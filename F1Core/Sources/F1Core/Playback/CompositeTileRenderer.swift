import CoreVideo
import Metal
import Foundation

/// One decoded pixel buffer and one Metal texture are shared by the visible tiles.
@MainActor public final class CompositeTileRenderer {
    public let device: any MTLDevice
    public let queue: any MTLCommandQueue
    private let pipeline: any MTLRenderPipelineState
    private let textureCache: CVMetalTextureCache
    private var frame: Frame?
    public var onFrame: (() -> Void)?

    private struct Frame {
        let pixels: CVPixelBuffer
        let backing: CVMetalTexture
        let texture: any MTLTexture
    }

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
              let library = try? device.makeLibrary(source: Self.shader, options: nil) else { return nil }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "compositeVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "compositeFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        var textureCache: CVMetalTextureCache?
        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor),
              CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache) == kCVReturnSuccess,
              let textureCache else { return nil }
        self.device = device
        self.queue = queue
        self.pipeline = pipeline
        self.textureCache = textureCache
    }

    public var hasFrame: Bool { frame != nil }

    func update(_ pixels: CVPixelBuffer) -> Bool {
        var backing: CVMetalTexture?
        let width = CVPixelBufferGetWidth(pixels)
        let height = CVPixelBufferGetHeight(pixels)
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixels, nil,
                                                             .bgra8Unorm, width, height, 0, &backing)
        guard status == kCVReturnSuccess, let backing, let texture = CVMetalTextureGetTexture(backing) else { return false }
        frame = Frame(pixels: pixels, backing: backing, texture: texture)
        onFrame?()
        return true
    }

    public func encode(rect: CGRect, descriptor: MTLRenderPassDescriptor, into command: any MTLCommandBuffer) -> Bool {
        guard let frame, let encoder = command.makeRenderCommandEncoder(descriptor: descriptor) else { return false }

        // CoreVideo textures and Metal UVs start at the upper left.
        let halfX = 0.5 / Double(frame.texture.width)
        let halfY = 0.5 / Double(frame.texture.height)
        var region = SIMD4<Float>(Float(rect.minX + halfX), Float(1 - rect.maxY + halfY),
                                  Float(max(0, rect.width - 2 * halfX)), Float(max(0, rect.height - 2 * halfY)))
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBytes(&region, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        encoder.setFragmentTexture(frame.texture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        // Retain the decoded surface until Metal is done sampling it.
        command.addCompletedHandler { _ in withExtendedLifetime(frame) {} }
        return true
    }

    func clear() {
        frame = nil
        CVMetalTextureCacheFlush(textureCache, 0)
    }

    private static let shader = """
    #include <metal_stdlib>
    using namespace metal;

    struct TileVertex {
        float4 position [[position]];
        float2 uv;
    };

    vertex TileVertex compositeVertex(uint vertexID [[vertex_id]], constant float4& region [[buffer(0)]]) {
        float2 corner = float2((vertexID == 1) ? 2.0 : 0.0, (vertexID == 2) ? 2.0 : 0.0);
        TileVertex out;
        out.position = float4(2.0 * corner.x - 1.0, 1.0 - 2.0 * corner.y, 0.0, 1.0);
        out.uv = region.xy + corner * region.zw;
        return out;
    }

    fragment half4 compositeFragment(TileVertex in [[stage_in]], texture2d<half> video [[texture(0)]]) {
        constexpr sampler bilinear(coord::normalized, address::clamp_to_edge, filter::linear);
        return half4(video.sample(bilinear, in.uv).rgb, 1.0h);
    }
    """
}

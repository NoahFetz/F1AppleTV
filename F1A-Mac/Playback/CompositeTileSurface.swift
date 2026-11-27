import F1Core
import MetalKit
import SwiftUI

@MainActor final class MacCompositePreview {
    let player: CompositePreviewPlayer
    let rects: [String: CGRect]
    private let views = NSHashTable<CompositeTileMetalView>.weakObjects()

    init(player: CompositePreviewPlayer, rects: [String: CGRect]) {
        self.player = player
        self.rects = rects
        player.renderer.onFrame = { [weak self] in
            self?.views.allObjects.forEach { $0.requestDraw() }
        }
    }

    fileprivate func attach(_ view: CompositeTileMetalView) { views.add(view) }
    fileprivate func detach(_ view: CompositeTileMetalView) { views.remove(view) }
}

struct CompositeTileSurface: NSViewRepresentable {
    let preview: MacCompositePreview
    let rect: CGRect

    func makeNSView(context: Context) -> CompositeTileMetalView {
        let view = CompositeTileMetalView(frame: .zero, device: preview.player.renderer.device)
        view.colorPixelFormat = .bgra8Unorm
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.attach(preview, rect: rect)
        return view
    }

    func updateNSView(_ view: CompositeTileMetalView, context: Context) {
        view.attach(preview, rect: rect)
    }

    static func dismantleNSView(_ view: CompositeTileMetalView, coordinator: ()) {
        view.detach()
    }
}

@MainActor final class CompositeTileMetalView: MTKView {
    private weak var preview: MacCompositePreview?
    private var rect = CGRect.zero
    private var drawing = false
    private var redrawPending = false

    func attach(_ preview: MacCompositePreview, rect: CGRect) {
        guard self.preview !== preview || self.rect != rect else { return }
        detach()
        self.preview = preview
        self.rect = rect
        preview.attach(self)
        requestDraw()
    }

    func detach() {
        preview?.detach(self)
        preview = nil
        redrawPending = false
    }

    func requestDraw() {
        if drawing { redrawPending = true }
        else { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !drawing, let renderer = preview?.player.renderer, renderer.hasFrame,
              let descriptor = currentRenderPassDescriptor, let drawable = currentDrawable,
              let command = renderer.queue.makeCommandBuffer(),
              renderer.encode(rect: rect, descriptor: descriptor, into: command) else { return }
        drawing = true
        command.present(drawable)
        command.addCompletedHandler { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.drawing = false
                if self.redrawPending {
                    self.redrawPending = false
                    self.requestDraw()
                }
            }
        }
        command.commit()
    }
}

import Foundation

/// Requests enough source pixels for the rendered artwork, including focus enlargement.
public struct CatalogArtworkRequest: Equatable {
    public let url: URL
    public let pixelSize: CGSize
    public let scale: CGFloat
    public var processingSize: CGSize { CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale) }

    public init?(pictureID: String?, size: CGSize, scale: CGFloat, focusScale: CGFloat = 1, maximumPixelDimension: CGFloat? = nil,
          baseURL: URL = URL(string: "https://f1tv.formula1.com/image-resizer/image")!) {
        guard let pictureID, !pictureID.isEmpty, size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0, scale.isFinite, scale > 0,
              focusScale.isFinite, focusScale >= 1 else { return nil }
        self.scale = scale
        // Round up to a small pixel bucket so subpixel layout changes share cache entries.
        var pixels = CGSize(width: ceil(size.width * scale * focusScale / 8) * 8,
                            height: ceil(size.height * scale * focusScale / 8) * 8)
        if let maximumPixelDimension {
            guard maximumPixelDimension.isFinite, maximumPixelDimension >= 8 else { return nil }
            let limit = floor(maximumPixelDimension / 8) * 8
            let ratio = min(1, limit / max(pixels.width, pixels.height))
            pixels = CGSize(width: max(8, ceil(pixels.width * ratio / 8) * 8),
                            height: max(8, ceil(pixels.height * ratio / 8) * 8))
        }
        pixelSize = pixels
        var components = URLComponents(url: baseURL.appendingPathComponent(pictureID), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "w", value: String(Int(pixelSize.width))),
                                 URLQueryItem(name: "h", value: String(Int(pixelSize.height))),
                                 URLQueryItem(name: "q", value: "HI")]
        guard let url = components.url else { return nil }
        self.url = url
    }
}

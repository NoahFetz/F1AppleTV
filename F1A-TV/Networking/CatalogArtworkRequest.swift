import Foundation

/// Requests enough source pixels for the rendered artwork, including focus enlargement.
struct CatalogArtworkRequest: Equatable {
    let url: URL
    let pixelSize: CGSize
    let scale: CGFloat
    var processingSize: CGSize { CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale) }

    init?(pictureID: String?, size: CGSize, scale: CGFloat, focusScale: CGFloat = 1,
          baseURL: URL = URL(string: "https://f1tv.formula1.com/image-resizer/image")!) {
        guard let pictureID, !pictureID.isEmpty, size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0, scale.isFinite, scale > 0,
              focusScale.isFinite, focusScale >= 1 else { return nil }
        self.scale = scale
        // Round up to a small pixel bucket so subpixel layout changes share cache entries.
        pixelSize = CGSize(width: ceil(size.width * scale * focusScale / 8) * 8,
                           height: ceil(size.height * scale * focusScale / 8) * 8)
        var components = URLComponents(url: baseURL.appendingPathComponent(pictureID), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "w", value: String(Int(pixelSize.width))),
                                 URLQueryItem(name: "h", value: String(Int(pixelSize.height))),
                                 URLQueryItem(name: "q", value: "HI")]
        guard let url = components.url else { return nil }
        self.url = url
    }
}

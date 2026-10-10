import SwiftUI
import AppKit
import F1Core

/// Shared cache, bounded source dimensions and stable image identity during resizing.
@MainActor private final class ArtworkCache {
    static let shared = ArtworkCache()
    private let images = NSCache<NSURL, NSImage>()
    private var pending: [URL: Task<NSImage?, Never>] = [:]
    init() { images.totalCostLimit = 96 * 1024 * 1024; images.countLimit = 160 }
    func image(_ url: URL) async -> NSImage? {
        if let image = images.object(forKey: url as NSURL) { return image }
        if let task = pending[url] { return await task.value }
        let task = Task { () -> NSImage? in
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200, let image = NSImage(data: data) else { return nil }
            return image
        }
        pending[url] = task
        let image = await task.value; pending.removeValue(forKey: url)
        if let image { images.setObject(image, forKey: url as NSURL, cost: Int(image.size.width * image.size.height * 4)) }
        return image
    }
}
@MainActor private final class ArtworkModel: ObservableObject {
    @Published var image: NSImage?
    private(set) var picture: String?
    func load(picture: String?, url: URL?) async {
        if self.picture != picture { self.picture = picture; image = nil }
        guard let url else { return }
        // Resize/fullscreen changes share coarse pixel buckets and cancel this debounce.
        do { try await Task.sleep(nanoseconds: 120_000_000) } catch { return }
        let next = await ArtworkCache.shared.image(url)
        guard !Task.isCancelled, self.picture == picture else { return }
        if let next { image = next }
    }
}
struct CatalogArtwork: View {
    var picture: String?
    var size: CGSize
    var fit = false
    @StateObject private var model = ArtworkModel()
    private var url: URL? {
        if let picture, picture.hasPrefix("https://") { return URL(string: picture) }
        let bucket = CGSize(width: ceil(max(1, size.width) / 64) * 64, height: ceil(max(1, size.height) / 32) * 32)
        return CatalogArtworkRequest(pictureID: picture, size: bucket, scale: 2, maximumPixelDimension: 2560)?.url
    }
    var body: some View {
        ZStack {
            if let image = model.image, model.picture == picture {
                Image(nsImage: image).resizable().aspectRatio(contentMode: fit ? .fit : .fill)
            } else if !fit {
                DesktopTheme.item.overlay(Image(systemName: "flag.checkered").foregroundStyle(.secondary))
            }
        }.frame(width: size.width, height: size.height).clipped()
            .task(id: url) { await model.load(picture: picture, url: url) }
    }
}

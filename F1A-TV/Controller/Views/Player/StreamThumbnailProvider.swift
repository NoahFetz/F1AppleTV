import AVKit
import UIKit

@MainActor
final class StreamThumbnailProvider {
    private weak var player: FairPlayer?
    private var requestTask: Task<Void, Never>?
    private var imagePlaylist: HLSImagePlaylist?
    private var playlistLoadedAt: Date?
    private var imageGenerator: AVAssetImageGenerator?
    private var thumbnailKeyLoader: FairPlayer?
    private var generationUnavailable = false
    private let imageCache = NSCache<NSURL, UIImage>()
    private let frameCache = NSCache<NSString, UIImage>()

    init(player: FairPlayer) {
        self.player = player
        imageCache.countLimit = 8
        frameCache.countLimit = 48
    }

    func cancel() {
        requestTask?.cancel()
        requestTask = nil
        imageGenerator?.cancelAllCGImageGeneration()
    }

    func request(at time: Double, completion: @escaping (UIImage?) -> Void) {
        requestTask?.cancel()
        imageGenerator?.cancelAllCGImageGeneration()
        guard let player = player, time.isFinite else { completion(nil); return }
        let date = player.currentItem?.currentDate()?.addingTimeInterval(time - player.currentTime().seconds)
        let key = NSString(string: "\(Int((date?.timeIntervalSince1970 ?? time) / 2))")
        if let cached = frameCache.object(forKey: key) { completion(cached); return }
        requestTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 180_000_000)
                guard let self = self, let player = self.player else { return }
                let image = try await self.loadImage(at: time, date: date, player: player)
                try Task.checkCancellation()
                if let image = image { self.frameCache.setObject(image, forKey: key) }
                completion(image)
            } catch {
                if !Task.isCancelled { completion(nil) }
            }
        }
    }

    private func loadImage(at time: Double, date: Date?, player: FairPlayer) async throws -> UIImage? {
        guard let text = player.previewManifest, let baseURL = player.previewBaseURL else { return nil }
        let manifest = HLSPreviewManifest(text: text, baseURL: baseURL)
        if let url = manifest.imagePlaylists.first {
            do {
                if imagePlaylist == nil || (imagePlaylist?.isLive == true && Date().timeIntervalSince(playlistLoadedAt ?? .distantPast) > 8) {
                    let (data, finalURL) = try await fetch(url)
                    guard let text = String(data: data, encoding: .utf8) else { return nil }
                    imagePlaylist = try HLSImagePlaylist(text: text, baseURL: finalURL)
                    playlistLoadedAt = Date()
                }
                if let frame = imagePlaylist?.frame(at: time, date: date) {
                    return try await image(for: frame)
                }
            } catch {
                try Task.checkCancellation()
                // A provider's image rendition can fail independently of normal video playback.
            }
        }
        guard manifest.hasIFrameRenditions, !generationUnavailable else { return nil }
        if imageGenerator == nil {
            let keyLoader = FairPlayer()
            keyLoader.streamEntitlement = player.streamEntitlement
            keyLoader.fairPlayService = player.fairPlayService
            keyLoader.reportsPlaybackErrors = false
            guard let asset = keyLoader.makeThumbnailAsset() else { return nil }
            thumbnailKeyLoader = keyLoader
            let generator = AVAssetImageGenerator(asset: asset)
            generator.maximumSize = CGSize(width: 512, height: 288)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = CMTime(seconds: 2, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 2, preferredTimescale: 600)
            imageGenerator = generator
        }
        guard let generator = imageGenerator else { return nil }
        do {
            let image = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image
            return UIImage(cgImage: image)
        } catch {
            try Task.checkCancellation()
            generationUnavailable = true
            return nil
        }
    }

    private func fetch(_ url: URL) async throws -> (Data, URL) {
        let request = URLRequest(url: url, timeoutInterval: 8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        try Task.checkCancellation()
        return (data, response.url ?? url)
    }

    private func image(for frame: HLSImagePlaylist.Frame) async throws -> UIImage? {
        let fullImage: UIImage
        if let cached = imageCache.object(forKey: frame.url as NSURL) {
            fullImage = cached
        } else {
            let (data, _) = try await fetch(frame.url)
            guard let image = UIImage(data: data) else { return nil }
            imageCache.setObject(image, forKey: frame.url as NSURL)
            fullImage = image
        }
        guard let tile = frame.tile, let source = fullImage.cgImage else { return fullImage }
        let x = CGFloat(frame.index % tile.columns) * CGFloat(tile.width)
        let y = CGFloat(frame.index / tile.columns) * CGFloat(tile.height)
        let rect = CGRect(x: x, y: y, width: CGFloat(tile.width), height: CGFloat(tile.height))
        guard rect.maxX <= CGFloat(source.width), rect.maxY <= CGFloat(source.height),
              let cropped = source.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped)
    }
}

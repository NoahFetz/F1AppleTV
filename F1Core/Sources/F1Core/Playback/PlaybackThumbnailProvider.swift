import AVFoundation
import CoreGraphics
import ImageIO
import Combine

/// Protected previews stay in AVFoundation's rendering path; they are never read back as pixels.
public enum PlaybackScrubPreview {
    case image(CGImage)
    case video(AVPlayerLayer)
}

public enum PlaybackNativePreviewState {
    case idle
    case loading(AVPlayerLayer)
    case ready(AVPlayerLayer)
    case unavailable

    public var surface: AVPlayerLayer? {
        switch self {
        case .loading(let layer), .ready(let layer): return layer
        case .idle, .unavailable: return nil
        }
    }
}

@MainActor
public final class PlaybackThumbnailProvider: ObservableObject {
    /// A live rendering surface, independent of time-specific request completions.
    /// Once ready, it can stay visible while coalesced seeks follow pointer movement.
    @Published public private(set) var nativePreviewState = PlaybackNativePreviewState.idle
    public var nativePreviewSurface: AVPlayerLayer? { nativePreviewState.surface }
    private weak var player: FairPlayer?
    private var requestTask: Task<Void, Never>?
    private var imagePlaylist: HLSImagePlaylist?
    private var playlistLoadedAt: Date?
    private var imageGenerator: AVAssetImageGenerator?
    private var thumbnailKeyLoader: FairPlayer?
    private var nativePlayer: FairPlayer?
    private var nativeLayer: AVPlayerLayer?
    private var idleReleaseTask: Task<Void, Never>?
    private var pendingRequest: Request?
    private struct Request {
        let id: UUID
        let time: Double
        let date: Date?
        let key: NSString
        let completion: (PlaybackScrubPreview?) -> Void
    }
    private var identity: String?
    private var requestID = UUID()
    private let allowUnprotectedVideoFallback: Bool
    private let session: URLSession
    private let refreshEntitlement: (() async throws -> PlaybackEntitlement)?
    private var refreshedSource: (entitlement: PlaybackEntitlement, text: String, baseURL: URL)?
    private var refreshedAccess = false
    private let imageCache = NSCache<NSURL, CGImage>()
    private let frameCache = NSCache<NSString, CGImage>()

    public init(player: FairPlayer, allowUnprotectedVideoFallback: Bool = false, session: URLSession = .shared,
                refreshEntitlement: (() async throws -> PlaybackEntitlement)? = nil) {
        self.session = session
        self.allowUnprotectedVideoFallback = allowUnprotectedVideoFallback
        self.player = player
        self.refreshEntitlement = refreshEntitlement
        imageCache.countLimit = 8
        frameCache.countLimit = 48
    }

    public func cancel() {
        idleReleaseTask?.cancel(); idleReleaseTask = nil
        cancelRequests()
        releaseNativePlayer()
    }

    private func cancelRequests() {
        requestID = UUID()
        requestTask?.cancel()
        requestTask = nil
        imageGenerator?.cancelAllCGImageGeneration()
        nativePlayer?.currentItem?.cancelPendingSeeks()
        pendingRequest = nil
    }

    /// Hides the surface and stops seeks while retaining the paused player/key
    /// session for the lifetime of the feed. Owners reset when playback closes.
    /// An optional timeout is available for shorter-lived preview owners.
    public func suspend(releaseAfter delay: Duration? = nil) {
        idleReleaseTask?.cancel(); idleReleaseTask = nil
        cancelRequests()
        nativePreviewState = .idle
        refreshedAccess = false
        nativePlayer?.pause()
        guard nativePlayer != nil, let delay else { return }
        idleReleaseTask = Task { [weak self] in
            do { try await Task.sleep(for: delay) } catch { return }
            self?.releaseNativePlayer()
            self?.idleReleaseTask = nil
        }
    }

    private func releaseNativePlayer() {
        nativePreviewState = .idle
        nativeLayer?.player = nil; nativeLayer = nil; nativePlayer?.stopStream(); nativePlayer = nil
    }

    /// Compatibility API for image renditions. Custom players should use requestPreview
    /// so protected I-frame tracks can be displayed without extracting their pixels.
    public func request(at time: Double, completion: @escaping (CGImage?) -> Void) {
        requestPreview(at: time) { preview in
            if case .image(let image) = preview { completion(image) } else { completion(nil) }
        }
    }

    public func warmUp() {
        guard let player, player.currentItem?.status == .readyToPlay else { return }
        requestPreview(at: player.currentTime().seconds) { _ in }
    }

    public func requestPreview(at time: Double, completion: @escaping (PlaybackScrubPreview?) -> Void) {
        guard let player, time.isFinite else { completion(nil); return }
        if identity != player.streamEntitlement?.url { reset(); identity = player.streamEntitlement?.url }
        idleReleaseTask?.cancel(); idleReleaseTask = nil
        if case .unavailable = nativePreviewState { completion(nil); return }
        let date = player.currentItem?.currentDate()?.addingTimeInterval(time - player.currentTime().seconds)
        let key = NSString(string: "\(Int((date?.timeIntervalSince1970 ?? time) / 2))")
        requestID = UUID()
        if let cached = frameCache.object(forKey: key) {
            pendingRequest = nil; completion(.image(cached)); return
        }
        pendingRequest = Request(id: requestID, time: time, date: date, key: key, completion: completion)
        // Keep one operation running and replace only the queued target. Cancelling
        // asset preparation on every pointer/remote movement starves continuous scrubs.
        guard requestTask == nil else { return }
        requestTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, let request = self.pendingRequest {
                self.pendingRequest = nil
                do {
                    guard let player = self.player else { break }
                    let preview = try await self.loadPreview(at: request.time, date: request.date, player: player)
                    try Task.checkCancellation()
                    if case .image(let image) = preview { self.frameCache.setObject(image, forKey: request.key) }
                    if self.requestID == request.id { request.completion(preview) }
                } catch {
                    if Task.isCancelled { return }
                    self.failNativePreview(error)
                    if self.requestID == request.id { request.completion(nil) }
                }
            }
            if !Task.isCancelled { self.requestTask = nil }
        }
    }

    /// Ends all thumbnail work and releases the independent FairPlay owner.
    public func reset() {
        cancel(); imageGenerator = nil; thumbnailKeyLoader?.stopStream(); thumbnailKeyLoader = nil
        imagePlaylist = nil; playlistLoadedAt = nil; identity = nil
        refreshedSource = nil; refreshedAccess = false
        imageCache.removeAllObjects(); frameCache.removeAllObjects()
    }

    private func loadPreview(at time: Double, date: Date?, player: FairPlayer) async throws -> PlaybackScrubPreview? {
        if case .unavailable = nativePreviewState { return nil }
        do {
            return try await loadPreviewSource(at: time, date: date, player: player)
        } catch {
            try Task.checkCancellation()
            guard AppErrorStore.httpStatus(for: error) == 403, !refreshedAccess, let refreshEntitlement else { throw error }
            refreshedAccess = true
            let entitlement = try await refreshEntitlement()
            try Task.checkCancellation()
            guard let url = URL(string: entitlement.url) else { throw URLError(.badURL) }
            let (data, baseURL) = try await fetch(url, reload: true)
            guard let text = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
            try Task.checkCancellation()
            releaseNativePlayer()
            imagePlaylist = nil; playlistLoadedAt = nil
            refreshedSource = (entitlement, text, baseURL)
            return try await loadPreviewSource(at: time, date: date, player: player)
        }
    }

    private func loadPreviewSource(at time: Double, date: Date?, player: FairPlayer) async throws -> PlaybackScrubPreview? {
        guard let text = refreshedSource?.text ?? player.previewManifest,
              let baseURL = refreshedSource?.baseURL ?? player.previewBaseURL else { return nil }
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
                    if let image = try await image(for: frame) { return .image(image) }
                }
            } catch {
                try Task.checkCancellation()
                // A provider's image rendition can fail independently of normal video playback.
            }
        }
        if let rendition = manifest.preferredIFrameRendition {
            return try await nativePreview(at: time, date: date, rendition: rendition, player: player)
        }
        let entitlement = refreshedSource?.entitlement ?? player.streamEntitlement
        let unprotected = entitlement?.licenseURL == nil && !(entitlement?.drmType?.lowercased().contains("fairplay") ?? false)
        guard allowUnprotectedVideoFallback && unprotected else { return nil }
        if imageGenerator == nil {
            let keyLoader = FairPlayer()
            keyLoader.streamEntitlement = entitlement
            keyLoader.fairPlayService = player.fairPlayService
            keyLoader.reportsPlaybackErrors = false
            guard let asset = keyLoader.makeThumbnailAsset() else { return nil }
            thumbnailKeyLoader = keyLoader
            let generator = AVAssetImageGenerator(asset: asset)
            generator.maximumSize = CGSize(width: 512, height: 288)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .positiveInfinity
            generator.requestedTimeToleranceAfter = .positiveInfinity
            imageGenerator = generator
        }
        guard let generator = imageGenerator else { return nil }
        do {
            let image = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image
            return .image(image)
        } catch {
            try Task.checkCancellation()
            return nil
        }
    }

    private final class SeekResult { var finished: Bool? }

    private func failNativePreview(_ error: Error) {
        AppErrorStore.shared.record(error, operation: .preview)
        releaseNativePlayer()
        // Stop retrying the same failing asset on every mouse movement. Leaving
        // and re-entering the scrubber (suspend) allows another attempt.
        nativePreviewState = .unavailable
    }

    private func nativeFailure(for item: AVPlayerItem) async -> Error {
        let reported = await FairPlayer.playbackFailure(for: item)
        // A media rejection can leave the item ready while its seek/display stalls.
        return item.error != nil || AppErrorStore.httpStatus(for: reported) != nil ? reported : URLError(.timedOut)
    }

    private func nativePreview(at time: Double, date: Date?, rendition: HLSPreviewManifest.IFrameRendition, player: FairPlayer) async throws -> PlaybackScrubPreview? {
        if case .unavailable = nativePreviewState { return nil }
        if nativePlayer?.currentItem?.status == .failed {
            if let item = nativePlayer?.currentItem { throw await nativeFailure(for: item) }
        }
        if nativePlayer == nil {
            let preview = FairPlayer()
            preview.streamEntitlement = refreshedSource?.entitlement ?? player.streamEntitlement
            preview.fairPlayService = player.fairPlayService
            preview.reportsPlaybackErrors = false
            preview.isMuted = true; preview.volume = 0
            guard let asset = preview.makeThumbnailAsset(url: rendition.url) else { return nil }
            let item = AVPlayerItem(asset: asset)
            item.preferredForwardBufferDuration = 1
            preview.replaceCurrentItem(with: item)
            let layer = AVPlayerLayer(player: preview)
            layer.videoGravity = .resizeAspect
            layer.frame = CGRect(x: 0, y: 0, width: 320, height: 180)
            nativePlayer = preview; nativeLayer = layer
        }
        guard let preview = nativePlayer, let item = preview.currentItem, let layer = nativeLayer else { return nil }
        // Mount the layer while preparing. Waiting for display readiness before
        // exposing it keeps the rendering host out of the startup path.
        if nativePreviewSurface == nil { nativePreviewState = .loading(layer) }
        let deadline = Date().addingTimeInterval(10)
        while item.status == .unknown && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        try Task.checkCancellation()
        guard item.status == .readyToPlay else {
            let error = await nativeFailure(for: item)
            try Task.checkCancellation()
            throw error
        }
        let result = SeekResult()
        let finished: @Sendable (Bool) -> Void = { ok in
            Task { @MainActor in result.finished = ok }
        }
        if let date {
            var target = date
            if let currentDate = item.currentDate(), let range = item.seekableTimeRanges.last?.timeRangeValue {
                let position = preview.currentTime().seconds
                let proposed = position + date.timeIntervalSince(currentDate)
                let clamped = min(max(proposed, range.start.seconds), CMTimeRangeGetEnd(range).seconds - 0.001)
                target = currentDate.addingTimeInterval(clamped - position)
            }
            preview.seek(to: target, completionHandler: finished)
        } else {
            // A moving live playlist without dates cannot be aligned safely to
            // another player's independently established timeline.
            guard !item.duration.isIndefinite else {
                throw AVError(.operationNotSupportedForAsset)
            }
            var target = max(0, time)
            if let range = item.seekableTimeRanges.last?.timeRangeValue {
                target = min(max(target, range.start.seconds), CMTimeRangeGetEnd(range).seconds)
            }
            // The service's I-frames are ~5.76 seconds apart. Native seeking picks
            // a nearby I-frame, rather than requiring a frame within two seconds.
            let tolerance = CMTime(seconds: 6, preferredTimescale: 600)
            preview.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: tolerance, toleranceAfter: tolerance, completionHandler: finished)
        }
        let seekDeadline = Date().addingTimeInterval(8)
        while (result.finished == nil || (result.finished == true && !layer.isReadyForDisplay)) && Date() < seekDeadline {
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        try Task.checkCancellation()
        guard result.finished == true, layer.isReadyForDisplay else {
            let error = await nativeFailure(for: item)
            try Task.checkCancellation()
            throw error
        }
        // Publishing the mutable renderer does not deliver a superseded timestamp
        // completion. It lets the UI display decoded frames during continuous scrubs.
        nativePreviewState = .ready(layer)
        return .video(layer)
    }

    deinit { idleReleaseTask?.cancel(); requestTask?.cancel() }

    private func fetch(_ url: URL, reload: Bool = false) async throws -> (Data, URL) {
        let request = URLRequest(url: url, cachePolicy: reload ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy, timeoutInterval: 8)
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            var info: [String: Any] = [:]
            if let response = response as? HTTPURLResponse { info[AppErrorStore.httpStatusKey] = response.statusCode }
            throw NSError(domain: NSURLErrorDomain, code: URLError.badServerResponse.rawValue, userInfo: info)
        }
        try Task.checkCancellation()
        return (data, response.url ?? url)
    }

    private func image(for frame: HLSImagePlaylist.Frame) async throws -> CGImage? {
        let fullImage: CGImage
        if let cached = imageCache.object(forKey: frame.url as NSURL) {
            fullImage = cached
        } else {
            let (data, _) = try await fetch(frame.url)
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            imageCache.setObject(image, forKey: frame.url as NSURL)
            fullImage = image
        }
        guard let tile = frame.tile else { return fullImage }
        let source = fullImage
        let x = CGFloat(frame.index % tile.columns) * CGFloat(tile.width)
        let y = CGFloat(frame.index / tile.columns) * CGFloat(tile.height)
        let rect = CGRect(x: x, y: y, width: CGFloat(tile.width), height: CGFloat(tile.height))
        guard rect.maxX <= CGFloat(source.width), rect.maxY <= CGFloat(source.height),
              let cropped = source.cropping(to: rect) else { return nil }
        return cropped
    }
}

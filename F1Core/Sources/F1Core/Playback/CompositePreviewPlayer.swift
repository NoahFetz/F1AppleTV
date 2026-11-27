import AVFoundation
import QuartzCore

@MainActor public final class CompositePreviewPlayer {
    public let source: PreviewFeedBundle.Composite
    private let item: AVPlayerItem
    private let player: AVPlayer
    private let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferMetalCompatibilityKey as String: true,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:]
    ])
    public let renderer: CompositeTileRenderer
    private var seeking = false
    private var lastFrameTime: CFTimeInterval = 0
    private var frameTimer: Timer?

    public init?(source: PreviewFeedBundle.Composite) {
        guard let renderer = CompositeTileRenderer() else { return nil }
        self.renderer = renderer
        self.source = source
        item = AVPlayerItem(url: source.url)
        player = AVPlayer(playerItem: item)
        item.add(output)
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false
    }

    public func start(at anchor: Double) async throws {
        for _ in 0..<30 {
            try Task.checkCancellation()
            if item.status == .readyToPlay { break }
            if item.status == .failed { throw APIError.invalidPlayback }
            try await Task.sleep(for: .milliseconds(100))
        }
        guard item.status == .readyToPlay else { throw URLError(.timedOut) }
        // The composite can expose its first frame at zero while its clock remains stalled.
        let target = position(for: anchor)
        seek(to: target, rate: 1)
        for _ in 0..<70 {
            try Task.checkCancellation()
            if item.status == .failed { throw APIError.invalidPlayback }
            if !seeking, player.currentTime().seconds > target + 0.1, readFrame() {
                startFrameTimer()
                return
            }
            try await Task.sleep(for: .milliseconds(80))
        }
        throw URLError(.timedOut)
    }

    public func sync(to seconds: Double, rate: Float) -> Bool {
        let playing = rate > 0
        guard item.status != .failed else { return false }
        if seeking { return CACurrentMediaTime() - lastFrameTime < 5 }
        let desired = position(for: seconds)
        if abs(player.currentTime().seconds - desired) > (playing ? 1.75 : 0.35) {
            seek(to: desired, rate: rate)
            return true
        }
        if playing, player.rate != rate { player.playImmediately(atRate: rate) }
        if !playing, player.rate != 0 { player.pause() }
        if !playing { lastFrameTime = CACurrentMediaTime() }
        return CACurrentMediaTime() - lastFrameTime < 5
    }

    private func startFrameTimer() {
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.readFrame() }
        }
        frameTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    deinit { frameTimer?.invalidate() }

    public func stop() {
        player.cancelPendingPrerolls()
        item.cancelPendingSeeks()
        player.pause()
        player.replaceCurrentItem(with: nil)
        frameTimer?.invalidate()
        frameTimer = nil
        renderer.clear()
    }

    private func position(for seconds: Double) -> Double {
        let upper = item.duration.seconds.isFinite ? max(0.1, item.duration.seconds - 0.25) : Double.greatestFiniteMagnitude
        let minimum = 5.0
        return min(max(seconds.isFinite ? seconds : 0, minimum), upper)
    }

    private func seek(to seconds: Double, rate: Float) {
        seeking = true
        lastFrameTime = CACurrentMediaTime()
        let target = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            Task { @MainActor in
                guard let self, self.player.currentItem === self.item else { return }
                self.seeking = false
                if finished && rate > 0 { self.player.playImmediately(atRate: rate) }
            }
        }
    }

    @discardableResult private func readFrame() -> Bool {
        guard !seeking else { return false }
        let time = player.currentTime()
        guard time.isNumeric, output.hasNewPixelBuffer(forItemTime: time),
              let pixels = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil),
              renderer.update(pixels) else { return false }
        lastFrameTime = CACurrentMediaTime()
        return true
    }
}

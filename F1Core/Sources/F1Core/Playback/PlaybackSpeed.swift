import AVFoundation

public enum PlaybackSpeed: Float, CaseIterable, Sendable {
    case half = 0.5
    case threeQuarters = 0.75
    case normal = 1
    case oneAndAQuarter = 1.25
    case oneAndAHalf = 1.5
    case double = 2

    public var label: String { Double(rawValue).formatted(.number.precision(.fractionLength(0...2))) + "×" }
}

extension AVPlayer {
    @MainActor public func applyPlaybackSpeed(_ speed: PlaybackSpeed) {
        guard defaultRate != speed.rawValue else { return }
        let isPlaying = timeControlStatus != .paused
        defaultRate = speed.rawValue
        if isPlaying { rate = speed.rawValue }
    }
}

import Foundation

enum LiveTimeline {
    static let edgePadding = 3.0
    static func target(start: Double, end: Double, lag: Double = edgePadding) -> Double? {
        guard start.isFinite, end.isFinite, lag.isFinite, end > start else { return nil }
        return max(start, min(end - min(0.1, (end - start) / 2), end - max(0.1, lag)))
    }
    static func isAtLive(position: Double, end: Double) -> Bool {
        position.isFinite && end.isFinite && abs(end - position) <= 6
    }
}

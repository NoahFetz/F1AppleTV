import Foundation

enum TransportDirection: Int {
    case backward = -1
    case forward = 1
}

struct MultiviewTransportState {
    enum Phase: Equatable { case navigation, preview, scanning, seeking }
    private(set) var phase = Phase.navigation
    private(set) var referenceID: String?
    private(set) var target: Double?
    private(set) var scanDirection = TransportDirection.forward
    private(set) var scanLevel = 0
    private(set) var position: Double = 0
    private(set) var lower: Double = 0
    private(set) var upper: Double = 0

    var isPreviewing: Bool { phase == .preview || phase == .scanning }
    var displayTime: Double { target ?? position }
    var scanLabel: String? { phase == .scanning ? "\(scanDirection == .backward ? "-" : "")\(scanLevel + 2)x" : nil }

    @discardableResult
    mutating func synchronize(referenceID: String?, position: Double, lower: Double, upper: Double, seeking: Bool) -> Bool {
        let changed = self.referenceID != referenceID
        if changed { cancel() }
        self.referenceID = referenceID
        self.position = position.isFinite ? position : 0
        self.lower = lower.isFinite ? lower : 0
        self.upper = upper.isFinite ? max(self.lower, upper) : self.lower
        if phase == .seeking && !seeking { cancel() }
        if let target { self.target = clamp(target) }
        return changed
    }

    mutating func step(_ direction: TransportDirection, playing: Bool) {
        target = clamp(displayTime + Double(direction.rawValue) * 10)
        phase = playing && !isPreviewing ? .seeking : .preview
    }

    mutating func pan(seconds: Double) {
        guard seconds.isFinite else { return }
        target = clamp(displayTime + seconds)
        phase = .preview
    }

    mutating func startScan(_ direction: TransportDirection) {
        target = clamp(displayTime)
        scanDirection = direction
        scanLevel = 0
        phase = .scanning
    }

    // Returning true means scanning has cycled back to normal playback.
    mutating func changeScanSpeed(_ direction: TransportDirection) -> Bool {
        guard phase == .scanning else { return false }
        if direction == scanDirection { scanLevel += 1 }
        else { scanLevel -= 1 }
        return scanLevel < 0 || scanLevel > 2
    }

    mutating func advanceScan(seconds: Double) {
        guard phase == .scanning, seconds.isFinite, seconds >= 0 else { return }
        let speed = [24.0, 48.0, 96.0][min(max(scanLevel, 0), 2)]
        target = clamp(displayTime + seconds * speed * Double(scanDirection.rawValue))
        if target == lower || target == upper { phase = .preview }
    }

    mutating func markSeeking() { phase = .seeking }
    mutating func cancel() { phase = .navigation; target = nil; scanLevel = 0 }
    private func clamp(_ value: Double) -> Double { min(max(value, lower), upper) }
}

struct MultiviewScrubSession {
    let id: UUID
    let referenceID: String
    let wasPlaying: Bool
}

struct AudioMixStreamState: Equatable {
    let id: String
    let title: String
    let volume: Float
    let isMuted: Bool
    let isAvailable: Bool
}

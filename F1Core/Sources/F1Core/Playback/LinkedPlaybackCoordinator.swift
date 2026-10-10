import Foundation

/// The desktop session supplies AVPlayer adapters; tests supply deterministic clocks and seeks.
@MainActor public protocol LinkedPlaybackParticipant: AnyObject {
    var id: String { get }
    var ready: Bool { get }
    var buffering: Bool { get }
    var changingQuality: Bool { get }
    var position: Double { get }
    var programDate: Date? { get }
    var seekRange: ClosedRange<Double>? { get }
    var live: Bool { get }
    func play()
    func pause()
    func cancelSeek()
    func seek(seconds: Double, completion: @escaping (Bool) -> Void)
    func seek(date: Date, completion: @escaping (Bool) -> Void)
}

public struct PlaybackAnchor {
    public var seconds: Double
    public var date: Date?
    public var lag: Double?
    public var capturedAt: Date
    public var playing: Bool
    public init(seconds: Double, date: Date?, lag: Double?, capturedAt: Date, playing: Bool) {
        self.seconds = seconds; self.date = date; self.lag = lag; self.capturedAt = capturedAt; self.playing = playing
    }
}

@MainActor public final class LinkedPlaybackCoordinator {
    public private(set) var participants: [any LinkedPlaybackParticipant] = []
    public private(set) var wantsPlayback = true
    public var isScrubbing = false
    public var onSeekFailure: ((String) -> Void)?
    private var referenceID: String?
    private var generation = UUID()
    private var pending = Set<String>()
    private var joining = Set<String>()
    private var pendingSince: [String: Date] = [:]
    private var seekIDs: [String: UUID] = [:]
    private var resumeAnchor: PlaybackAnchor?
    private let clock: () -> Date
    public init(clock: @escaping () -> Date = Date.init) { self.clock = clock }
    public var reference: (any LinkedPlaybackParticipant)? {
        if let current = participants.first(where: { $0.id == referenceID && $0.ready && !$0.buffering }) { return current }
        let current = participants.first { $0.ready && !$0.buffering }
        referenceID = current?.id
        return current
    }
    public var hasPendingSeek: Bool { !pending.isEmpty }
    public func targetPosition(for participant: any LinkedPlaybackParticipant, anchor: PlaybackAnchor) -> Double? {
        desiredSeconds(participant, anchor)
    }
    public func add(_ participant: any LinkedPlaybackParticipant) {
        guard !participants.contains(where: { $0.id == participant.id }) else { return }
        participants.append(participant); joining.insert(participant.id); tick()
    }
    public func remove(id: String) {
        participants.first { $0.id == id }?.cancelSeek()
        participants.removeAll { $0.id == id }; joining.remove(id); pending.remove(id); pendingSince.removeValue(forKey: id)
        seekIDs.removeValue(forKey: id)
        if referenceID == id { referenceID = nil }
        if participants.isEmpty { reset() }
    }
    public func reset() {
        generation = UUID()
        participants.forEach { $0.cancelSeek(); $0.pause() }
        participants.removeAll(); pending.removeAll(); pendingSince.removeAll(); joining.removeAll()
        seekIDs.removeAll()
        referenceID = nil; resumeAnchor = nil; isScrubbing = false; wantsPlayback = true
    }
    public func capture() -> PlaybackAnchor? {
        guard let reference, reference.position.isFinite else { return resumeAnchor }
        return anchor(reference, seconds: reference.position)
    }
    public func restore(_ anchor: PlaybackAnchor?) {
        resumeAnchor = anchor
        if let anchor { wantsPlayback = anchor.playing }
    }
    public func setPlaying(_ playing: Bool) {
        invalidateSeeks(); wantsPlayback = playing
        if playing { synchronize() } else { participants.forEach { $0.pause() } }
    }
    public func seek(from id: String, seconds: Double) {
        guard seconds.isFinite, let source = participants.first(where: { $0.id == id && $0.ready }) else { return }
        invalidateSeeks()
        let target = anchor(source, seconds: seconds)
        resumeAnchor = target
        participants.forEach { $0.pause(); align($0, to: target) }
    }
    public func skip(from id: String, seconds: Double) {
        guard let source = participants.first(where: { $0.id == id }) else { return }
        seek(from: id, seconds: source.position + seconds)
    }
    public func goLive(from id: String) {
        guard let source = participants.first(where: { $0.id == id && $0.live }), let range = source.seekRange,
              let target = LiveTimeline.target(start: range.lowerBound, end: range.upperBound) else { return }
        wantsPlayback = true; seek(from: id, seconds: target)
    }
    public func synchronize() {
        guard let reference else { return }
        invalidateSeeks(); resumeAnchor = nil
        let target = anchor(reference, seconds: reference.position)
        participants.forEach { align($0, to: target) }
    }
    /// Called every two seconds, and when a newly prepared feed joins the session.
    public func tick() {
        let expired = pendingSince.filter { clock().timeIntervalSince($0.value) > 20 }.map(\.key)
        if !expired.isEmpty {
            invalidateSeeks()
            for id in expired { joining.insert(id); onSeekFailure?(id) }
        }
        guard !isScrubbing, pending.isEmpty, !participants.contains(where: { $0.changingQuality }) else { return }
        guard let reference else { return }
        // Live assets can become ready before publishing a seekable range. Start the
        // first feed so AVFoundation can obtain that range, then align normally.
        if reference.seekRange == nil, resumeAnchor == nil {
            if wantsPlayback { reference.play() } else { reference.pause() }
        }
        let target = resumeAnchor ?? anchor(reference, seconds: reference.position)
        for participant in participants where participant.ready && !participant.buffering {
            let desired = desiredSeconds(participant, target)
            let drift = desired.map { abs(participant.position - $0) } ?? 0
            if joining.contains(participant.id) || drift > 0.5 {
                align(participant, to: target)
            } else if wantsPlayback { participant.play() } else { participant.pause() }
        }
        if joining.isEmpty && pending.isEmpty { resumeAnchor = nil }
    }
    private func invalidateSeeks() {
        generation = UUID(); participants.forEach { $0.cancelSeek() }; pending.removeAll(); pendingSince.removeAll()
        seekIDs.removeAll()
    }
    private func anchor(_ source: any LinkedPlaybackParticipant, seconds: Double) -> PlaybackAnchor {
        let delta = seconds - source.position
        return PlaybackAnchor(seconds: seconds, date: source.programDate?.addingTimeInterval(delta),
                              lag: source.live ? source.seekRange.map { max(0.1, $0.upperBound - seconds) } : nil,
                              capturedAt: clock(), playing: wantsPlayback)
    }
    private func elapsed(_ anchor: PlaybackAnchor) -> Double { anchor.playing ? max(0, clock().timeIntervalSince(anchor.capturedAt)) : 0 }
    private func desiredSeconds(_ participant: any LinkedPlaybackParticipant, _ anchor: PlaybackAnchor) -> Double? {
        guard let range = participant.seekRange else { return nil }
        let value: Double
        if let date = anchor.date, let ownDate = participant.programDate {
            value = participant.position + date.addingTimeInterval(elapsed(anchor)).timeIntervalSince(ownDate)
        } else if participant.live, let lag = anchor.lag { value = range.upperBound - lag }
        else { value = anchor.seconds + elapsed(anchor) }
        guard value.isFinite else { return nil }
        return min(max(value, range.lowerBound), max(range.lowerBound, range.upperBound - 0.1))
    }
    private func align(_ participant: any LinkedPlaybackParticipant, to target: PlaybackAnchor) {
        guard participant.ready, !participant.buffering, !participant.changingQuality, !pending.contains(participant.id),
              let seconds = desiredSeconds(participant, target) else { joining.insert(participant.id); return }
        let epoch = generation; let id = participant.id; let seekID = UUID()
        seekIDs[id] = seekID
        pending.insert(id); pendingSince[id] = clock()
        let finish: (Bool) -> Void = { [weak self, weak participant] success in
            guard let self, let participant, self.generation == epoch, self.seekIDs[id] == seekID,
                  self.participants.contains(where: { $0 === participant }) else { return }
            self.pending.remove(id); self.pendingSince.removeValue(forKey: id)
            self.seekIDs.removeValue(forKey: id)
            if success {
                self.joining.remove(id)
                if self.wantsPlayback { participant.play() } else { participant.pause() }
            } else { participant.pause(); self.joining.insert(id); self.onSeekFailure?(id) }
            if self.joining.isEmpty && self.pending.isEmpty { self.resumeAnchor = nil }
        }
        if let date = target.date, let ownDate = participant.programDate {
            let adjusted = date.addingTimeInterval(elapsed(target))
            let withinRange = abs(seconds - (participant.position + adjusted.timeIntervalSince(ownDate))) < 0.2
            if withinRange {
                participant.seek(date: adjusted) { [weak self, weak participant] success in
                    guard let self, let participant, self.generation == epoch, self.seekIDs[id] == seekID,
                          self.participants.contains(where: { $0 === participant }) else { return }
                    if success { finish(true) } else { participant.seek(seconds: seconds, completion: finish) }
                }
            } else { participant.seek(seconds: seconds, completion: finish) }
        } else { participant.seek(seconds: seconds, completion: finish) }
    }
}

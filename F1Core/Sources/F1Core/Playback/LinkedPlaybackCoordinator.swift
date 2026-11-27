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
    func setPlaybackSpeed(_ speed: PlaybackSpeed)
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
    public var speed: PlaybackSpeed
    public init(seconds: Double, date: Date?, lag: Double?, capturedAt: Date, playing: Bool, speed: PlaybackSpeed = .normal) {
        self.seconds = seconds; self.date = date; self.lag = lag; self.capturedAt = capturedAt; self.playing = playing
        self.speed = speed
    }
    func elapsed(at now: Date) -> Double {
        playing ? max(0, now.timeIntervalSince(capturedAt)) * Double(speed.rawValue) : 0
    }
}

@MainActor public final class LinkedPlaybackCoordinator {
    public private(set) var participants: [any LinkedPlaybackParticipant] = []
    public private(set) var wantsPlayback = true
    public private(set) var playbackSpeed = PlaybackSpeed.normal
    public var isScrubbing = false
    public var onSeekFailure: ((String) -> Void)?
    public var onUserSeekCompleted: ((Double) -> Void)?
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
        participant.setPlaybackSpeed(participant.live ? .normal : playbackSpeed)
        participants.append(participant); joining.insert(participant.id); tick()
    }
    public func remove(id: String) {
        guard let participant = participants.first(where: { $0.id == id }) else { return }
        participant.cancelSeek()
        participants.removeAll { $0.id == id }; joining.remove(id); pending.remove(id); pendingSince.removeValue(forKey: id)
        seekIDs.removeValue(forKey: id)
        if referenceID == id { referenceID = nil }
        if participants.isEmpty {
            resumeAnchor = nil; isScrubbing = false; wantsPlayback = true
        }
    }
    public func reset() {
        generation = UUID()
        participants.forEach { $0.cancelSeek(); $0.pause() }
        participants.removeAll(); pending.removeAll(); pendingSince.removeAll(); joining.removeAll()
        seekIDs.removeAll()
        referenceID = nil; resumeAnchor = nil; isScrubbing = false; wantsPlayback = true
        playbackSpeed = .normal
    }
    public func capture() -> PlaybackAnchor? {
        guard let reference, reference.position.isFinite else { return resumeAnchor }
        return anchor(reference, seconds: reference.position)
    }
    public func restore(_ anchor: PlaybackAnchor?) {
        resumeAnchor = anchor
        if let anchor {
            wantsPlayback = anchor.playing
            setPlaybackSpeed(anchor.speed)
        }
    }
    public func setPlaybackSpeed(_ speed: PlaybackSpeed) {
        guard speed != playbackSpeed, !participants.contains(where: \.live) else { return }
        if var anchor = resumeAnchor {
            let now = clock()
            let elapsed = anchor.elapsed(at: now)
            anchor.seconds += elapsed
            anchor.date = anchor.date?.addingTimeInterval(elapsed)
            anchor.capturedAt = now
            anchor.speed = speed
            resumeAnchor = anchor
        }
        playbackSpeed = speed
        participants.forEach { $0.setPlaybackSpeed(speed) }
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
        for participant in participants {
            participant.pause()
            align(participant, to: target, onSuccess: participant.id == id ? onUserSeekCompleted : nil)
        }
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
                              capturedAt: clock(), playing: wantsPlayback, speed: source.live ? .normal : playbackSpeed)
    }
    private func desiredSeconds(_ participant: any LinkedPlaybackParticipant, _ anchor: PlaybackAnchor) -> Double? {
        guard let range = participant.seekRange else { return nil }
        let value: Double
        if let date = anchor.date, let ownDate = participant.programDate {
            value = participant.position + date.addingTimeInterval(anchor.elapsed(at: clock())).timeIntervalSince(ownDate)
        } else if participant.live, let lag = anchor.lag { value = range.upperBound - lag }
        else { value = anchor.seconds + anchor.elapsed(at: clock()) }
        guard value.isFinite else { return nil }
        return min(max(value, range.lowerBound), max(range.lowerBound, range.upperBound - 0.1))
    }
    private func align(_ participant: any LinkedPlaybackParticipant, to target: PlaybackAnchor,
                       onSuccess: ((Double) -> Void)? = nil) {
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
                onSuccess?(participant.position)
            } else { participant.pause(); self.joining.insert(id); self.onSeekFailure?(id) }
            if self.joining.isEmpty && self.pending.isEmpty { self.resumeAnchor = nil }
        }
        if let date = target.date, let ownDate = participant.programDate {
            let adjusted = date.addingTimeInterval(target.elapsed(at: clock()))
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

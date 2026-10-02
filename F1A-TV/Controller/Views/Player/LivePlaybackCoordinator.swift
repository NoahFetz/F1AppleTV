import AVFoundation

struct PlaybackPositionSnapshot {
    let seconds: Double
    let date: Date?
    let lag: Double?
    let paused: Bool
    @MainActor init(_ player: AVPlayer) {
        seconds = player.currentTime().seconds; date = player.currentItem?.currentDate(); paused = player.rate == 0
        if player.currentItem?.duration.seconds.isFinite == false, let range = player.currentItem?.seekableTimeRanges.last?.timeRangeValue {
            lag = max(0.1, CMTimeRangeGetEnd(range).seconds - seconds)
        } else { lag = nil }
    }
    @MainActor func apply(to player: AVPlayer, isCurrent: @escaping () -> Bool = { true }, completion: @escaping (Bool) -> Void) {
        guard let item = player.currentItem else { completion(false); return }
        let target: Double
        if let lag, let range = item.seekableTimeRanges.last?.timeRangeValue {
            target = LiveTimeline.target(start: range.start.seconds, end: CMTimeRangeGetEnd(range).seconds, lag: lag) ?? .nan
        } else { target = seconds }
        let fallback = {
            guard isCurrent(), target.isFinite, player.currentItem === item else { completion(false); return }
            player.seek(to: CMTime(seconds: max(0, target), preferredTimescale: 600)) { done in DispatchQueue.main.async { completion(done) } }
        }
        if let date, item.currentDate() != nil {
            player.seek(to: date) { done in DispatchQueue.main.async { if done { completion(true) } else { fallback() } } }
        } else { fallback() }
    }
}

/// A small interface also used by deterministic live-window tests.
@MainActor
protocol LiveSeekSession: AnyObject {
    var identity: ObjectIdentifier { get }
    var ready: Bool { get }
    var range: (start: Double, end: Double)? { get }
    var position: Double { get }
    var date: Date? { get }
    func seek(time: Double, completion: @escaping (Bool) -> Void)
    func seek(date: Date, completion: @escaping (Bool) -> Void)
    func play()
    func cancelSeek()
}

extension LiveSeekSession { var identity: ObjectIdentifier { ObjectIdentifier(self) } }

@MainActor
final class AVLiveSeekSession: LiveSeekSession {
    weak var player: AVPlayer?
    private weak var item: AVPlayerItem?
    init(_ player: AVPlayer) { self.player = player; item = player.currentItem }
    var identity: ObjectIdentifier { player.map(ObjectIdentifier.init) ?? ObjectIdentifier(self) }
    var ready: Bool { player?.currentItem === item && item?.status == .readyToPlay }
    var range: (start: Double, end: Double)? {
        guard ready, let range = item?.seekableTimeRanges.last?.timeRangeValue else { return nil }
        return (range.start.seconds, CMTimeRangeGetEnd(range).seconds)
    }
    var position: Double { player?.currentTime().seconds ?? .nan }
    var date: Date? { item?.currentDate() }
    func seek(time: Double, completion: @escaping (Bool) -> Void) {
        guard ready, let player else { completion(false); return }
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { finished in
            DispatchQueue.main.async { completion(finished) }
        }
    }
    func seek(date: Date, completion: @escaping (Bool) -> Void) {
        guard ready, let player else { completion(false); return }
        player.seek(to: date) { finished in DispatchQueue.main.async { completion(finished) } }
    }
    func play() { if ready { player?.play() } }
    func cancelSeek() { item?.cancelPendingSeeks() }
}

/// One owned jump, cancelled by another seek, pause, stream removal, or dismissal.
@MainActor
final class LivePlaybackCoordinator {
    private var generation = UUID()
    private var sessions = [ObjectIdentifier: LiveSeekSession]()
    private var reference: LiveSeekSession?
    private var pending = Set<ObjectIdentifier>()
    private var timer: Timer?
    private var deadline = Date.distantPast
    private var referenceReady = false
    private var seeking = Set<ObjectIdentifier>()
    private var didReportFailure = false
    private let clock: () -> Date
    init(clock: @escaping () -> Date = Date.init) { self.clock = clock }
    var onFailure: (() -> Void)?
    var hasJump: Bool { reference != nil }
    var isSeeking: Bool { !referenceReady || !seeking.isEmpty || !pending.isEmpty }
    func jump(reference: LiveSeekSession, sessions: [LiveSeekSession]) {
        cancel()
        didReportFailure = false
        self.reference = reference
        self.sessions = Dictionary(sessions.map { ($0.identity, $0) }, uniquingKeysWith: { first, _ in first })
        self.sessions[reference.identity] = reference
        pending = Set(self.sessions.keys)
        deadline = clock().addingTimeInterval(20)
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in Task { @MainActor in self?.preparePending() } }
        preparePending()
    }
    func include(_ session: LiveSeekSession) {
        guard hasJump else { return }
        let id = session.identity
        sessions[id] = session; pending.insert(id)
        deadline = clock().addingTimeInterval(20)
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in Task { @MainActor in self?.preparePending() } }
        }
        preparePending()
    }
    func preparePending() {
        guard let reference else { return }
        if clock() > deadline {
            let failed = !pending.isEmpty || !seeking.isEmpty || !referenceReady
            if failed { cancel(); reportFailure() } else { timer?.invalidate(); timer = nil }
            return
        }
        let identity = generation
        let refID = reference.identity
        if !referenceReady {
            guard pending.contains(refID), reference.ready, let range = reference.range,
                  let target = LiveTimeline.target(start: range.start, end: range.end) else { return }
            pending.remove(refID)
            seeking.insert(refID)
            reference.seek(time: target) { [weak self, weak reference] finished in
                guard let self, let reference, self.generation == identity else { return }
                self.seeking.remove(refID)
                guard finished else { self.cancel(); self.reportFailure(); return }
                reference.play(); self.referenceReady = true; self.preparePending()
            }
            return
        }
        for id in Array(pending) {
            guard let session = sessions[id], session.ready, let range = session.range,
                  let referenceRange = reference.range else { continue }
            let lag = max(0.1, referenceRange.end - reference.position)
            guard let target = LiveTimeline.target(start: range.start, end: range.end, lag: lag) else { continue }
            pending.remove(id)
            seeking.insert(id)
            let finish: (Bool) -> Void = { [weak self, weak session] finished in
                guard let self, let session, self.generation == identity else { return }
                self.seeking.remove(id)
                if finished { session.play() } else { self.reportFailure() }
            }
            if let date = reference.date, session.date != nil {
                session.seek(date: date) { [weak self, weak session] finished in
                    guard let self, let session, self.generation == identity else { return }
                    if finished { finish(true) } else { session.seek(time: target, completion: finish) }
                }
            } else { session.seek(time: target, completion: finish) }
        }
    }
    func cancel() {
        generation = UUID(); timer?.invalidate(); timer = nil
        sessions.values.forEach { $0.cancelSeek() }; sessions.removeAll(); pending.removeAll()
        reference = nil; referenceReady = false
        seeking.removeAll()
    }
    private func reportFailure() {
        guard !didReportFailure else { return }
        didReportFailure = true; onFailure?()
    }
    deinit { timer?.invalidate() }
}

@MainActor
enum StreamSynchronization {
    static func seek(_ player: AVPlayer, to reference: AVPlayer, isCurrent: @escaping () -> Bool = { true }, completion: @escaping (Bool) -> Void) {
        guard let item = player.currentItem, let refItem = reference.currentItem else { completion(false); return }
        let target: Double
        if !refItem.duration.seconds.isFinite,
           let ownRange = item.seekableTimeRanges.last?.timeRangeValue,
           let refRange = refItem.seekableTimeRanges.last?.timeRangeValue {
            target = LiveTimeline.target(start: ownRange.start.seconds, end: CMTimeRangeGetEnd(ownRange).seconds,
                                         lag: max(0.1, CMTimeRangeGetEnd(refRange).seconds - reference.currentTime().seconds)) ?? .nan
        } else { target = reference.currentTime().seconds }
        let seekTime = {
            guard isCurrent(), target.isFinite, player.currentItem === item else { completion(false); return }
            let range = item.seekableTimeRanges.last?.timeRangeValue
            let lower = range?.start.seconds ?? 0
            let upper = range.map { CMTimeRangeGetEnd($0).seconds - 0.1 } ?? (item.duration.seconds.isFinite ? item.duration.seconds : target)
            player.seek(to: CMTime(seconds: max(lower, min(target, max(lower, upper))), preferredTimescale: 600)) { done in
                DispatchQueue.main.async { completion(done) }
            }
        }
        if let date = refItem.currentDate(), item.currentDate() != nil {
            player.seek(to: date) { done in DispatchQueue.main.async { if done { completion(true) } else { seekTime() } } }
        } else { seekTime() }
    }
}

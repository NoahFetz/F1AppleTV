import Foundation

/// Muted previews follow the linked session without becoming reference feeds.
/// Hidden neighbours stay prepared and paused; showing them aligns them immediately.
@MainActor public final class LinkedPreviewCoordinator {
    private let session: LinkedPlaybackCoordinator
    private let clock: () -> Date
    private var participants: [String: any LinkedPlaybackParticipant] = [:]
    private var visible = Set<String>()
    private var pending: [String: (UUID, Date)] = [:]
    public init(session: LinkedPlaybackCoordinator, clock: @escaping () -> Date = Date.init) { self.session = session; self.clock = clock }
    public func add(_ participant: any LinkedPlaybackParticipant) { participants[participant.id] = participant; tick() }
    public func remove(_ id: String) { participants.removeValue(forKey: id)?.cancelSeek(); pending.removeValue(forKey: id); visible.remove(id) }
    public func setVisible(_ ids: Set<String>) { visible = ids; tick() }
    public func reset() {
        participants.values.forEach { $0.cancelSeek(); $0.pause() }
        participants.removeAll(); pending.removeAll(); visible.removeAll()
    }
    public func tick() {
        for (id, (_, started)) in pending where clock().timeIntervalSince(started) > 5 {
            participants[id]?.cancelSeek(); pending.removeValue(forKey: id)
        }
        let suspended = session.isScrubbing || session.hasPendingSeek || session.participants.contains { $0.changingQuality }
        for participant in participants.values {
            guard visible.contains(participant.id), !suspended else { participant.pause(); continue }
            if !session.wantsPlayback { participant.pause() }
            guard participant.ready, !participant.buffering, !participant.changingQuality, pending[participant.id] == nil else { continue }
            guard let anchor = session.capture(), let seconds = session.targetPosition(for: participant, anchor: anchor) else { participant.pause(); continue }
            let drift = participant.position.isFinite ? abs(participant.position - seconds) : .infinity
            if drift > 0.5 { align(participant, anchor: anchor, seconds: seconds) }
            else if session.wantsPlayback { participant.play() } else { participant.pause() }
        }
    }
    private func align(_ participant: any LinkedPlaybackParticipant, anchor: PlaybackAnchor, seconds: Double) {
        let id = participant.id, seek = UUID()
        pending[id] = (seek, clock()); participant.pause()
        let finish: (Bool) -> Void = { [weak self, weak participant] success in
            guard let self, let participant, self.participants[id] === participant, self.pending[id]?.0 == seek else { return }
            self.pending.removeValue(forKey: id)
            if success && self.visible.contains(id) && self.session.wantsPlayback && !self.session.isScrubbing && !self.session.hasPendingSeek && !self.session.participants.contains(where: { $0.changingQuality }) {
                participant.play()
            } else { participant.pause() }
        }
        if let date = anchor.date, let ownDate = participant.programDate {
            let elapsed = anchor.playing ? max(0, clock().timeIntervalSince(anchor.capturedAt)) : 0
            let target = date.addingTimeInterval(elapsed)
            if abs(participant.position + target.timeIntervalSince(ownDate) - seconds) < 0.2 {
                participant.seek(date: target) { [weak self, weak participant] success in
                    guard let self, let participant, self.participants[id] === participant, self.pending[id]?.0 == seek else { return }
                    if success { finish(true) } else { participant.seek(seconds: seconds, completion: finish) }
                }
                return
            }
        }
        participant.seek(seconds: seconds, completion: finish)
    }
}

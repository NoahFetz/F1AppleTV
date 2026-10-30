import AVKit
import MediaPlayer
import F1Core

enum TVRemotePlaybackAction: Sendable {
    case play, pause, toggle, skip(Double), seek(Double)
}

/// The custom viewer publishes one entry. Native AVKit owns its own session;
/// stop() releases every player and command registration before that handoff.
@MainActor final class TVNowPlayingCoordinator: NSObject, MPNowPlayingSessionDelegate {
    private(set) var session: MPNowPlayingSession?
    private(set) var ownerID: String?
    private var generation = UUID()
    private var targets: [(MPRemoteCommand, Any)] = []
    private var observations: [NSKeyValueObservation] = []
    private var observedPlayers: [AVPlayer] = []
    private var artworkData: Data?
    private var artwork: MPMediaItemArtwork?
    var onRefresh: (() -> Void)?
    var onCommand: ((TVRemotePlaybackAction) -> Void)?

    func update(feeds: [PlayerItem], playing: Bool, live: Bool) {
        let ordered = feeds.sorted { $0.position < $1.position }
        let states = ordered.map { feed in
            NowPlayingFeed(id: feed.id, isAvailable: !feed.hasFailed &&
                (feed.player?.currentItem?.status == .readyToPlay || feed.player?.resolutionStatus == .switching),
                isMuted: feed.player?.isMuted ?? true, volume: feed.player?.volume ?? 0)
        }
        guard let id = NowPlayingFeed.owner(in: states), let owner = ordered.first(where: { $0.id == id }),
              let player = owner.player else { stop(); return }
        let players = ordered.filter { feed in states.contains { $0.id == feed.id && $0.isAvailable } }.compactMap(\.player)
        if let session, players.count != session.players.count ||
            zip(players, session.players).contains(where: { $0 !== $1 }) {
            // Replace the session as a unit. removePlayer() attempts to remove
            // automatic metadata observers even when automatic publishing is off
            // on tvOS, which can raise an Objective-C KVO exception.
            stop()
        }
        if session == nil {
            let value = MPNowPlayingSession(players: players)
            value.automaticallyPublishesNowPlayingInfo = false; value.delegate = self
            session = value
            registerCommands(value.remoteCommandCenter)
        }
        observe(players)
        ownerID = id
        let metadata = player.playbackMetadata ?? PlaybackMetadata(session: owner.contentItem, channel: owner.contentItem.channel, feedTitle: owner.contentItem.title)
        var info: [String: Any] = [MPMediaItemPropertyTitle: metadata.title, MPMediaItemPropertyArtist: metadata.subtitle,
                                 MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
                                 MPNowPlayingInfoPropertyExternalContentIdentifier: owner.contentItem.contentId ?? id,
                                 MPNowPlayingInfoPropertyIsLiveStream: live,
                                 MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
                                 MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0]
        let time = player.currentTime().seconds
        if time.isFinite, time >= 0 { info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time }
        if !live, let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if live, let date = player.currentItem?.currentDate() { info[MPNowPlayingInfoPropertyCurrentPlaybackDate] = date }
        if metadata.artworkData != artworkData {
            artworkData = metadata.artworkData
            artwork = metadata.artworkData.flatMap(UIImage.init(data:)).map { image in
                MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            }
        }
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        session?.nowPlayingInfoCenter.nowPlayingInfo = info
        if session?.isActive == false { session?.becomeActiveIfPossible(completion: nil) }
    }

    private func observe(_ players: [FairPlayer]) {
        guard players.count != observedPlayers.count || zip(players, observedPlayers).contains(where: { $0 !== $1 }) else { return }
        observations.removeAll(); observedPlayers = players
        for player in players {
            observations.append(player.observe(\.volume, options: [.new]) { [weak self] _, _ in Task { @MainActor in self?.onRefresh?() } })
            observations.append(player.observe(\.isMuted, options: [.new]) { [weak self] _, _ in Task { @MainActor in self?.onRefresh?() } })
            observations.append(player.observe(\.currentItem, options: [.new]) { [weak self] _, _ in Task { @MainActor in self?.onRefresh?() } })
        }
    }
    func nowPlayingSessionDidChangeCanBecomeActive(_ nowPlayingSession: MPNowPlayingSession) {
        guard session === nowPlayingSession, nowPlayingSession.canBecomeActive else { return }
        nowPlayingSession.becomeActiveIfPossible(completion: nil)
    }
    private func registerCommands(_ center: MPRemoteCommandCenter) {
        let identity = generation
        func register(_ command: MPRemoteCommand, action: @escaping (MPRemoteCommandEvent) -> TVRemotePlaybackAction?) {
            command.isEnabled = true
            let token = command.addTarget { [weak self] event in
                guard self != nil, let value = action(event) else { return .commandFailed }
                Task { @MainActor [weak self] in
                    guard let self, self.generation == identity, self.session != nil else { return }
                    self.onCommand?(value)
                }
                return .success
            }
            targets.append((command, token))
        }
        register(center.playCommand) { _ in .play }
        register(center.pauseCommand) { _ in .pause }
        register(center.togglePlayPauseCommand) { _ in .toggle }
        center.skipForwardCommand.preferredIntervals = [10]; center.skipBackwardCommand.preferredIntervals = [10]
        register(center.skipForwardCommand) { .skip(($0 as? MPSkipIntervalCommandEvent)?.interval ?? 10) }
        register(center.skipBackwardCommand) { .skip(-(($0 as? MPSkipIntervalCommandEvent)?.interval ?? 10)) }
        register(center.changePlaybackPositionCommand) {
            guard let event = $0 as? MPChangePlaybackPositionCommandEvent, event.positionTime.isFinite else { return nil }
            return .seek(event.positionTime)
        }
    }
    func stop() {
        generation = UUID()
        for (command, target) in targets { command.removeTarget(target) }
        targets.removeAll(); observations.removeAll(); observedPlayers.removeAll()
        let previous = session
        session = nil; ownerID = nil
        previous?.delegate = nil
        previous?.nowPlayingInfoCenter.nowPlayingInfo = nil
        artwork = nil; artworkData = nil
    }
    deinit {
        for (command, target) in targets { command.removeTarget(target) }
    }
}

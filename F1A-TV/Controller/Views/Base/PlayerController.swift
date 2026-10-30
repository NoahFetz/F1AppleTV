#if canImport(F1Core)
import F1Core
#endif
//
//  PlayerController.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 13.12.20.
//

import Foundation
import AVKit

/// Playback owners register real feeds only; muted browsing previews must not
/// keep the TV awake. A fullscreen transition can temporarily have two owners.
@MainActor
final class PlaybackIdleTimer {
    static let shared = PlaybackIdleTimer()
    @MainActor private final class Owner {
        weak var object: AnyObject?
        let players: [AVPlayer]
        var observations: [NSKeyValueObservation] = []
        var itemObservations: [ObjectIdentifier: NSKeyValueObservation] = [:]
        init(_ object: AnyObject, players: [AVPlayer]) { self.object = object; self.players = players }
    }
    private var owners: [ObjectIdentifier: Owner] = [:]
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    func setPlayers(_ players: [AVPlayer], owner: AnyObject) {
        let identity = ObjectIdentifier(owner)
        guard !players.isEmpty else { remove(identity); return }
        let entry = Owner(owner, players: players)
        owners[identity] = entry
        for player in players {
            player.preventsDisplaySleepDuringVideoPlayback = true
            let changed: () -> Void = { [weak self] in
                Task { @MainActor in self?.refresh() }
            }
            entry.observations.append(player.observe(\.timeControlStatus, options: [.new]) { _, _ in changed() })
            entry.observations.append(player.observe(\.rate, options: [.new]) { _, _ in changed() })
            entry.observations.append(player.observe(\.currentItem, options: [.new]) { [weak self, weak entry, weak player] _, _ in
                Task { @MainActor in
                    guard let self, let entry, let player else { return }
                    self.observeItemStatus(player, owner: entry); self.refresh()
                }
            })
            observeItemStatus(player, owner: entry)
        }
        refresh()
    }
    private func observeItemStatus(_ player: AVPlayer, owner: Owner) {
        let identity = ObjectIdentifier(player)
        owner.itemObservations[identity] = player.currentItem?.observe(\.status, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    func remove(_ identity: ObjectIdentifier) { owners.removeValue(forKey: identity); refresh() }
    @objc private func refresh(_ notification: Notification? = nil) {
        owners = owners.filter { $0.value.object != nil }
        let active = notification?.name != UIApplication.willResignActiveNotification && UIApplication.shared.applicationState == .active
        UIApplication.shared.isIdleTimerDisabled = active && owners.values.contains { owner in
            owner.players.contains { player in
                player.currentItem != nil && player.currentItem?.status != .failed && player.timeControlStatus != .paused
            }
        }
    }
}

@MainActor
class PlayerController: NSObject, @preconcurrency AVPlayerViewControllerDelegate {
    private var entitlementTask: Task<Void, Never>?
    private var entitlementGeneration = UUID()
    private weak var pendingOwner: UIViewController?
    private weak var services: AppServices?
    
    var playFromStart = false
    var playerItem = PlayerItem()
    
    var fullscreenPlayerDismissedProtocol: FullscreenPlayerDismissedProtocol?
    private var defaultsObservation: NSKeyValueObservation?
    private var defaultsTask: Task<Void, Never>?
    private var resolutionObserver: NSObjectProtocol?
    private let liveCoordinator = LivePlaybackCoordinator()
    private var nativeTimeObserver: Any?
    private var nativeRateObservation: NSKeyValueObservation?
    private weak var observedPlayer: AVPlayer?
    private var liveMenuState: String?
    private var mediaChannel = ChannelType.MainFeed
    private var liveSession = false
    private weak var presentedPlayerController: AVPlayerViewController?
    private var availableChannels: [PlaybackChannel] = []
    private var selectedChannel: PlaybackChannel?
    private var sessionItem: ContentItem?
    private var metadataBinding = PlaybackMetadataBinding()
    private var feedSwitch: NativeFeedSwitch?
    private let feedSwitchTimeout: TimeInterval

    private final class NativeFeedSwitch {
        let channel: PlaybackChannel
        let player = FairPlayer()
        @MainActor lazy var metadataBinding = PlaybackMetadataBinding()
        lazy var layer = AVPlayerLayer(player: player)
        var task: Task<Void, Never>?
        var observation: NSKeyValueObservation?
        var timeout: DispatchWorkItem?
        var restoring = false
        init(channel: PlaybackChannel) { self.channel = channel }
        deinit { task?.cancel(); timeout?.cancel() }
    }
    
    init(feedSwitchTimeout: TimeInterval = 30) {
        self.feedSwitchTimeout = feedSwitchTimeout
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.avPlayerDidDismiss), name: .avPlayerDidDismiss, object: nil)
    }
    
    deinit {
        let identity = ObjectIdentifier(self)
        let pendingPlayer = feedSwitch?.player
        let pendingLayer = feedSwitch?.layer
        Task { @MainActor in
            pendingLayer?.player = nil; pendingLayer?.removeFromSuperlayer()
            pendingPlayer?.stopStream()
            PlaybackIdleTimer.shared.remove(identity)
        }
        entitlementTask?.cancel()
        defaultsTask?.cancel()
        feedSwitch?.task?.cancel(); feedSwitch?.timeout?.cancel()
        if let nativeTimeObserver { observedPlayer?.removeTimeObserver(nativeTimeObserver) }
        if let observer = resolutionObserver { NotificationCenter.default.removeObserver(observer) }
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func avPlayerDidDismiss(_ notification: Notification) {
        guard let dismissed = notification.object as? AVPlayerViewController,
              dismissed === presentedPlayerController else { return }
        cancelNativeFeedSwitch()
        metadataBinding.cancel(); sessionItem = nil
        availableChannels = []; selectedChannel = nil
        entitlementGeneration = UUID(); entitlementTask?.cancel(); entitlementTask = nil; pendingOwner = nil
        PlaybackIdleTimer.shared.setPlayers([], owner: self)
        defaultsObservation = nil
        defaultsTask?.cancel()
        liveCoordinator.cancel()
        if let nativeTimeObserver { observedPlayer?.removeTimeObserver(nativeTimeObserver) }
        nativeRateObservation = nil
        nativeTimeObserver = nil; observedPlayer = nil; liveMenuState = nil
        defaultsTask = nil
        presentedPlayerController = nil
        if let observer = resolutionObserver { NotificationCenter.default.removeObserver(observer) }
        resolutionObserver = nil
        if fullscreenPlayerDismissedProtocol == nil {
            playerItem.player?.stopStream()
        }
        dismissed.player = nil
        let dismissedProtocol = fullscreenPlayerDismissedProtocol
        fullscreenPlayerDismissedProtocol = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismissedProtocol?.fullscreenPlayerDidDismiss()
        }
    }
    
    func playVideo(_ video: VideoDetails, playFromStart: Bool, services: AppServices, owner: UIViewController) {
        guard let channel = PlaybackSelection.initialChannel(in: video.channels, preference: CredentialHelper.getPlayerSettings().defaultFeed) else { return }
        beginStream(contentId: channel.target.uri, playFromStart: playFromStart, services: services, owner: owner,
                    channel: channel.kind, isLive: video.isLive, channels: video.channels, selected: channel, sessionItem: video.item)
    }

    func playStream(contentId: String, playFromStart: Bool? = false, services: AppServices, owner: UIViewController, channel: ChannelType = .MainFeed, isLive: Bool = false, sessionItem: ContentItem? = nil) {
        beginStream(contentId: contentId, playFromStart: playFromStart ?? false, services: services, owner: owner,
                    channel: channel, isLive: isLive, channels: [], selected: nil, sessionItem: sessionItem)
    }

    private func beginStream(contentId: String, playFromStart: Bool, services: AppServices, owner: UIViewController,
                             channel: ChannelType, isLive: Bool, channels: [PlaybackChannel], selected: PlaybackChannel?, sessionItem: ContentItem?) {
        cancelNativeFeedSwitch()
        defaultsObservation = nil; defaultsTask?.cancel(); defaultsTask = nil
        availableChannels = channels; selectedChannel = selected
        self.sessionItem = sessionItem
        metadataBinding.cancel()
        self.playFromStart = playFromStart
        self.mediaChannel = channel; self.liveSession = isLive
        self.services = services; pendingOwner = owner
        entitlementTask?.cancel(); let generation = UUID(); entitlementGeneration = generation
        let playback = services.playback
        entitlementTask = Task { [weak self, weak owner] in
            do {
                let entitlement = try await playback.entitlement(PlaybackTarget(uri: contentId, requiresVideoDetails: false))
                try Task.checkCancellation()
                guard let self, self.entitlementGeneration == generation, owner?.viewIfLoaded?.window != nil else { return }
                self.pendingOwner = nil; self.entitlementTask = nil
                self.didLoadStreamEntitlement(streamEntitlement: entitlement)
            } catch {
                guard let self, self.entitlementGeneration == generation, owner?.viewIfLoaded?.window != nil, !Task.isCancelled, !(error is CancellationError) else { return }
                recordServiceFailure(error, operation: .entitlement)
                UserInteractionHelper.instance.showError(title: "error".localizedString, message: "diagnostics_summary_operation".localizedString, recordsError: false, retry: { [weak self, weak owner] in
                    guard let owner, owner.viewIfLoaded?.window != nil else { return }
                    self?.beginStream(contentId: contentId, playFromStart: playFromStart, services: services, owner: owner,
                                      channel: channel, isLive: isLive, channels: channels, selected: selected, sessionItem: sessionItem)
                })
            }
        }
    }

    func cancelPending(for owner: UIViewController) {
        guard pendingOwner === owner else { return }
        entitlementGeneration = UUID(); entitlementTask?.cancel(); entitlementTask = nil; pendingOwner = nil
    }

    private func didLoadStreamEntitlement(streamEntitlement: PlaybackEntitlement) {
        var localPlayerItem = selectedChannel.map { PlayerItem(contentItem: $0.displayItem, position: 0) } ?? PlayerItem()
        localPlayerItem.entitlement = streamEntitlement
        
        localPlayerItem.player = FairPlayer(); localPlayerItem.player?.onPlaybackError = tvPlaybackError
        localPlayerItem.player?.fairPlayService = services?.fairPlay
        localPlayerItem.player?.playStream(streamEntitlement: streamEntitlement)
        self.playerItem = localPlayerItem
        if let player = localPlayerItem.player { metadataBinding.bind(player: player, metadata: metadata(for: selectedChannel)) }
        let fromStart = self.playFromStart
        if let player = localPlayerItem.player { self.openPlayer(player: player, standalone: true) }
        let settings = CredentialHelper.getPlayerSettings()
        let channel = mediaChannel
        let isF1Live = selectedChannel.map { StreamSelection(channel: $0) == .f1Live } ?? false
        localPlayerItem.player?.prepareStream(startupMaximumHeight: settings.startupMaximumHeight) { [weak self, weak player = localPlayerItem.player] item in
            guard let self = self, let player = player, self.playerItem.player === player,
                  self.presentedPlayerController?.player === player else { return }
            self.defaultsObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak player] item, _ in
                DispatchQueue.main.async {
                    guard let self, let player, self.playerItem.player === player, player.currentItem === item, item.status == .readyToPlay else { return }
                    self.defaultsObservation = nil
                    self.defaultsTask?.cancel()
                    self.defaultsTask = Task { @MainActor [weak self, weak player] in
                        await PlaybackDefaults.apply(to: item, channel: channel, settings: settings, isF1Live: isF1Live) {
                            self?.playerItem.player === player && player?.currentItem === item && self?.presentedPlayerController?.player === player
                        }
                    }
                    player.volume = settings.getPreferredVolume(for: channel)
                    player.isMuted = settings.getPreferredMute(for: channel)
                }
            }
            if fromStart {
                player.seek(to: CMTimeMakeWithSeconds(1, preferredTimescale: 1))
            }
            player.play()
        }
    }
    
    func openPlayer(player: AVPlayer, fullscreenPlayerDismissedProtocol: FullscreenPlayerDismissedProtocol? = nil, isLive: Bool? = nil, standalone: Bool = false) {
        if !standalone {
            cancelNativeFeedSwitch()
            availableChannels = []; selectedChannel = nil
        }
        PlaybackIdleTimer.shared.setPlayers([player], owner: self)
        self.fullscreenPlayerDismissedProtocol = fullscreenPlayerDismissedProtocol
        if let isLive { liveSession = isLive }
        
        let playerViewController = AVPlayerViewController()
        self.presentedPlayerController = playerViewController
        
        playerViewController.player = player
        // Native transport and trick-play remain available independently of the
        // custom multiview preview preference.
        playerViewController.showsPlaybackControls = true
        playerViewController.requiresLinearPlayback = false
        
        playerViewController.delegate = self
        playerViewController.allowsPictureInPicturePlayback = true
        bindPlayer(player, controller: playerViewController)
        UserInteractionHelper.instance.getPresentingViewController()?.present(playerViewController, animated: true) {
            if playerViewController.player?.currentItem != nil { playerViewController.player?.play() }
        }
    }

    private func bindPlayer(_ player: AVPlayer, controller playerViewController: AVPlayerViewController) {
        liveCoordinator.cancel()
        if let observer = resolutionObserver { NotificationCenter.default.removeObserver(observer) }
        resolutionObserver = nil
        if let fairPlayer = player as? FairPlayer {
            updateTransportMenu(controller: playerViewController, player: fairPlayer)
            resolutionObserver = NotificationCenter.default.addObserver(forName: FairPlayer.resolutionDidChange, object: fairPlayer, queue: .main) { [weak self, weak playerViewController, weak fairPlayer] _ in
                MainActor.assumeIsolated {
                    guard let self, let controller = playerViewController, let player = fairPlayer,
                          self.presentedPlayerController === controller, controller.player === player else { return }
                    self.updateTransportMenu(controller: controller, player: player)
                }
            }
        }
        if let nativeTimeObserver { observedPlayer?.removeTimeObserver(nativeTimeObserver) }
        observedPlayer = player; liveMenuState = nil
        nativeRateObservation = player.observe(\.rate, options: [.old, .new]) { [weak self, weak player] _, change in
            guard let old = change.oldValue, let new = change.newValue, old > 0, new == 0 else { return }
            DispatchQueue.main.async {
                guard let self, self.observedPlayer === player, self.liveCoordinator.hasJump else { return }
                self.liveCoordinator.cancel()
            }
        }
        nativeTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self, weak playerViewController, weak player] _ in
            MainActor.assumeIsolated {
                guard let self, let controller = playerViewController, let player else { return }
                guard self.presentedPlayerController === controller, controller.player === player else { return }
                let range = player.currentItem?.seekableTimeRanges.last?.timeRangeValue
                let state = range.map { LiveTimeline.isAtLive(position: player.currentTime().seconds, end: CMTimeRangeGetEnd($0).seconds) ? "live" : "behind" } ?? "unavailable"
                if self.liveMenuState != state {
                    self.liveMenuState = state
                    self.updateTransportMenu(controller: controller, player: player)
                }

            }
        }

    }

    /// A candidate stays paused and muted until readiness, defaults and alignment
    /// succeed. The currently presented feed owns transport and audio throughout.
    func selectNativeFeed(id: String) {
        guard feedSwitch == nil, fullscreenPlayerDismissedProtocol == nil,
              let channel = availableChannels.first(where: { $0.id == id }), channel.id != selectedChannel?.id,
              let controller = presentedPlayerController, controller.viewIfLoaded?.window != nil,
              let source = controller.player, source.currentItem?.status == .readyToPlay,
              let services else { return }
        let attempt = NativeFeedSwitch(channel: channel)
        feedSwitch = attempt
        attempt.player.isMuted = true
        // Give live HLS a rendering output while it prepares and seeks. The
        // current feed remains visible; this surface never presents a picture.
        attempt.layer.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        attempt.layer.opacity = 0
        controller.view.layer.insertSublayer(attempt.layer, at: 0)
        attempt.player.fairPlayService = services.fairPlay
        attempt.player.onPlaybackError = { [weak self, weak attempt] error in
            guard let self, let attempt, self.feedSwitch === attempt else { return }
            self.failNativeFeedSwitch(attempt, error: error)
        }
        let timeout = DispatchWorkItem { [weak self, weak attempt] in
            guard let self, let attempt, self.feedSwitch === attempt else { return }
            self.failNativeFeedSwitch(attempt, error: URLError(.timedOut))
        }
        attempt.timeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + feedSwitchTimeout, execute: timeout)
        updateTransportMenu(controller: controller, player: source)
        let playback = services.playback
        let settings = CredentialHelper.getPlayerSettings()
        attempt.task = Task { [weak self, weak attempt, weak controller, weak source] in
            do {
                let entitlement = try await playback.entitlement(channel.target)
                try Task.checkCancellation()
                guard let self, let attempt, let controller, let source,
                      self.feedSwitch === attempt, self.presentedPlayerController === controller, controller.player === source else { return }
                attempt.player.playStream(streamEntitlement: entitlement)
                attempt.metadataBinding.bind(player: attempt.player, metadata: self.metadata(for: attempt.channel))
                attempt.player.prepareStream(startupMaximumHeight: settings.startupMaximumHeight) { [weak self, weak attempt, weak controller, weak source] item in
                    guard let self, let attempt, let controller, let source,
                          self.feedSwitch === attempt, controller.player === source else { return }
                    attempt.observation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak attempt, weak controller, weak source] item, _ in
                        DispatchQueue.main.async {
                            guard let self, let attempt, let controller, let source, self.feedSwitch === attempt,
                                  controller.player === source, attempt.player.currentItem === item else { return }
                            if item.status == .failed {
                                self.failNativeFeedSwitch(attempt, error: item.error ?? URLError(.cannotDecodeContentData))
                            } else if item.status == .readyToPlay, !attempt.restoring {
                                attempt.restoring = true
                                attempt.observation = nil
                                self.alignNativeFeed(attempt, source: source, controller: controller, settings: settings)
                            }
                        }
                    }
                }
            } catch {
                guard let self, let attempt, self.feedSwitch === attempt, !Task.isCancelled, !(error is CancellationError) else { return }
                self.failNativeFeedSwitch(attempt, error: error)
            }
        }
    }

    private func alignNativeFeed(_ attempt: NativeFeedSwitch, source: AVPlayer, controller: AVPlayerViewController, settings: PlayerSettings) {
        attempt.task = Task { @MainActor [weak self, weak attempt, weak source, weak controller] in
            guard let attempt, let source, let controller, let item = attempt.player.currentItem else { return }
            await PlaybackDefaults.apply(to: item, channel: attempt.channel.kind, settings: settings,
                                         isF1Live: StreamSelection(channel: attempt.channel) == .f1Live) { [weak self] in
                self?.feedSwitch === attempt && controller.player === source
            }
            guard let self, !Task.isCancelled, self.feedSwitch === attempt, controller.player === source else { return }
            StreamSynchronization.seek(attempt.player, to: source, isCurrent: { [weak self] in
                self?.feedSwitch === attempt && controller.player === source
            }) { [weak self, weak attempt, weak source, weak controller] done in
                guard let self, let attempt, let source, let controller, self.feedSwitch === attempt,
                      self.presentedPlayerController === controller, controller.player === source else { return }
                guard done else { self.failNativeFeedSwitch(attempt, error: URLError(.cannotDecodeContentData)); return }
                let playing = source.rate != 0
                self.defaultsObservation = nil; self.defaultsTask?.cancel(); self.defaultsTask = nil
                self.feedSwitch = nil
                attempt.timeout?.cancel(); attempt.observation = nil
                self.metadataBinding.cancel(); self.metadataBinding = attempt.metadataBinding
                self.selectedChannel = attempt.channel; self.mediaChannel = attempt.channel.kind
                var next = PlayerItem(contentItem: attempt.channel.displayItem, position: 0)
                next.player = attempt.player; next.entitlement = attempt.player.streamEntitlement
                self.playerItem = next
                attempt.player.onPlaybackError = tvPlaybackError
                attempt.player.volume = settings.getPreferredVolume(for: attempt.channel.kind)
                attempt.player.isMuted = settings.getPreferredMute(for: attempt.channel.kind)
                controller.player = attempt.player
                attempt.layer.player = nil; attempt.layer.removeFromSuperlayer()
                self.bindPlayer(attempt.player, controller: controller)
                PlaybackIdleTimer.shared.setPlayers([attempt.player], owner: self)
                if playing { attempt.player.play() } else { attempt.player.pause() }
                if let source = source as? FairPlayer { source.stopStream() } else { source.pause() }
            }
        }
    }

    private func failNativeFeedSwitch(_ attempt: NativeFeedSwitch, error: Error) {
        guard feedSwitch === attempt else { return }
        cancelNativeFeedSwitch()
        recordServiceFailure(error, operation: .preparation)
        if let controller = presentedPlayerController, let player = controller.player {
            updateTransportMenu(controller: controller, player: player)
            UserInteractionHelper.instance.showError(title: "error".localizedString, message: "player_feed_failed".localizedString, recordsError: false)
        }
    }

    private func cancelNativeFeedSwitch() {
        guard let attempt = feedSwitch else { return }
        feedSwitch = nil
        attempt.task?.cancel(); attempt.timeout?.cancel(); attempt.observation = nil
        attempt.metadataBinding.cancel()
        attempt.player.onPlaybackError = nil
        attempt.layer.player = nil; attempt.layer.removeFromSuperlayer()
        attempt.player.stopStream()
    }

    private func metadata(for channel: PlaybackChannel?) -> PlaybackMetadata? {
        guard let sessionItem else { return nil }
        let title = channel.flatMap { TVPlaybackChannels.items(for: [$0], settings: CredentialHelper.getPlayerSettings()).first?.title }
        return PlaybackMetadata(session: sessionItem, channel: channel, feedTitle: title)
    }

    private func updateTransportMenu(controller: AVPlayerViewController, player: AVPlayer) {
        var items: [UIMenuElement] = []
        if let player = player as? FairPlayer { items.append(player.resolutionMenu()) }
        if availableChannels.count > 1, fullscreenPlayerDismissedProtocol == nil {
            let switching = feedSwitch != nil
            let channels = TVPlaybackChannels.items(for: availableChannels, settings: CredentialHelper.getPlayerSettings())
            var actions: [UIMenuElement] = channels.compactMap { item in
                guard let channel = item.channel else { return nil }
                return UIAction(title: item.title ?? channel.title, identifier: UIAction.Identifier(channel.id),
                                attributes: switching ? [.disabled] : [], state: channel.id == selectedChannel?.id ? .on : .off) { [weak self] _ in
                    self?.selectNativeFeed(id: channel.id)
                }
            }
            if switching { actions.insert(UIAction(title: "player_feed_switching".localizedString, attributes: .disabled) { _ in }, at: 0) }
            items.append(UIMenu(title: "player_feed".localizedString, image: UIImage(systemName: "tv"), identifier: UIMenu.Identifier("native.feed"), children: actions))
        }
        if liveSession {
            let range = player.currentItem?.seekableTimeRanges.last?.timeRangeValue
            let available = range.flatMap { LiveTimeline.target(start: $0.start.seconds, end: CMTimeRangeGetEnd($0).seconds) } != nil
            let atLive = range.map { LiveTimeline.isAtLive(position: player.currentTime().seconds, end: CMTimeRangeGetEnd($0).seconds) } ?? false
            let action = UIAction(title: (atLive ? "live_status" : "go_live").localizedString, image: UIImage(systemName: "dot.radiowaves.left.and.right"), identifier: UIAction.Identifier("native.goLive"), attributes: available ? [] : [.disabled]) { [weak self, weak player, weak controller] _ in
                guard let self, let player, self.presentedPlayerController === controller, controller?.player === player else { return }
                let session = AVLiveSeekSession(player)
                self.liveCoordinator.onFailure = {
                    UserInteractionHelper.instance.showError(title: "error".localizedString, message: "go_live_failed".localizedString)
                }
                self.liveCoordinator.jump(reference: session, sessions: [session])
            }
            items.append(action)
        }
        controller.transportBarCustomMenuItems = items
    }

    func playerViewController(_ playerViewController: AVPlayerViewController, timeToSeekAfterUserNavigatedFrom oldTime: CMTime, to targetTime: CMTime) -> CMTime {
        liveCoordinator.cancel()
        return targetTime
    }

    public func playerViewController(_ playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        
        guard let currentviewController = UserInteractionHelper.instance.getPresentingViewController() else {
            completionHandler(false)
            return
        }
        if currentviewController != playerViewController{
            currentviewController.present(playerViewController, animated: true, completion: nil)
        }
        completionHandler(true)
    }
}

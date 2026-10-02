//
//  PlayerController.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 13.12.20.
//

import Foundation
import AVKit

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
    
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.avPlayerDidDismiss), name: .avPlayerDidDismiss, object: nil)
    }
    
    deinit {
        entitlementTask?.cancel()
        defaultsTask?.cancel()
        if let nativeTimeObserver { observedPlayer?.removeTimeObserver(nativeTimeObserver) }
        if let observer = resolutionObserver { NotificationCenter.default.removeObserver(observer) }
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func avPlayerDidDismiss(_ notification: Notification) {
        guard let dismissed = notification.object as? AVPlayerViewController,
              dismissed === presentedPlayerController else { return }
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
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            if let dismissedProtocol = self.fullscreenPlayerDismissedProtocol {
                dismissedProtocol.fullscreenPlayerDidDismiss()
            }
        }
    }
    
    func playStream(contentId: String, playFromStart: Bool? = false, services: AppServices, owner: UIViewController, channel: ChannelType = .MainFeed, isLive: Bool = false) {
        defaultsObservation = nil
        self.playFromStart = playFromStart ?? false
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
                    self?.playStream(contentId: contentId, playFromStart: playFromStart, services: services, owner: owner, channel: channel, isLive: isLive)
                })
            }
        }
    }

    func cancelPending(for owner: UIViewController) {
        guard pendingOwner === owner else { return }
        entitlementGeneration = UUID(); entitlementTask?.cancel(); entitlementTask = nil; pendingOwner = nil
    }

    private func didLoadStreamEntitlement(streamEntitlement: PlaybackEntitlement) {
        var localPlayerItem = PlayerItem()
        
        localPlayerItem.player = FairPlayer()
        localPlayerItem.player?.fairPlayService = services?.fairPlay
        localPlayerItem.player?.playStream(streamEntitlement: streamEntitlement)
        self.playerItem = localPlayerItem
        let fromStart = self.playFromStart
        if let player = localPlayerItem.player { self.openPlayer(player: player) }
        let settings = CredentialHelper.getPlayerSettings()
        let channel = mediaChannel
        localPlayerItem.player?.prepareStream(startupMaximumHeight: settings.startupMaximumHeight) { [weak self, weak player = localPlayerItem.player] item in
            guard let self = self, let player = player, self.playerItem.player === player,
                  self.presentedPlayerController?.player === player else { return }
            self.defaultsObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak player] item, _ in
                DispatchQueue.main.async {
                    guard let self, let player, self.playerItem.player === player, player.currentItem === item, item.status == .readyToPlay else { return }
                    self.defaultsObservation = nil
                    self.defaultsTask?.cancel()
                    self.defaultsTask = Task { @MainActor [weak self, weak player] in
                        await PlaybackDefaults.apply(to: item, channel: channel, settings: settings) {
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
    
    func openPlayer(player: AVPlayer, fullscreenPlayerDismissedProtocol: FullscreenPlayerDismissedProtocol? = nil, isLive: Bool? = nil) {
        self.fullscreenPlayerDismissedProtocol = fullscreenPlayerDismissedProtocol
        if let isLive { liveSession = isLive }
        
        let playerViewController = AVPlayerViewController()
        self.presentedPlayerController = playerViewController
        
        playerViewController.player = player
        
        playerViewController.delegate = self
        playerViewController.allowsPictureInPicturePlayback = true
        if let observer = resolutionObserver { NotificationCenter.default.removeObserver(observer) }
        resolutionObserver = nil
        if let fairPlayer = player as? FairPlayer {
            updateTransportMenu(controller: playerViewController, player: fairPlayer)
            resolutionObserver = NotificationCenter.default.addObserver(forName: FairPlayer.resolutionDidChange, object: fairPlayer, queue: .main) { [weak self, weak playerViewController, weak fairPlayer] _ in
                MainActor.assumeIsolated {
                    guard let self, let controller = playerViewController, let player = fairPlayer else { return }
                    self.updateTransportMenu(controller: controller, player: player)
                }
            }
        }
        if let nativeTimeObserver { observedPlayer?.removeTimeObserver(nativeTimeObserver) }
        observedPlayer = player; liveMenuState = nil
        nativeRateObservation = player.observe(\.rate, options: [.old, .new]) { [weak self] _, change in
            guard let old = change.oldValue, let new = change.newValue, old > 0, new == 0 else { return }
            DispatchQueue.main.async {
                guard let self, self.liveCoordinator.hasJump else { return }
                self.liveCoordinator.cancel()
            }
        }
        nativeTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self, weak playerViewController, weak player] _ in
            MainActor.assumeIsolated {
                guard let self, let controller = playerViewController, let player else { return }
                let range = player.currentItem?.seekableTimeRanges.last?.timeRangeValue
                let state = range.map { LiveTimeline.isAtLive(position: player.currentTime().seconds, end: CMTimeRangeGetEnd($0).seconds) ? "live" : "behind" } ?? "unavailable"
                if self.liveMenuState != state {
                    self.liveMenuState = state
                    self.updateTransportMenu(controller: controller, player: player)
                }

            }
        }

        UserInteractionHelper.instance.getPresentingViewController()?.present(playerViewController, animated: true) {
            if playerViewController.player?.currentItem != nil { playerViewController.player?.play() }
        }
    }
    
    private func updateTransportMenu(controller: AVPlayerViewController, player: AVPlayer) {
        var items: [UIMenuElement] = []
        if let player = player as? FairPlayer { items.append(player.resolutionMenu()) }
        if liveSession {
            let range = player.currentItem?.seekableTimeRanges.last?.timeRangeValue
            let available = range.flatMap { LiveTimeline.target(start: $0.start.seconds, end: CMTimeRangeGetEnd($0).seconds) } != nil
            let atLive = range.map { LiveTimeline.isAtLive(position: player.currentTime().seconds, end: CMTimeRangeGetEnd($0).seconds) } ?? false
            let action = UIAction(title: (atLive ? "live_status" : "go_live").localizedString, image: UIImage(systemName: "dot.radiowaves.left.and.right"), attributes: available ? [] : [.disabled]) { [weak self, weak player, weak controller] _ in
                guard let self, let player, self.presentedPlayerController === controller else { return }
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

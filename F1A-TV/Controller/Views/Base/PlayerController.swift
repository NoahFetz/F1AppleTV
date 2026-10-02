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
    private weak var presentedPlayerController: AVPlayerViewController?
    
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.avPlayerDidDismiss), name: .avPlayerDidDismiss, object: nil)
    }
    
    deinit {
        entitlementTask?.cancel()
        defaultsTask?.cancel()
        if let observer = resolutionObserver { NotificationCenter.default.removeObserver(observer) }
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func avPlayerDidDismiss(_ notification: Notification) {
        guard let dismissed = notification.object as? AVPlayerViewController,
              dismissed === presentedPlayerController else { return }
        defaultsTask?.cancel()
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
    
    func playStream(contentId: String, playFromStart: Bool? = false, services: AppServices, owner: UIViewController) {
        defaultsObservation = nil
        self.playFromStart = playFromStart ?? false
        
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
                    self?.playStream(contentId: contentId, playFromStart: playFromStart, services: services, owner: owner)
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
        localPlayerItem.player?.prepareStream(startupMaximumHeight: settings.startupMaximumHeight) { [weak self, weak player = localPlayerItem.player] item in
            guard let self = self, let player = player, self.playerItem.player === player,
                  self.presentedPlayerController?.player === player else { return }
            self.defaultsObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak player] item, _ in
                DispatchQueue.main.async {
                    guard let self, let player, self.playerItem.player === player, player.currentItem === item, item.status == .readyToPlay else { return }
                    self.defaultsObservation = nil
                    self.defaultsTask?.cancel()
                    self.defaultsTask = Task { @MainActor [weak self, weak player] in
                        await PlaybackDefaults.apply(to: item, channel: .MainFeed, settings: settings) {
                            self?.playerItem.player === player && player?.currentItem === item && self?.presentedPlayerController?.player === player
                        }
                    }
                    player.volume = settings.getPreferredVolume(for: .MainFeed)
                    player.isMuted = settings.getPreferredMute(for: .MainFeed)
                }
            }
            if fromStart {
                player.seek(to: CMTimeMakeWithSeconds(1, preferredTimescale: 1))
            }
            player.play()
        }
    }
    
    func openPlayer(player: AVPlayer, fullscreenPlayerDismissedProtocol: FullscreenPlayerDismissedProtocol? = nil) {
        self.fullscreenPlayerDismissedProtocol = fullscreenPlayerDismissedProtocol
        
        let playerViewController = AVPlayerViewController()
        self.presentedPlayerController = playerViewController
        
        playerViewController.player = player
        
        playerViewController.delegate = self
        playerViewController.allowsPictureInPicturePlayback = true
        if let observer = resolutionObserver { NotificationCenter.default.removeObserver(observer) }
        resolutionObserver = nil
        if let fairPlayer = player as? FairPlayer {
            playerViewController.transportBarCustomMenuItems = [fairPlayer.resolutionMenu()]
            resolutionObserver = NotificationCenter.default.addObserver(forName: FairPlayer.resolutionDidChange, object: fairPlayer, queue: .main) { [weak playerViewController, weak fairPlayer] _ in
                guard let fairPlayer = fairPlayer else { return }
                playerViewController?.transportBarCustomMenuItems = [fairPlayer.resolutionMenu()]
            }
        }
        
        UserInteractionHelper.instance.getPresentingViewController()?.present(playerViewController, animated: true) {
            if playerViewController.player?.currentItem != nil { playerViewController.player?.play() }
        }
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

//
//  PlayerController.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 13.12.20.
//

import Foundation
import AVKit

class PlayerController: NSObject, AVPlayerViewControllerDelegate, StreamEntitlementLoadedProtocol {
    static let instance = PlayerController()
    
    var playFromStart = false
    
    var fullscreenPlayerDismissedProtocol: FullscreenPlayerDismissedProtocol?
    
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.avPlayerDidDismiss), name: .avPlayerDidDismiss, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func avPlayerDidDismiss(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            if let dismissedProtocol = self.fullscreenPlayerDismissedProtocol {
                dismissedProtocol.fullscreenPlayerDidDismiss()
            }
        }
    }
    
    func playStream(contentId: String, playFromStart: Bool? = false) {
        self.playFromStart = playFromStart ?? false
        
        var contentUrl = contentId
        if(!contentUrl.starts(with: "CONTENT")){
            contentUrl = "CONTENT/PLAY?contentId=" + contentId
        }
        DataManager.instance.loadStreamEntitlement(contentId: contentUrl, streamEntitlementLoadedProtocol: self)
    }
    
    func didLoadStreamEntitlement(playerId: String, streamEntitlement: StreamEntitlementDto) {
        let fairPlayManager = FairPlayManager(streamEntitlement: streamEntitlement)
        
        let playerAsset = fairPlayManager.makeFairPlayReady() ?? AVAsset()
        let playerItem = AVPlayerItem(asset: playerAsset)
        let player = AVPlayer(playerItem: playerItem)
        
        if(self.playFromStart) {
            player.seek(to: CMTimeMakeWithSeconds(Float64(1), preferredTimescale: 1))
        }
        
        self.openPlayer(player: player)
    }
    
    func openPlayer(player: AVPlayer, fullscreenPlayerDismissedProtocol: FullscreenPlayerDismissedProtocol? = nil) {
        self.fullscreenPlayerDismissedProtocol = fullscreenPlayerDismissedProtocol
        
        let playerViewController = AVPlayerViewController()
        
        playerViewController.player = player
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch(let error) {
            print(error.localizedDescription)
        }
        
        playerViewController.delegate = self
        playerViewController.allowsPictureInPicturePlayback = true
        
        UserInteractionHelper.instance.getPresentingViewController().present(playerViewController, animated: true) {
            playerViewController.player?.play()
        }
    }
    
    public func playerViewController(_ playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        
        let currentviewController = UserInteractionHelper.instance.getPresentingViewController()
        if currentviewController != playerViewController{
            currentviewController.present(playerViewController, animated: true, completion: nil)
        }
        completionHandler(true)
    }
}

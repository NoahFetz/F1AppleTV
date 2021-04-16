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
    
    func playStream(contentId: String) {
        var contentUrl = contentId
        if(!contentUrl.starts(with: "CONTENT")){
            contentUrl = "CONTENT/PLAY?contentId=" + contentId
        }
        DataManager.instance.loadStreamEntitlement(contentId: contentUrl, streamEntitlementLoadedProtocol: self)
    }
    
    func didLoadStreamEntitlement(playerId: String, streamEntitlement: StreamEntitlementDto) {
        if let url = URL(string: streamEntitlement.url) {
            self.openPlayer(url: url)
        }
    }
    
    func openPlayer(url: URL) {
        let playerAsset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: playerAsset)
        let player = AVPlayer(playerItem: playerItem)
        
        self.openPlayer(player: player)
    }
    
    func openPlayer(player: AVPlayer) {
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

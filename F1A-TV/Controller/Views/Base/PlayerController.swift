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
    
    func didLoadStreamEntitlement(streamEntitlement: StreamEntitlementDto) {
        if let url = URL(string: streamEntitlement.url) {
            self.openPlayer(url: url)
        }
    }
    
    func openPlayer(url: URL) {
        let player = AVPlayer(url: url)
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
        
        //Maybe need this in the future to make a multiview player thingy :)
        /*var counter = 0
        for entitlement in self.entitlements {
            if let entitlementUrl = URL(string: entitlement.url) {
                let layerPlayer = AVPlayer(url: entitlementUrl)
                let playerLayer = AVPlayerLayer(player: layerPlayer)
                
                switch counter {
                case 0:
                    playerLayer.frame = CGRect(x: 0, y: 0, width: UserInteractionHelper.instance.getPresentingViewController().view.bounds.width/2, height: UserInteractionHelper.instance.getPresentingViewController().view.bounds.height/2)
                    
                case 1:
                    playerLayer.frame = CGRect(x: UserInteractionHelper.instance.getPresentingViewController().view.bounds.width/2, y: 0, width: UserInteractionHelper.instance.getPresentingViewController().view.bounds.width/2, height: UserInteractionHelper.instance.getPresentingViewController().view.bounds.height/2)
                    
                case 2:
                    playerLayer.frame = CGRect(x: 0, y: UserInteractionHelper.instance.getPresentingViewController().view.bounds.height/2, width: UserInteractionHelper.instance.getPresentingViewController().view.bounds.width/2, height: UserInteractionHelper.instance.getPresentingViewController().view.bounds.height/2)
                    
                case 3:
                    playerLayer.frame = CGRect(x: UserInteractionHelper.instance.getPresentingViewController().view.bounds.width/2, y: UserInteractionHelper.instance.getPresentingViewController().view.bounds.height/2, width: UserInteractionHelper.instance.getPresentingViewController().view.bounds.width/2, height: UserInteractionHelper.instance.getPresentingViewController().view.bounds.height/2)
                    
                default:
                    playerLayer.frame = CGRect(x: UserInteractionHelper.instance.getPresentingViewController().view.bounds.width/2, y: UserInteractionHelper.instance.getPresentingViewController().view.bounds.height/2, width: UserInteractionHelper.instance.getPresentingViewController().view.bounds.width/2, height: UserInteractionHelper.instance.getPresentingViewController().view.bounds.height/2)
                }
                counter+=1
                
                playerLayer.videoGravity = .resizeAspect
                UserInteractionHelper.instance.getPresentingViewController().view.layer.addSublayer(playerLayer)
                playerLayer.masksToBounds = true
                layerPlayer.play()
            }
        }
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = CGRect(x: 150, y: 200, width: 1920, height: 1080)
        playerLayer.videoGravity = .resizeAspect
        UserInteractionHelper.instance.getPresentingViewController().view.layer.addSublayer(playerLayer)
        playerLayer.masksToBounds = true*/
        
        player.play()
    }
    
    public func playerViewController(_ playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        UserInteractionHelper.instance.getPresentingViewController().present(playerViewController, animated: true)
        completionHandler(true)
    }
}

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
        /*let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = CGRect(x: 150, y: 200, width: 1920, height: 1080)
        playerLayer.videoGravity = .resizeAspect
        UserInteractionHelper.instance.getPresentingViewController().view.layer.addSublayer(playerLayer)
        playerLayer.masksToBounds = true
        
        player.play()*/
    }
    
    public func playerViewController(_ playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        UserInteractionHelper.instance.getPresentingViewController().present(playerViewController, animated: true)
        completionHandler(true)
    }
}

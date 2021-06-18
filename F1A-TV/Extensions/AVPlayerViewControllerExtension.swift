//
//  AVPlayerViewControllerExtension.swift
//  F1A-TV
//
//  Created by Noah Fetz on 05.04.21.
//

import AVKit

extension AVPlayerViewController {
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if(self.player != nil) {
            self.player?.pause()
            self.player = nil
        }
        NotificationCenter.default.post(name: .avPlayerDidDismiss, object: nil, userInfo: nil)
    }
}

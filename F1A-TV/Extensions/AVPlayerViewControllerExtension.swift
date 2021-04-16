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
        self.player?.pause()
        NotificationCenter.default.post(name: .avPlayerDidDismiss, object: nil, userInfo: nil)
    }
}

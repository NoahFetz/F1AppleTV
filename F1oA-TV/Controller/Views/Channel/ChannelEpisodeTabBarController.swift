//
//  ChannelEpisodeTabBarController.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import UIKit

class ChannelEpisodeTabBarController: UITabBarController {

    var session = SessionDto()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupTabItems()
    }
    
    func setupTabItems() {
        self.tabBar.items?[0].title = NSLocalizedString("channels_title", comment: "")
        self.tabBar.items?[1].title = NSLocalizedString("episodes_title", comment: "")
    }
    
    func initialize(session: SessionDto) {
        self.session = session
    }
}

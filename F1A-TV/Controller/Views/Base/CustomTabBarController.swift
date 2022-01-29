//
//  CustomTabBarController.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit

class CustomTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if(self.traitCollection.userInterfaceStyle == .dark){
            ConstantsUtil.darkStyle = true
        }else{
            ConstantsUtil.darkStyle = false
        }
        
        self.setupTabItems()
    }
    
    func setupTabItems() {
        self.tabBar.items?[0].title = "featured_title".localizedString
        self.tabBar.items?[1].title = "archive_title".localizedString
        self.tabBar.items?[2].title = "account_title".localizedString
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #available(iOS 13.0, *) {
            let hasUserInterfaceStyleChanged = previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) ?? false
            if(hasUserInterfaceStyleChanged){
                if(traitCollection.userInterfaceStyle == .dark){
                    ConstantsUtil.darkStyle = true
                }else{
                    ConstantsUtil.darkStyle = false
                }
                NotificationCenter.default.post(name: .userInterfaceStyleChanged, object: nil)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

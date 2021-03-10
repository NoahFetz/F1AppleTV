//
//  UIViewControllerExtension.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit

extension UIViewController {
    func getViewControllerWith(viewIdentifier: String) -> UIViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: viewIdentifier)
    }
    
    func presentFullscreenInNavigationController(viewIdentifier: String) {
        self.presentFullscreenInNavigationController(viewController: self.getViewControllerWith(viewIdentifier: viewIdentifier))
    }
    
    func presentFullscreenInNavigationController(viewController: UIViewController) {
        self.navigationController?.pushViewController(viewController, animated: true)
    }
    
    func presentFullscreen(viewIdentifier: String) {
        self.presentFullscreen(viewController: self.getViewControllerWith(viewIdentifier: viewIdentifier))
    }
    
    func presentFullscreen(viewController: UIViewController) {
        self.present(viewController, animated: true)
    }
}

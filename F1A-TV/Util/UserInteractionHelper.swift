//
//  UserInteractionHelper.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 03.03.21.
//

import UIKit

class UserInteractionHelper {
    static let instance = UserInteractionHelper()
    
    func getKeyWindow() -> UIWindow {
        return UIApplication.shared.connectedScenes.filter({$0.activationState == .foregroundActive}).map({$0 as? UIWindowScene}).compactMap({$0}).first?.windows.filter({$0.isKeyWindow}).first ?? UIWindow()
    }
    
    func getPresentingViewController() -> UIViewController {
        if var topController = self.getKeyWindow().rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            return topController
        }
        return self.getKeyWindow().rootViewController ?? UIViewController()
    }
    
    func showSuccess(title: String, message: String) {
        SPAlert.present(title: title, message: message, preset: .done)
    }
    
    func showError(title: String, message: String) {
        SPAlert.present(title: title, message: message, preset: .error)
    }
    
    func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("close", comment: ""), style: .cancel, handler: { (UIAlertAction) in
            print("Cancelled")
        }))
        
        self.getPresentingViewController().present(alertController, animated: true)
    }
}

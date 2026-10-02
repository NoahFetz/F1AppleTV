//
//  UserInteractionHelper.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 03.03.21.
//

import UIKit
import SPAlert

class UserInteractionHelper {
    static let instance = UserInteractionHelper()
    
    func getKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    func getPresentingViewController() -> UIViewController? {
        guard var controller = getKeyWindow()?.rootViewController else { return nil }
        while let presented = controller.presentedViewController { controller = presented }
        return controller
    }

    func showSuccess(title: String, message: String) {
        SPAlert.present(title: title, message: message, preset: .done)
    }
    
    func showError(title: String, message: String, recordsError: Bool = true, retry: (() -> Void)? = nil) {
        if recordsError { AppErrorStore.shared.record(NSError(domain: "Application", code: 1), operation: .action) }
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            if let retry { alert.addAction(UIAlertAction(title: "action_retry".localizedString, style: .default) { _ in retry() }) }
            alert.addAction(UIAlertAction(title: "close".localizedString, style: .cancel))
            guard let presenter = self.getPresentingViewController(), !(presenter is UIAlertController) else { return }
            presenter.present(alert, animated: true)
        }
    }
    
    func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "close".localizedString, style: .cancel, handler: { (UIAlertAction) in
            print("Cancelled")
        }))
        
        self.getPresentingViewController()?.present(alertController, animated: true)
    }
}

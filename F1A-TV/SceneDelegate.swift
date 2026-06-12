//
//  SceneDelegate.swift
//  F1TV
//
//  Created by Noah Fetz on 12.06.26.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func sceneWillResignActive(_ scene: UIScene) {
        print("Will resign active")
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        print("Did enter background")
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        print("Will enter foreground")
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        print("Did become active")
    }

}

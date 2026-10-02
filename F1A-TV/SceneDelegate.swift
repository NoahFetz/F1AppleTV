//
//  SceneDelegate.swift
//  F1TV
//
//  Created by Noah Fetz on 12.06.26.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var services: AppServices?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = self.window ?? UIWindow(windowScene: scene)
        let services = AppServices.live(); self.services = services
        let home = HomeShellViewController(); home.services = services
        let navigation = UINavigationController(rootViewController: home)
        navigation.setNavigationBarHidden(true, animated: false)
        window.rootViewController = navigation
        self.window = window
        window.makeKeyAndVisible()
    }

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

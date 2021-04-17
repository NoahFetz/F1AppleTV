//
//  AppDelegate.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit
import CoreData

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        /**
         Only for debug - Prints all font names
         */
        /*for family in UIFont.familyNames.sorted() {
            let names = UIFont.fontNames(forFamilyName: family)
            print("Family: \(family) Font names: \(names)")
        }*/
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        print("Will resign active")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("Did enter background")
        self.saveContext()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("Will enter foreground")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        print("Did become active")
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "F1ATV")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}


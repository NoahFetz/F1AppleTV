//
//  DatabaseController.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import CoreData

class DatabaseController: NSObject {
    static let instance = DatabaseController()
    var managedObjectContext: NSManagedObjectContext;
    
    override init() {
        guard let modelURL = Bundle.main.url(forResource: "F1ATV", withExtension:"momd") else {
            fatalError("Error loading model from bundle");
        }
        
        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Error initializing mom from: \(modelURL)");
        }
        
        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom);
        self.managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType);
        self.managedObjectContext.persistentStoreCoordinator = psc;
        
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask);
        let docURL = urls[urls.endIndex-1];
        let storeURL = docURL.appendingPathComponent("DataModel.sqlite");
        let options = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
        do {
            try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options);
        } catch {
            do {
                try FileManager.default.removeItem(at: storeURL);
            } catch {
                fatalError("Error removing file: \(error)");
            }
            
            do {
                try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options);
            } catch {
                fatalError("Error migrating store: \(error)");
            }
        }
    }
}

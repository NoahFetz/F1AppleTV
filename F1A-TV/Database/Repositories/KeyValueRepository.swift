//
//  KeyValueRepository.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import CoreData

class KeyValueRepository {
    private let entityNameKey = "KeyValueStoreEntity"
    var managedObjectContext: NSManagedObjectContext!
    
    func getKeyValuePairs() -> [KeyValueStoreObject] {
        let ctx = DatabaseController.instance.managedObjectContext
        let fetchRequest = NSFetchRequest<KeyValueStoreEntity>(entityName: self.entityNameKey)
        var loadedEntities = [KeyValueStoreEntity]()
        do {
            loadedEntities = try ctx.fetch(fetchRequest)
        } catch {
        }
        
        var items = [KeyValueStoreObject]();
        for loadedItem in loadedEntities {
            items.append(KeyValueStoreObject(entity: loadedItem))
        }
        return items
    }
    
    func clear() {
        let ctx = DatabaseController.instance.managedObjectContext
        let fetchRequest = NSFetchRequest<KeyValueStoreEntity>(entityName: self.entityNameKey)
        var loadedItems = [KeyValueStoreEntity]()
        do {
            loadedItems = try ctx.fetch(fetchRequest)
        } catch {
        }
        
        for loadedItem in loadedItems {
            ctx.delete(loadedItem)
        }
        
        do {
            try ctx.save()
        } catch {
        }
    }
    
    func delete(id: UUID) {
        let ctx = DatabaseController.instance.managedObjectContext
        let fetchRequest = NSFetchRequest<KeyValueStoreEntity>(entityName: self.entityNameKey)
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        var loadedItems = [KeyValueStoreEntity]()
        do {
            loadedItems = try ctx.fetch(fetchRequest)
        } catch {
        }
        
        for loadedItem in loadedItems {
            ctx.delete(loadedItem)
        }
        
        do {
            try ctx.save()
        } catch {
        }
    }
    
    func updateItem(id: UUID, keyValueObject: KeyValueStoreObject) {
        let ctx = DatabaseController.instance.managedObjectContext
        let fetchRequest = NSFetchRequest<KeyValueStoreEntity>(entityName: self.entityNameKey)
        fetchRequest.predicate = NSPredicate(format: "key == %@", keyValueObject.key as CVarArg)
        var loadedItems = [KeyValueStoreEntity]()
        do {
            loadedItems = try ctx.fetch(fetchRequest)
        } catch {
        }
        if(loadedItems.count == 1){
            for loadedItem in loadedItems {
                loadedItem.id = keyValueObject.id
                loadedItem.value = keyValueObject.value
            }
        }else{
            print("Error occured")
        }
        
        do {
            try ctx.save()
        } catch {
        }
    }
    
    func insertItem(item: KeyValueStoreObject) {
        let ctx = DatabaseController.instance.managedObjectContext
        let itemToInsert = KeyValueStoreEntity(context: ctx)
        itemToInsert.id = item.id
        itemToInsert.key = item.key
        itemToInsert.value = item.value
        
        ctx.insert(itemToInsert)
        do {
            try ctx.save();
        } catch {
        }
    }
}

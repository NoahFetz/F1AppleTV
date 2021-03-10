//
//  DataSource.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation

class DataSource {
    static let instance = DataSource()
    let keyValueRepository = KeyValueRepository()
    
    func getAllKeyValues() -> [KeyValueStoreObject]{
        return keyValueRepository.getKeyValuePairs()
    }
    
    func addKeyValue(keyValuePair: KeyValueStoreObject) {
        if(getKeyValuePair(keyString: keyValuePair.key)).key == ""{
            keyValueRepository.insertItem(item: keyValuePair)
        }else{
            updateKeyValuePair(keyValuePair: keyValuePair)
        }
    }
    
    func deleteKeyValue(keyValuePair: KeyValueStoreObject) {
        keyValueRepository.delete(id: UUID(uuidString: keyValuePair.id)!)
    }
    
    func updateKeyValuePair(keyValuePair: KeyValueStoreObject) {
        keyValueRepository.updateItem(id: UUID(uuidString: keyValuePair.id)!, keyValueObject: keyValuePair)
    }
    
    func getKeyValuePair(keyString: String) -> KeyValueStoreObject {
        for keyValuePair in DataSource.instance.getAllKeyValues(){
            if(keyValuePair.key == keyString){
                return keyValuePair
            }
        }
        return KeyValueStoreObject()
    }
}

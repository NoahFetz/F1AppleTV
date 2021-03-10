//
//  KeyValueStoreObject.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation

struct KeyValueStoreObject: Codable {
    var id: String
    var key: String
    var value: String
    
    init() {
        self.id = UUID().uuidString
        self.key = ""
        self.value = ""
    }
    
    init(id: String, key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
    
    init(entity: KeyValueStoreEntity) {
        self.id = entity.id ?? UUID().uuidString
        self.key = entity.key ?? ""
        self.value = entity.value ?? ""
    }
}

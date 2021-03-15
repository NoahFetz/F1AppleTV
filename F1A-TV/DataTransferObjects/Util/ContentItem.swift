//
//  ContentItem.swift
//  F1A-TV
//
//  Created by Noah Fetz on 13.03.21.
//

import Foundation

struct ContentItem {
    var objectType: ContentObjectType
    var container: ContainerDto
    
    init() {
        self.objectType = ContentObjectType()
        self.container = ContainerDto()
    }
    
    init(objectType: ContentObjectType, container: ContainerDto) {
        self.objectType = objectType
        self.container = container
    }
}

//
//  ContentSection.swift
//  F1A-TV
//
//  Created by Noah Fetz on 13.03.21.
//

import Foundation

struct ContentSection {
    var title: String
    var items: [ContentItem]
    var layoutType: ContainerLayoutType
    var container: ContainerDto
    
    init() {
        self.title = ""
        self.items = [ContentItem]()
        self.layoutType = ContainerLayoutType()
        self.container = ContainerDto()
    }
    
    init(title: String, items: [ContentItem], layoutType: ContainerLayoutType, container: ContainerDto) {
        self.title = title
        self.items = items
        self.layoutType = layoutType
        self.container = container
    }
}

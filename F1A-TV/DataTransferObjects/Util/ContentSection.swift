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
    
    init() {
        self.title = ""
        self.items = [ContentItem]()
    }
    
    init(title: String, items: [ContentItem]) {
        self.title = title
        self.items = items
    }
}

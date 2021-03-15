//
//  ActionDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct ActionDto: Codable {
    var key: String
    var uri: String
    var targetType: String
    var href: String

    init() {
        self.key = ""
        self.uri = ""
        self.targetType = ""
        self.href = ""
    }
    
    init(key: String, uri: String, targetType: String, href: String) {
        self.key = key
        self.uri = uri
        self.targetType = targetType
        self.href = href
    }
    
    enum CodingKeys: String, CodingKey {
        case key = "key"
        case uri = "uri"
        case targetType = "targetType"
        case href = "href"
    }
}

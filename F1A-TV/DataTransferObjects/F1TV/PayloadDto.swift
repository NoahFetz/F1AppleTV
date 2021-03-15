//
//  PayloadDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct PayloadDto: Codable {
    var objectSubtype: String
    var contentId: String
    var title: String
    var objectType: String

    init() {
        self.objectSubtype = ""
        self.contentId = ""
        self.title = ""
        self.objectType = ""
    }
    
    init(objectSubtype: String, contentId: String, title: String, objectType: String) {
        self.objectSubtype = objectSubtype
        self.contentId = contentId
        self.title = title
        self.objectType = objectType
    }
    
    enum CodingKeys: String, CodingKey {
        case objectSubtype = "objectSubtype"
        case contentId = "contentId"
        case title = "title"
        case objectType = "objectType"
    }
}

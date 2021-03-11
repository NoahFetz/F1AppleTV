//
//  VodDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 11.03.21.
//

import Foundation

struct VodDto: Codable {
    var imageUrls: [String]
    var contentUrls: [String] //Episodes
    var uid: String
    var dataSourceId: String
    var name: String

    init() {
        self.imageUrls = [String]()
        self.contentUrls = [String]()
        self.uid = ""
        self.dataSourceId = ""
        self.name = ""
    }
    
    init(imageUrls: [String], contentUrls: [String], uid: String, dataSourceId: String, name: String) {
        self.imageUrls = imageUrls
        self.contentUrls = contentUrls
        self.uid = uid
        self.dataSourceId = dataSourceId
        self.name = name
    }
    
    enum CodingKeys: String, CodingKey {
        case imageUrls = "image_urls"
        case contentUrls = "content_urls"
        case uid = "uid"
        case dataSourceId = "data_source_id"
        case name = "name"
    }
}

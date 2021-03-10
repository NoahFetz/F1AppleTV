//
//  SeriesDto.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 09.03.21.
//

import Foundation

struct SeriesDto: Codable {
    var imageUrls: [String]
    var contentUrls: [String]
    var sessionoccurrenceUrls: [String]
    var driveroccurrenceUrls: [String]
    var uid: String
    var dataSourceId: String
    var name: String

    init() {
        self.imageUrls = [String]()
        self.contentUrls = [String]()
        self.sessionoccurrenceUrls = [String]()
        self.driveroccurrenceUrls = [String]()
        self.uid = ""
        self.dataSourceId = ""
        self.name = ""
    }
    
    init(dataSourceFields: [String], imageUrls: [String], contentUrls: [String], sessionoccurrenceUrls: [String], driveroccurrenceUrls: [String], uid: String, dataSourceId: String, name: String) {
        self.imageUrls = imageUrls
        self.contentUrls = contentUrls
        self.sessionoccurrenceUrls = sessionoccurrenceUrls
        self.driveroccurrenceUrls = driveroccurrenceUrls
        self.uid = uid
        self.dataSourceId = dataSourceId
        self.name = name
    }
    
    enum CodingKeys: String, CodingKey {
        case imageUrls = "image_urls"
        case contentUrls = "content_urls"
        case sessionoccurrenceUrls = "sessionoccurrence_urls"
        case driveroccurrenceUrls = "driveroccurrence_urls"
        case uid = "uid"
        case dataSourceId = "data_source_id"
        case name = "name"
    }
}

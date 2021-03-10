//
//  EventDto.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation

struct EventDto: Codable {
    var imageUrls: [String]
    var sessionOccurrenceUrls: [String]
    var driverOccurrenceUrls: [String]
    var uid: String
    var dataSourceId: String
    var startDate: Date
    var endDate: Date
    var name: String
    var officialName: String
    var slug: String
    var nationUrl: String

    init() {
        self.imageUrls = [String]()
        self.sessionOccurrenceUrls = [String]()
        self.driverOccurrenceUrls = [String]()
        self.uid = ""
        self.dataSourceId = ""
        self.startDate = Date()
        self.endDate = Date()
        self.name = ""
        self.officialName = ""
        self.slug = ""
        self.nationUrl = ""
    }
    
    init(imageUrls: [String], sessionOccurrenceUrls: [String], driverOccurrenceUrls: [String], uid: String, dataSourceId: String, startDate: Date, endDate: Date, name: String, officialName: String, slug: String, nationUrl: String) {
        self.imageUrls = imageUrls
        self.sessionOccurrenceUrls = sessionOccurrenceUrls
        self.driverOccurrenceUrls = driverOccurrenceUrls
        self.uid = uid
        self.dataSourceId = dataSourceId
        self.startDate = startDate
        self.endDate = endDate
        self.name = name
        self.officialName = officialName
        self.slug = slug
        self.nationUrl = nationUrl
    }
    
    enum CodingKeys: String, CodingKey {
        case imageUrls = "image_urls"
        case sessionOccurrenceUrls = "sessionoccurrence_urls"
        case driverOccurrenceUrls = "driveroccurrence_urls"
        case uid = "uid"
        case dataSourceId = "data_source_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case name = "name"
        case officialName = "official_name"
        case slug = "slug"
        case nationUrl = "nation_url"
    }
}

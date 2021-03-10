//
//  ChannelDto.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import Foundation

struct ChannelDto: Codable {
    var streams: [StreamDto]
    var driverOccurrenceUrls: [String]
    var uid: String
    var dataSourceId: String
    var channelType: String
    var slug: String
    var name: String
    
    init() {
        self.streams = [StreamDto]()
        self.driverOccurrenceUrls = [String]()
        self.uid = ""
        self.dataSourceId = ""
        self.channelType = ""
        self.slug = ""
        self.name = ""
    }
    
    init(streams: [StreamDto], driverOccurrenceUrls: [String], uid: String, dataSourceId: String, channelType: String, slug: String, name: String) {
        self.streams = streams
        self.driverOccurrenceUrls = driverOccurrenceUrls
        self.uid = uid
        self.dataSourceId = dataSourceId
        self.channelType = channelType
        self.slug = slug
        self.name = name
    }
    
    enum CodingKeys: String, CodingKey {
        case streams = "ovps"
        case driverOccurrenceUrls = "driveroccurrence_urls"
        case uid = "uid"
        case dataSourceId = "data_source_id"
        case channelType = "channel_type"
        case slug = "slug"
        case name = "name"
    }
}

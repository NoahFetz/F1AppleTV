//
//  AssetDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 11.03.21.
//

import Foundation

class AssetDto: Codable {
    var imageUrls: [String]
    var uid: String
    var dataSourceId: String
    var duration: String
    var durationInSeconds: Int
    var subtitles: Bool
    var sound: Bool
    var title: String
    var slug: String

    init() {
        self.imageUrls = [String]()
        self.uid = ""
        self.dataSourceId = ""
        self.duration = ""
        self.durationInSeconds = 0
        self.subtitles = false
        self.sound = false
        self.title = ""
        self.slug = ""
    }
    
    init(imageUrls: [String], uid: String, dataSourceId: String, duration: String, durationInSeconds: Int, subtitles: Bool, sound: Bool, title: String, slug: String) {
        self.imageUrls = imageUrls
        self.uid = uid
        self.dataSourceId = dataSourceId
        self.duration = duration
        self.durationInSeconds = durationInSeconds
        self.subtitles = subtitles
        self.sound = sound
        self.title = title
        self.slug = slug
    }
    
    enum CodingKeys: String, CodingKey {
        case imageUrls = "image_urls"
        case uid = "uid"
        case dataSourceId = "data_source_id"
        case duration = "duration"
        case durationInSeconds = "duration_in_seconds"
        case subtitles = "subtitles"
        case sound = "sound"
        case title = "title"
        case slug = "slug"
    }
}

//
//  EpisodeDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct NewEpisodeDto: Codable {
    var uid: String
    var contentId: Int
    var contentType: String
    var contentSubtype: String
    var shortName: String
    var longName: String
    var seriesUid: String
    var playbackUrl: String
    var thumbnailUrl: String
    
    init() {
        self.uid = ""
        self.contentId = 0
        self.contentType = ""
        self.contentSubtype = ""
        self.shortName = ""
        self.longName = ""
        self.seriesUid = ""
        self.playbackUrl = ""
        self.thumbnailUrl = ""
    }
    
    init(uid: String, contentId: Int, contentType: String, contentSubtype: String, shortName: String, longName: String, seriesUid: String, playbackUrl: String, thumbnailUrl: String) {
        self.uid = ""
        self.contentId = 0
        self.contentType = ""
        self.contentSubtype = ""
        self.shortName = ""
        self.longName = ""
        self.seriesUid = ""
        self.playbackUrl = ""
        self.thumbnailUrl = ""
    }
    
    enum CodingKeys: String, CodingKey {
        case uid = "uid"
        case contentId = "contentId"
        case contentType = "contentType"
        case contentSubtype = "contentSubtype"
        case shortName = "shortName"
        case longName = "longName"
        case seriesUid = "seriesUid"
        case playbackUrl = "playbackUrl"
        case thumbnailUrl = ""
    }
}

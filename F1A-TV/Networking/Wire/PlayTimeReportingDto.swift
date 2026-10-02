//
//  PlayTimeReportingDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 03.08.21.
//

import Foundation

struct PlayTimeReportingDto: Encodable {
    var contentId: Int
    var contentSubType: String
    var playHeadPosition: Int
    var timestamp: Int
    
    init(contentId: Int, contentSubType: String, playHeadPosition: Int, timestamp: Int) {
        self.contentId = contentId
        self.contentSubType = contentSubType
        self.playHeadPosition = playHeadPosition
        self.timestamp = timestamp
    }
    
    enum CodingKeys: String, CodingKey {
        case contentId = "contentId"
        case contentSubType = "contentSubType"
        case playHeadPosition = "playHeadPosition"
        case timestamp = "timestamp"
    }
}

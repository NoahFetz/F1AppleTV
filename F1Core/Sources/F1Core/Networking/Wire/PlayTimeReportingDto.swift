//
//  PlayTimeReportingDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 03.08.21.
//

import Foundation

public struct PlayTimeReportingDto: Encodable {
    public var contentId: Int
    public var contentSubType: String
    public var playHeadPosition: Int
    public var timestamp: Int
    
    public init(contentId: Int, contentSubType: String, playHeadPosition: Int, timestamp: Int) {
        self.contentId = contentId
        self.contentSubType = contentSubType
        self.playHeadPosition = playHeadPosition
        self.timestamp = timestamp
    }
    
    public enum CodingKeys: String, CodingKey {
        case contentId = "contentId"
        case contentSubType = "contentSubType"
        case playHeadPosition = "playHeadPosition"
        case timestamp = "timestamp"
    }
}

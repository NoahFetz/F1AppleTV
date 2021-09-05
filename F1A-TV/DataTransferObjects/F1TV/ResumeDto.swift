//
//  ResumeDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 03.08.21.
//

import Foundation

struct ResumeDto: Codable {
    var playHeadPosition: Int?
    var timestamp: Double?
    var deciveType: String?

    init() {
    }
    
    init(playHeadPosition: Int?, timestamp: Double?, deciveType: String?) {
        self.playHeadPosition = playHeadPosition
        self.timestamp = timestamp
        self.deciveType = deciveType
    }
    
    enum CodingKeys: String, CodingKey {
        case playHeadPosition = "playHeadPosition"
        case timestamp = "timestamp"
        case deciveType = "deciveType"
    }
}

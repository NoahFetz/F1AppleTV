//
//  StreamTokenRequestDto.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import Foundation

struct ChannelStreamTokenRequestDto: Codable {
    var channelUrl: String
    
    init() {
        self.channelUrl = ""
    }
    
    init(channelUrl: String) {
        self.channelUrl = channelUrl
    }
    
    enum CodingKeys: String, CodingKey {
        case channelUrl = "channel_url"
    }
}

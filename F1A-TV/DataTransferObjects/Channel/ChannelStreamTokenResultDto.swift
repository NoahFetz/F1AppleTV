//
//  StreamTokenDto.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import Foundation

struct ChannelStreamTokenResultDto: Codable {
    var tokenisedUrl: String
    
    init() {
        self.tokenisedUrl = ""
    }
    
    init(tokenisedUrl: String) {
        self.tokenisedUrl = tokenisedUrl
    }
    
    enum CodingKeys: String, CodingKey {
        case tokenisedUrl = "tokenised_url"
    }
}

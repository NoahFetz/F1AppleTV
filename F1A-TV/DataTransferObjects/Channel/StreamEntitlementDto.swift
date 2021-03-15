//
//  StreamEntitlementDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct StreamEntitlementDto: Codable {
    var entitlementToken: String
    var url: String
    var streamType: String

    init() {
        self.entitlementToken = ""
        self.url = ""
        self.streamType = ""
    }
    
    init(entitlementToken: String, url: String, streamType: String) {
        self.entitlementToken = entitlementToken
        self.url = url
        self.streamType = streamType
    }
    
    enum CodingKeys: String, CodingKey {
        case entitlementToken = "entitlementToken"
        case url = "url"
        case streamType = "streamType"
    }
}

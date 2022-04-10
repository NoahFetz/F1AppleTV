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
    var drmType: String?
    var laUrl: String?
    var channelId: Int

    init() {
        self.entitlementToken = ""
        self.url = ""
        self.streamType = ""
        self.channelId = 0
    }
    
    init(entitlementToken: String, url: String, streamType: String, drmType: String, laUrl: String?, channelId: Int) {
        self.entitlementToken = entitlementToken
        self.url = url
        self.streamType = streamType
        self.drmType = drmType
        self.laUrl = laUrl
        self.channelId = channelId
    }
    
    enum CodingKeys: String, CodingKey {
        case entitlementToken = "entitlementToken"
        case url = "url"
        case streamType = "streamType"
        case drmType = "drmType"
        case laUrl = "laURL"
        case channelId = "channelId"
    }
}

//
//  StreamDto.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import Foundation

class StreamDto: Codable {
    var accountUrl: String
    var path: String
    var fullStreamUrl: String
    var domain: String

    init() {
        self.accountUrl = ""
        self.path = ""
        self.fullStreamUrl = ""
        self.domain = ""
    }
    
    init(accountUrl: String, path: String, fullStreamUrl: String, domain: String) {
        self.accountUrl = accountUrl
        self.path = path
        self.fullStreamUrl = fullStreamUrl
        self.domain = domain
    }
    
    enum CodingKeys: String, CodingKey {
        case accountUrl = "account_url"
        case path = "path"
        case fullStreamUrl = "full_stream_url"
        case domain = "domain"
    }
}

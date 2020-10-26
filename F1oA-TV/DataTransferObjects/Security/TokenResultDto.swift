//
//  TokenResultDto.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation

struct TokenResultDto: Codable {
    let token: String
    let oauth2AccessToken: String
    let planUrls: [String]
    let userIsVip: Bool

    init() {
        self.token = ""
        self.oauth2AccessToken = ""
        self.planUrls = [String]()
        self.userIsVip = false
    }
    
    init(token: String, oauth2AccessToken: String, planUrls: [String], userIsVip: Bool) {
        self.token = token
        self.oauth2AccessToken = oauth2AccessToken
        self.planUrls = planUrls
        self.userIsVip = userIsVip
    }
    
    enum CodingKeys: String, CodingKey {
        case token = "token"
        case oauth2AccessToken = "oauth2_access_token"
        case planUrls = "plan_urls"
        case userIsVip = "user_is_vip"
    }
}

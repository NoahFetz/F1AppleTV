//
//  TokenRequestDto.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation

struct TokenRequestDto: Codable {
    var accessToken: String
    var identityProviderUrl: String
    
    init() {
        self.accessToken = ""
        self.identityProviderUrl = ""
    }
    
    init(accessToken: String, identityProviderUrl: String) {
        self.accessToken = accessToken
        self.identityProviderUrl = identityProviderUrl
    }
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case identityProviderUrl = "identity_provider_url"
    }
}

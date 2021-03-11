//
//  AuthDataDto.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation

struct AuthDataDto: Codable {
    var subscriptionStatus: String
    var subscriptionToken: String

    init() {
            self.subscriptionStatus = ""
            self.subscriptionToken = ""
        }
    
    init(subscriptionStatus: String, subscriptionToken: String) {
            self.subscriptionStatus = subscriptionStatus
            self.subscriptionToken = subscriptionToken
        }
    
    enum CodingKeys: String, CodingKey {
        case subscriptionStatus = "subscriptionStatus"
        case subscriptionToken = "subscriptionToken"
    }
}

//
//  AuthDataDto.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation

public struct AuthDataDto: Codable {
    public var subscriptionStatus: String
    public var subscriptionToken: String

    public init() {
            self.subscriptionStatus = ""
            self.subscriptionToken = ""
        }
    
    public init(subscriptionStatus: String, subscriptionToken: String) {
            self.subscriptionStatus = subscriptionStatus
            self.subscriptionToken = subscriptionToken
        }
    
    public enum CodingKeys: String, CodingKey {
        case subscriptionStatus = "subscriptionStatus"
        case subscriptionToken = "subscriptionToken"
    }
}

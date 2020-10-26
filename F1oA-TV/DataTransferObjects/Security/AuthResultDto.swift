//
//  AuthResultDto.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation

struct AuthResultDto: Codable {
    let sessionId: String
    let passwordIsTemporary: Bool
    let subscriber: SubscriberDto
    let country: String
    let authData: AuthDataDto
   
    init() {
        self.sessionId = ""
        self.passwordIsTemporary = false
        self.subscriber = SubscriberDto()
        self.country = ""
        self.authData = AuthDataDto()
    }
    
    init(sessionId: String, passwordIsTemporary: Bool, subscriber: SubscriberDto, country: String, authData: AuthDataDto) {
        self.sessionId = sessionId
        self.passwordIsTemporary = passwordIsTemporary
        self.subscriber = subscriber
        self.country = country
        self.authData = authData
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "SessionId"
        case passwordIsTemporary = "PasswordIsTemporary"
        case subscriber = "Subscriber"
        case country = "Country"
        case authData = "data"
    }
}

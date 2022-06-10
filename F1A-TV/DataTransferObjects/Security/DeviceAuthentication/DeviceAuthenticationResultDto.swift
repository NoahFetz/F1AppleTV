//
//  DeviceAuthenticationResultDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

struct DeviceAuthenticationResultDto: Codable {
    var sessionId: String
    var authenticationKey: String
    var passwordIsTemporary: Bool
    var subscriber: SubscriberDto
    var country: String
    var data: AuthDataDto

    init() {
        self.sessionId = ""
        self.authenticationKey = ""
        self.passwordIsTemporary = false
        self.subscriber = SubscriberDto()
        self.country = ""
        self.data = AuthDataDto()
    }
    
    init(sessionId: String, authenticationKey: String, passwordIsTemporary: Bool, subscriber: SubscriberDto, country: String, data: AuthDataDto) {
        self.sessionId = sessionId
        self.authenticationKey = authenticationKey
        self.passwordIsTemporary = passwordIsTemporary
        self.subscriber = subscriber
        self.country = country
        self.data = data
    }
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "SessionId"
        case authenticationKey = "AuthenticationKey"
        case passwordIsTemporary = "PasswordIsTemporary"
        case subscriber = "Subscriber"
        case country = "Country"
        case data = "data"
    }
}

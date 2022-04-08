//
//  ChallengeResultDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 09.04.22.
//

import Foundation

struct ChallengeResultDto: Codable {
    var expiresIn: Int
    var token: String
    
    init() {
        self.expiresIn = 0
        self.token = ""
    }
    
    init(expiresIn: Int, token: String) {
        self.expiresIn = expiresIn
        self.token = token
    }
    
    enum CodingKeys: String, CodingKey {
        case expiresIn = "expires_in"
        case token = "token"
    }
}

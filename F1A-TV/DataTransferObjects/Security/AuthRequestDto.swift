//
//  AuthRequestDto.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation

struct AuthRequestDto: Codable {
    var login: String
    var password: String
    
    init() {
        self.login = ""
        self.password = ""
    }
    
    init(login: String, password: String) {
        self.login = login
        self.password = password
    }
    
    enum CodingKeys: String, CodingKey {
        case login = "login"
        case password = "password"
    }
}

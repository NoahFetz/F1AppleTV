//
//  SubscriberDto.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation

struct SubscriberDto: Codable {
    let firstName: String
    let lastName: String
    let homeCountry: String
    let id: Int
    let email: String
    let login: String
    
    init() {
        self.firstName = ""
        self.lastName = ""
        self.homeCountry = ""
        self.id = 0
        self.email = ""
        self.login = ""
    }
    
    init(firstName: String, lastName: String, homeCountry: String, id: Int, email: String, login: String) {
        self.firstName = firstName
        self.lastName = lastName
        self.homeCountry = homeCountry
        self.id = id
        self.email = email
        self.login = login
    }

    enum CodingKeys: String, CodingKey {
        case firstName = "FirstName"
        case lastName = "LastName"
        case homeCountry = "HomeCountry"
        case id = "Id"
        case email = "Email"
        case login = "Login"
    }
}

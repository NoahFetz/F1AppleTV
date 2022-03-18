//
//  APIVersionType.swift
//  F1A-TV
//
//  Created by Noah Fetz on 18.03.22.
//

import Foundation

enum APIVersionType: String, CaseIterable, Codable {
    case V1 = "1.0"
    case V2 = "2.0"
    case V3 = "3.0"
    
    init() {
        self = .V3
    }
    
    func getVersionType() -> String {
        return self.rawValue
    }
}

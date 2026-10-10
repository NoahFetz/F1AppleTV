//
//  APIVersionType.swift
//  F1A-TV
//
//  Created by Noah Fetz on 18.03.22.
//

import Foundation

public enum APIVersionType: String, CaseIterable, Codable {
    case V1 = "1.0"
    case V2 = "2.0"
    case V3 = "3.0"
    
    public init() {
        self = .V3
    }
    
    public func getVersionType() -> String {
        return self.rawValue
    }
}

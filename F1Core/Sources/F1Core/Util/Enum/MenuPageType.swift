//
//  MenuPageType.swift
//  F1A-TV
//
//  Created by Noah Fetz on 18.03.22.
//

import Foundation

public enum MenuPageType: String, CaseIterable, Codable {
    case Home = "395"
    case CurrentSeason = "12343"
    case Archive = "493"
    case Shows = "410"
    case Docs = "413"
    
    public init() {
        self = .Home
    }
    
    public func getPageId() -> String {
        return self.rawValue
    }
}

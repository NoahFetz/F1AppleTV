//
//  MenuPageType.swift
//  F1A-TV
//
//  Created by Noah Fetz on 18.03.22.
//

import Foundation

enum MenuPageType: String, CaseIterable, Codable {
    case Home = "395"
    case CurrentSeason = "10295"
    case Archive = "493"
    case Shows = "410"
    case Docs = "413"
    
    init() {
        self = .Home
    }
    
    func getPageId() -> String {
        return self.rawValue
    }
}

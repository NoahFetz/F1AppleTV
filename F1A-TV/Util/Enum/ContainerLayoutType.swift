//
//  ContainerLayoutType.swift
//  F1A-TV
//
//  Created by Noah Fetz on 13.03.21.
//

import Foundation

enum ContainerLayoutType: CaseIterable {
    case Unknown
    case Hero
    case Title
    case VerticalThumbnail
    case HorizontalThumbnail
    case ContentItem
    
    init() {
        self = .Unknown
    }
    
    static func fromIdentifier(identifier: String) -> ContainerLayoutType {
        for type in ContainerLayoutType.allCases {
            if(type.getIdentifier() == identifier) {
                return type
            }
        }
        return .Unknown
    }
    
    func getIdentifier() -> String {
        switch self {
        case .Unknown:
            return ""
        
        case .Hero:
            return "hero"
            
        case .Title:
            return "title"
            
        case .VerticalThumbnail:
            return "vertical_thumbnail"
            
        case .HorizontalThumbnail:
            return "horizontal_thumbnail"
            
        case .ContentItem:
            return "CONTENT_ITEM"
            
        }
    }
}

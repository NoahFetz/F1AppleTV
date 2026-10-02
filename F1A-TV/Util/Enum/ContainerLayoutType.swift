//
//  ContainerLayoutType.swift
//  F1A-TV
//
//  Created by Noah Fetz on 13.03.21.
//

import Foundation

enum ContainerLayoutType: CaseIterable {
    case Unknown
    case PageHeader
    case Hero
    case Title
    case Subtitle
    case GpBanner
    case VerticalThumbnail
    case HorizontalThumbnail
    case ContentItem
    case Schedule
    case VerticalSimplePoster
    case HorizontalSimplePoster
    case HorizontalSimpleThumbnail
    case VerticalSimpleThumbnail
    
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
        
        case .PageHeader:
            return "__page_header"
        case .Hero:
            return "hero"
            
        case .Title:
            return "title"
            
        case .Subtitle:
            return "subtitle"
            
        case .GpBanner:
            return "gp_banner"
            
        case .VerticalThumbnail:
            return "vertical_thumbnail"
            
        case .HorizontalThumbnail:
            return "horizontal_thumbnail"
            
        case .ContentItem:
            return "CONTENT_ITEM"
            
        case .Schedule:
            return "interactive_schedule"
            
        case .VerticalSimplePoster:
            return "vertical_simple_poster"

        case .HorizontalSimplePoster:
            return "horizontal_simple_poster"

        case .HorizontalSimpleThumbnail:
            return "horizontal_simple_thumbnail"

        case .VerticalSimpleThumbnail:
            return "vertical_simple_thumbnail"
            
        }
    }

    var isPoster: Bool {
        self == .HorizontalSimplePoster || self == .VerticalSimplePoster
    }

    var isHorizontal: Bool {
        [.Hero, .HorizontalThumbnail, .HorizontalSimplePoster, .HorizontalSimpleThumbnail].contains(self)
    }
}

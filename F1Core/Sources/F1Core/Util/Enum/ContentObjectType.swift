//
//  ContentObjectType.swift
//  F1A-TV
//
//  Created by Noah Fetz on 13.03.21.
//

import Foundation

public enum ContentObjectType: CaseIterable, Sendable {
    case Unknown
    case Video
    case Launcher
    case Bundle
    
    public init() {
        self = .Unknown
    }
    
    public static func fromIdentifier(identifier: String) -> ContentObjectType {
        for type in ContentObjectType.allCases {
            if(type.getIdentifier() == identifier) {
                return type
            }
        }
        return .Unknown
    }
    
    public func getIdentifier() -> String {
        switch self {
        case .Unknown:
            return ""
        
        case .Video:
            return "VIDEO"
            
        case .Launcher:
            return "LAUNCHER"
            
        case .Bundle:
            return "BUNDLE"
            
        }
    }
}

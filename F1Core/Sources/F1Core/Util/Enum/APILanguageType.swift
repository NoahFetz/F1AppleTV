//
//  APILanguageType.swift
//  F1A-TV
//
//  Created by Noah Fetz on 24.09.21.
//

import Foundation

public enum APILanguageType: Int, CaseIterable, Codable {
    case English = 0
    case German = 1
    case Spanish = 2
    case French = 3
    case Dutch = 4
    case Portuguese = 5
    
    public init() {
        self = .English
    }
    
    public static func fromAPIKey(apiKey: String) -> APILanguageType {
        for type in APILanguageType.allCases {
            if(type.getAPIKey() == apiKey) {
                return type
            }
        }
        return .English
    }
    
    public func getAPIKey() -> String {
        switch self {
        case .English:
            return "ENG"
            
        case .German:
            return "DEU"
            
        case .Spanish:
            return "SPA"
            
        case .French:
            return "FRA"
            
        case .Dutch:
            return "NLD"
            
        case .Portuguese:
            return "POR"
            
        }
    }
    
    public func getLanguageDisplayName() -> String {
        switch self {
        case .English:
            return "settings_language_english_displayname".localizedString
            
        case .German:
            return "settings_language_german_displayname".localizedString
            
        case .Spanish:
            return "settings_language_spanish_displayname".localizedString
            
        case .French:
            return "settings_language_french_displayname".localizedString
            
        case .Dutch:
            return "settings_language_dutch_displayname".localizedString
            
        case .Portuguese:
            return "settings_language_portuguese_displayname".localizedString
            
        }
    }
}

//
//  APIStreamType.swift
//  APIStreamType
//
//  Created by Noah Fetz on 04.09.21.
//

import Foundation

public enum APIStreamType: Int, CaseIterable, Codable {
    case BigScreenHLS = 0
    case WebHLS = 1
    
    public init() {
        self = .BigScreenHLS
    }
    
    public func getAPIKey() -> String {
        switch self {
        case .BigScreenHLS:
            return "BIG_SCREEN_HLS"
            
        case .WebHLS:
            return "WEB_HLS"
            
        }
    }
    
    public func getProviderDisplayName() -> String {
        switch self {
        case .BigScreenHLS:
            return "settings_cdn_big_screen_hls_provider_displayname".localizedString
            
        case .WebHLS:
            return "settings_cdn_web_hls_provider_displayname".localizedString
            
        }
    }
}

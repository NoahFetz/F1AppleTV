//
//  ChannelType.swift
//  F1A-TV
//
//  Created by Noah Fetz on 06.04.21.
//

import Foundation

enum ChannelType: CaseIterable {
    case MainFeed
    case AdditionalFeed
    case OnBoardCamera
    
    init() {
        self = .MainFeed
    }
    
    func getIdentifier() -> Int {
        switch self {
        case .MainFeed:
            return 0
            
        case .AdditionalFeed:
            return 1
            
        case .OnBoardCamera:
            return 2
        }
    }
}

//
//  DriverChannelSortType.swift
//  F1A-TV
//
//  Created by Noah Fetz on 25.08.22.
//

import Foundation

enum DriverChannelSortType: Int, CaseIterable, Codable {
    case DriverNumber = 0
    case Alphabetical = 1
    
    init() {
        self = .DriverNumber
    }
    
    func getDisplayName() -> String {
        switch self {
        case .DriverNumber:
            return "settings_driver_channel_sorting_driver_number_title".localizedString
            
        case .Alphabetical:
            return "settings_driver_channel_sorting_alphabetical_title".localizedString
            
        }
    }
}

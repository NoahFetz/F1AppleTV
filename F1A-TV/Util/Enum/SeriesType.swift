//
//  SeriesType.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 10.03.21.
//

import UIKit

enum SeriesType: CaseIterable {
    case None
    case Formula1
    case Formula2
    case Formula3
    case PorscheSuperCup
    
    init() {
        self = .None
    }
    
    static func fromIdentifier(identifier: Int) -> SeriesType {
        for type in SeriesType.allCases {
            if(type.getIdentifier() == identifier) {
                return type
            }
        }
        return .None
    }
    
    static func fromCapitalDisplayName(capitalDisplayName: String) -> SeriesType {
        for type in SeriesType.allCases {
            if(type.getCapitalDisplayName() == capitalDisplayName) {
                return type
            }
        }
        return .None
    }
    
    func getIdentifier() -> Int {
        switch self {
        case .None:
            return 0
        
        case .Formula1:
            return 1
            
        case .Formula2:
            return 2
            
        case .Formula3:
            return 10
            
        case .PorscheSuperCup:
            return 7
        }
    }
    
    func getCapitalDisplayName() -> String {
        switch self {
        case .None:
            return ""
        
        case .Formula1:
            return "FORMULA 1"
            
        case .Formula2:
            return "FORMULA 2"
            
        case .Formula3:
            return "FORMULA 3"
            
        case .PorscheSuperCup:
            return "PORSCHE"
        }
    }
    
    func getShortDisplayName() -> String {
        switch self {
        case .None:
            return ""
        
        case .Formula1:
            return "F1"
            
        case .Formula2:
            return "F2"
            
        case .Formula3:
            return "F3"
            
        case .PorscheSuperCup:
            return "PSC"
        }
    }
    
    func getColor() -> UIColor {
        switch self {
        case .None:
            return UIColor.white
        
        case .Formula1:
            return UIColor(rgb: 0xe10600)
            
        case .Formula2:
            return UIColor(rgb: 0x4178b1)
            
        case .Formula3:
            return UIColor(rgb: 0x77776e)
            
        case .PorscheSuperCup:
            return UIColor(rgb: 0x4178b1)
        }
    }
}

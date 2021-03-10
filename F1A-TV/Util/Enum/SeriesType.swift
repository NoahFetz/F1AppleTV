//
//  SeriesType.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 10.03.21.
//

import UIKit

enum SeriesType: CaseIterable {
    case Formula1
    case Formula2
    case Formula3
    case PorscheSuperCup
    
    init() {
        self = .Formula1
    }
    
    static func fromIdentifier(identifier: Int) -> SeriesType {
        for type in SeriesType.allCases {
            if(type.getIdentifier() == identifier) {
                return type
            }
        }
        return .Formula1
    }
    
    func getIdentifier() -> Int {
        switch self {
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
    
    func getColor() -> UIColor {
        switch self {
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

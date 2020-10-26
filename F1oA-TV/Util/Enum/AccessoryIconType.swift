//
//  AccessoryIconType.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import UIKit

enum AccessoryIconType: CaseIterable {
    case None
    case Disclosure
    case Delete
    case Checkmark
    case AppNotificationBadge
    case BarcodeViewfinder
    case Clock
    
    init() {
        self = .None
    }
    
    static func fromIdentifier(identifier: Int) -> AccessoryIconType {
        for accessoryIcon in AccessoryIconType.allCases {
            if(accessoryIcon.getIdentifier() == identifier) {
                return accessoryIcon
            }
        }
        return .None
    }
    
    func getIcon() -> UIImage? {
        switch self {
        case .None:
            return nil
            
        case .Disclosure:
            return UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .bold))
            
        case .Delete:
            return UIImage(systemName: "xmark.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .bold))
            
        case .Checkmark:
            return UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
            
        case .AppNotificationBadge:
            return UIImage(systemName: "app.badge", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .regular))
            
        case .BarcodeViewfinder:
            return UIImage(systemName: "barcode.viewfinder", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .regular))
            
        case .Clock:
            return UIImage(systemName: "clock", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .regular))
        }
    }
    
    func getIdentifier() -> Int {
        switch self {
        case .None:
            return 0
            
        case .Disclosure:
            return 1
            
        case .Delete:
            return 2
            
        case .Checkmark:
            return 3
            
        case .AppNotificationBadge:
            return 4
            
        case .BarcodeViewfinder:
            return 5
            
        case .Clock:
            return 6
        }
    }
    
    func getCaption() -> String {
        switch self {
        case .None:
            return "None"
            
        case .Disclosure:
            return "Disclosure"
            
        case .Delete:
            return "Delete"
            
        case .Checkmark:
            return "Checkmark"
            
        case .AppNotificationBadge:
            return "AppNotificationBadge"
            
        case .BarcodeViewfinder:
            return "BarcodeViewfinder"
            
        case .Clock:
            return "Clock"
            
        }
    }
}

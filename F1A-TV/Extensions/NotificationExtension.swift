//
//  NotificationExtension.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation

extension Notification.Name {
    static let userInterfaceStyleChanged = Notification.Name("userInterfaceStyleChanged")
    static let seasonsChanged = Notification.Name("seasonsChanged")
    static let eventChanged = Notification.Name("eventChanged")
    static let imageChanged = Notification.Name("imageChanged")
    static let avPlayerDidDismiss = Notification.Name("avPlayerDidDismiss")
}

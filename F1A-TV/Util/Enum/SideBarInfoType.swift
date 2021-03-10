//
//  SideBarInfoType.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 09.03.21.
//

import Foundation

enum SideBarInfoType: CaseIterable {
    case Season
    case Event
    case Session
    
    init() {
        self = .Season
    }
}

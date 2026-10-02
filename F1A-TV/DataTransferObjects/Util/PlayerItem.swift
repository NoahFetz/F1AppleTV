//
//  PlayerItem.swift
//  F1A-TV
//
//  Created by Noah Fetz on 03.04.21.
//

import Foundation
import AVKit

struct PlayerItem: Identifiable {
    var id = UUID().uuidString.lowercased()
    var contentItem: ContentItem
    var entitlement: PlaybackEntitlement?
    var position: Int
    var player: FairPlayer?
    var playerAsset: AVURLAsset? { player?.currentItem?.asset as? AVURLAsset }
    var playerItem: AVPlayerItem? { player?.currentItem }
    
    init() {
        self.contentItem = ContentItem()
        self.position = 0
    }
    
    init(contentItem: ContentItem, position: Int) {
        self.contentItem = contentItem
        self.position = position
    }
}

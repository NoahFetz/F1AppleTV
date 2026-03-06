//
//  PlayerCollectionViewController+Overlays.swift
//  F1A-TV
//
//  Created by Noah Fetz on 29.03.21.
//

import UIKit

// MARK: - Overlay Presentation
extension PlayerCollectionViewController {
    
    func showInfoOverlay() {
        if(self.playerInfoViewController == nil) {
            self.playerInfoViewController = self.getViewControllerWith(viewIdentifier: ConstantsUtil.playerInfoOverlayViewController) as? PlayerInfoOverlayViewController
            self.playerInfoViewController?.modalPresentationStyle = .overCurrentContext
            self.playerInfoViewController?.initialize(contentItem: self.channelItems.first(where: {$0.container.metadata?.channelType == .MainFeed}) ?? ContentItem())
        }
        
        if(self.playerInfoViewController?.isBeingPresented ?? true) {
            return
        }
        
        self.present(self.playerInfoViewController ?? UIViewController(), animated: true)
    }
    
    func showControlStripOverlay() {
        self.controlStripViewController = self.getViewControllerWith(viewIdentifier: ConstantsUtil.controlStripOverlayViewController) as? ControlStripOverlayViewController
        self.controlStripViewController?.modalPresentationStyle = .overCurrentContext
        
        let focusedPlayerItem = self.playerItems[self.lastFocusedPlayer?.item ?? 0]
        
        self.controlStripViewController?.initialize(playerItem: focusedPlayerItem, playerCount: self.playerItems.count, controlStripActionProtocol: self)
        
        if(self.controlStripViewController?.isBeingPresented ?? true) {
            return
        }
        
        self.present(self.controlStripViewController ?? UIViewController(), animated: true)
    }
    
    func showChannelSelectorOverlay() {
        if(self.channelSelectorViewController == nil) {
            self.channelSelectorViewController = self.getViewControllerWith(viewIdentifier: ConstantsUtil.channelSelectorOverlayViewController) as? ChannelSelectorOverlayViewController
            self.channelSelectorViewController?.modalPresentationStyle = .overCurrentContext
            self.channelSelectorViewController?.initialize(channelItems: self.channelItems, selectionReturnProtocol: self)
        }
        
        if(self.channelSelectorViewController?.isBeingPresented ?? true) {
            return
        }
        
        self.present(self.channelSelectorViewController ?? UIViewController(), animated: true)
    }
}

// MARK: - Protocol Callbacks
extension PlayerCollectionViewController {
    
    func fullscreenPlayerDidDismiss() {
        if let syncPlayerItem = self.playerItems.first(where: {$0.id == self.fullscreenPlayerId}) {
            self.syncAllPlayers(with: syncPlayerItem)
            self.setPreferredDisplayCriteria(displayCriteria: syncPlayerItem.playerAsset?.preferredDisplayCriteria)
        }else{
            self.playAll()
        }
    }
    
    func didSelectChannel(channelItem: ContentItem) {
        self.loadStreamEntitlement(channelItem: channelItem)
    }
}

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
            self.playerInfoViewController?.initialize(contentItem: self.channelItems.first(where: {$0.channelType == .MainFeed}) ?? ContentItem())
        }

        if(self.playerInfoViewController?.isBeingPresented ?? true) {
            return
        }

        self.present(self.playerInfoViewController ?? UIViewController(), animated: true)
    }

    func showControlStripOverlay(for requestedIndexPath: IndexPath? = nil) {
        guard !self.playerItems.isEmpty else { return }

        self.controlStripViewController = self.getViewControllerWith(viewIdentifier: ConstantsUtil.controlStripOverlayViewController) as? ControlStripOverlayViewController
        self.controlStripViewController?.modalPresentationStyle = .overCurrentContext

        let focusedIndexPath = requestedIndexPath
            ?? self.lastFocusedPlayer
            ?? IndexPath(item: 0, section: 0)
        let focusedItemIndex = min(focusedIndexPath.item, self.playerItems.count - 1)
        let focusedPlayerItem = self.playerItems[focusedItemIndex]
        self.setControlTargetPlayer(id: focusedPlayerItem.id)

        self.controlStripViewController?.initialize(
            playerItem: focusedPlayerItem,
            playerCount: self.playerItems.count,
            controlStripActionProtocol: self,
            isLiveSession: isLiveSession,
            onDismiss: { [weak self] in
                self?.setControlTargetPlayer(id: nil)
            }
        )

        if(self.controlStripViewController?.isBeingPresented ?? true) {
            return
        }

        self.present(self.controlStripViewController ?? UIViewController(), animated: true)
    }

    func setControlTargetPlayer(id: String?) {
        guard self.controlTargetPlayerId != id else { return }
        self.controlTargetPlayerId = id

        for case let cell as ChannelPlayerCollectionViewCell in self.collectionView.visibleCells {
            guard let indexPath = self.collectionView.indexPath(for: cell), indexPath.item < self.playerItems.count else { continue }
            cell.isControlTarget = self.playerItems[indexPath.item].id == id
        }
    }

    func showChannelSelectorOverlay() {
        if(self.channelSelectorViewController == nil) {
            self.channelSelectorViewController = self.getViewControllerWith(viewIdentifier: ConstantsUtil.channelSelectorOverlayViewController) as? ChannelSelectorOverlayViewController
            self.channelSelectorViewController?.modalPresentationStyle = .overCurrentContext
            self.channelSelectorViewController?.services = services
            self.channelSelectorViewController?.initialize(channelItems: self.channelItems, selectionReturnProtocol: self)
        }

        if(self.channelSelectorViewController?.isBeingPresented ?? true) {
            return
        }

        self.channelSelectorViewController?.activeChannelKeys = Set(self.playerItems.map { ChannelPreviewCell.channelKey($0.contentItem) })
        let index = self.lastFocusedPlayer?.item ?? 0
        self.channelSelectorViewController?.referencePlayer = self.playerItems.indices.contains(index) ? self.playerItems[index].player : self.playerItems.first?.player
        self.channelSelectorViewController?.referencePlayerProvider = { [weak self] in
            guard let self else { return nil }
            let index = self.lastFocusedPlayer?.item ?? 0
            return self.playerItems.indices.contains(index) ? self.playerItems[index].player : self.playerItems.first?.player
        }
        self.present(self.channelSelectorViewController ?? UIViewController(), animated: true)
    }
}

// MARK: - Protocol Callbacks
extension PlayerCollectionViewController {

    func fullscreenPlayerDidDismiss() {
        if let syncPlayerItem = self.playerItems.first(where: {$0.id == self.fullscreenPlayerId}) {
            wantsPlayback = syncPlayerItem.player?.rate != 0
            self.syncAllPlayers(with: syncPlayerItem)
            if let player = syncPlayerItem.player { self.updatePreferredDisplayCriteria(for: player) }
        }else{
            self.playAll()
        }
    }

    func didSelectChannel(channelItem: ContentItem) {
        self.loadStreamEntitlement(channelItem: channelItem)
    }
}

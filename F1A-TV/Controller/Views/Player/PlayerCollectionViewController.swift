//
//  PlayerCollectionViewController.swift
//  F1A-TV
//
//  Created by Noah Fetz on 29.03.21.
//

import UIKit
import AVKit

class PlayerCollectionViewController: BaseCollectionViewController, StreamEntitlementLoadedProtocol, ChannelSelectionProtocol, ControlStripActionProtocol, FullscreenPlayerDismissedProtocol, PlayTimeReportedProtocol {
    
    // MARK: - Properties
    var channelItems = [ContentItem]()
    var playerItems = [PlayerItem]()
    var lastFocusedPlayer: IndexPath?
    
    var fullscreenPlayerId: String?
    
    var playerInfoViewController: PlayerInfoOverlayViewController?
    var channelSelectorViewController: ChannelSelectorOverlayViewController?
    var controlStripViewController: ControlStripOverlayViewController?
    
    var isFirstPlayer = true
    var playFromStart = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupCollectionView()
    }
    
    func initialize(channelItems: [ContentItem], playFromStart: Bool? = false) {
        self.channelItems = channelItems
        self.playFromStart = playFromStart ?? false
        
        for mainChannel in self.channelItems.filter({$0.container.metadata?.channelType == .MainFeed}) {
            self.loadStreamEntitlement(channelItem: mainChannel)
        }
    }
    
    // MARK: - Setup
    func setupCollectionView() {
        self.collectionView.backgroundColor = .black
        
        // Use custom layout for main + small players arrangement
        let customLayout = PlayerGridLayout()
        self.collectionView.collectionViewLayout = customLayout
        
        let playPauseGesture = UITapGestureRecognizer(target: self, action: #selector(self.playPausePressed))
        playPauseGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        self.collectionView.addGestureRecognizer(playPauseGesture)
        
        //Override the default menu back because we need to stop all players before we dismiss the view controller
        let menuGesture = UITapGestureRecognizer(target: self, action: #selector(self.menuPressed))
        menuGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        self.collectionView.addGestureRecognizer(menuGesture)

        let swipeUpRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeUpRegognized))
        swipeUpRecognizer.direction = .up
        self.collectionView.addGestureRecognizer(swipeUpRecognizer)

        let swipeLeftRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeLeftRegognized))
        swipeLeftRecognizer.direction = .left
        self.collectionView.addGestureRecognizer(swipeLeftRecognizer)
        
        // Add select button (long press) gesture to show channel selector (useful in simulator)
        let selectLongPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.selectLongPressed))
        selectLongPressGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        self.collectionView.addGestureRecognizer(selectLongPressGesture)
    }
    
    // MARK: - Layout Update Helper
    func applyLayoutUpdate(strategy: LayoutUpdateStrategy, changedIndex: Int, isAdding: Bool) {
        self.collectionView.collectionViewLayout.invalidateLayout()
        
        switch strategy {
        case .reloadAll:
            // Complete reload - safest option for mode changes
            self.collectionView.reloadData()
            
        case .simpleInsert(let index):
            self.collectionView.insertItems(at: [IndexPath(item: index, section: 0)])
            
        case .simpleDelete(let index):
            self.collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
            
        case .reloadMainArea, .reloadSidebarOnly:
            // For now, just reload all - can optimize later
            self.collectionView.reloadData()
        }
    }
    
    // MARK: - UICollectionView DataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if(self.playerItems.isEmpty) {
            return 1
        }
        return self.playerItems.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if(self.playerItems.isEmpty) {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ConstantsUtil.noContentCollectionViewCell, for: indexPath) as! NoContentCollectionViewCell
            
            cell.centerLabel.text = "multiplayer_no_channels_add_first".localizedString
            
            return cell
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ConstantsUtil.channelPlayerCollectionViewCell, for: indexPath) as! ChannelPlayerCollectionViewCell
        
        cell.loadingSpinner?.startAnimating()
        
        let currentItem = self.playerItems[indexPath.item]
        
        cell.titleLabel.text = ""
        cell.subtitleLabel.text = ""
        cell.subtitleLabel.textColor = .white
        
        switch currentItem.contentItem.container.metadata?.channelType {
        case .MainFeed, .AdditionalFeed:
            cell.titleLabel.text = currentItem.contentItem.container.metadata?.title
            
        case .OnBoardCamera:
            cell.titleLabel.text = currentItem.contentItem.container.metadata?.title
            
            if let additionalStream = currentItem.contentItem.container.metadata?.additionalStreams?.first {
                cell.subtitleLabel.text = additionalStream.teamName
                cell.subtitleLabel.textColor = UIColor(rgb: additionalStream.hex ?? "#00000000")
            }
            
        default:
            print("Shouldn't happen (Hopefully ^^)")
        }
        
        if let player = currentItem.player {
            cell.startPlayer(player: player)
            player.play()
            
            cell.loadingSpinner?.stopAnimating()
            
            self.waitForPlayerReadyToPlay(playerItem: currentItem)
        }
        
        return cell
    }
    
    // MARK: - UICollectionView Delegate
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if(self.playerItems.isEmpty) {
            self.showChannelSelectorOverlay()
            return
        }
        
        self.showControlStripOverlay()
    }
    
    override func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if collectionView == self.collectionView {
            if(self.playerItems.isEmpty){
                self.lastFocusedPlayer = nil
                return
            }
            
            if let nextFocusedIndexPath = context.nextFocusedIndexPath {
                self.lastFocusedPlayer = nextFocusedIndexPath
                return
            }
            
            if let previouslyFocusedIndexPath = context.previouslyFocusedIndexPath {
                self.lastFocusedPlayer = previouslyFocusedIndexPath
                return
            }
        }
    }
}

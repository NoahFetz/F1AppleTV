//
//  PlayerCollectionViewController.swift
//  F1A-TV
//
//  Created by Noah Fetz on 29.03.21.
//

import UIKit
import AVKit

class PlayerCollectionViewController: BaseCollectionViewController, UICollectionViewDelegateFlowLayout, StreamEntitlementLoadedProtocol, ChannelSelectionProtocol, ControlStripActionProtocol {
    var channelItems = [ContentItem]()
    var playerItems = [PlayerItem]()
    var lastFocusedPlayer: IndexPath?
    
    var fullscreenPlayerId: String?
    
    var playerInfoViewController: PlayerInfoOverlayViewController?
    var channelSelectorViewController: ChannelSelectorOverlayViewController?
    var controlStripViewController: ControlStripOverlayViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupCollectionView()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
//        player?.removeObserver(self, forKeyPath: “timeControlStatus”)
    }
    
    func setupCollectionView() {
        self.collectionView.backgroundColor = .black
        
        /*let mosaicLayout = FMMosaicLayoutCopy()
        self.collectionView?.collectionViewLayout = mosaicLayout*/
        
        let playPauseGesture = UITapGestureRecognizer(target: self, action: #selector(self.playPausePressed))
        playPauseGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        self.collectionView.addGestureRecognizer(playPauseGesture)
        
        //Override the default menu back because we need to stop all players before we dismiss the view controller
        let menuGesture = UITapGestureRecognizer(target: self, action: #selector(self.menuPressed))
        menuGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        self.collectionView.addGestureRecognizer(menuGesture)
        
//        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesturePerformed))
//        self.collectionView.addGestureRecognizer(panGestureRecognizer)
        
//        let swipeDownRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeDownRecognized))
//        swipeDownRecognizer.direction = .down
//        self.collectionView.addGestureRecognizer(swipeDownRecognizer)

        let swipeUpRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeUpRegognized))
        swipeUpRecognizer.direction = .up
        self.collectionView.addGestureRecognizer(swipeUpRecognizer)

        let swipeLeftRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeLeftRegognized))
        swipeLeftRecognizer.direction = .left
        self.collectionView.addGestureRecognizer(swipeLeftRecognizer)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.avPlayerDidDismiss), name: .avPlayerDidDismiss, object: nil)
    }
    
    func initialize(channelItems: [ContentItem]) {
        self.channelItems = channelItems
        
        for mainChannel in self.channelItems.filter({$0.container.metadata?.channelType == .MainFeed}) {
            self.loadStreamEntitlement(channelItem: mainChannel)
        }
    }
    
    func loadStreamEntitlement(channelItem: ContentItem) {
        self.orderChannels()
        
        let playerItem = PlayerItem(contentItem: channelItem, position: self.playerItems.count)
        self.playerItems.append(playerItem)
        
        if(self.playerItems.count == 1) {
            self.collectionView.reloadItems(at: [IndexPath(item: 0, section: 0)])
        }else{
            self.collectionView.insertItems(at: [IndexPath(item: playerItem.position, section: 0)])
        }
        
        if let id = channelItem.container.metadata?.contentId {
            if let additionalStream = channelItem.container.metadata?.additionalStreams?.first {
                
                
                self.loadStreamEntitlement(playerId: playerItem.id, contentId: additionalStream.playbackUrl)
                return
            }
            
            self.loadStreamEntitlement(playerId: playerItem.id, contentId: String(id))
        }
    }
    
    func loadStreamEntitlement(playerId: String, contentId: String) {
        var contentUrl = contentId
        if(!contentUrl.starts(with: "CONTENT")){
            contentUrl = "CONTENT/PLAY?contentId=" + contentId
        }
        DataManager.instance.loadStreamEntitlement(contentId: contentUrl, playerId: playerId, streamEntitlementLoadedProtocol: self)
    }
    
    func didLoadStreamEntitlement(playerId: String, streamEntitlement: StreamEntitlementDto) {
        if let index = self.playerItems.firstIndex(where: {$0.id == playerId}) {
            var playerItem = self.playerItems[index]
            
            playerItem.entitlement = streamEntitlement
            
            if let url = URL(string: streamEntitlement.url) {
                playerItem.playerAsset = AVAsset(url: url)
                playerItem.playerItem = AVPlayerItem(asset: playerItem.playerAsset ?? AVAsset())
                playerItem.player = AVPlayer(playerItem: playerItem.playerItem)
            }
            
            self.playerItems[index] = playerItem
            
            self.collectionView.reloadItems(at: [IndexPath(item: playerItem.position, section: 0)])
        }
    }
    
    @objc func avPlayerDidDismiss(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            if let syncPlayerId = self.fullscreenPlayerId {
                self.syncAllPlayers(with: syncPlayerId)
            }
            
            self.playAll()
        }
    }
    
    func didSelectChannel(channelItem: ContentItem) {
        self.loadStreamEntitlement(channelItem: channelItem)
    }
    
    // MARK: UICollectionViewDataSource

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
            
            cell.centerLabel.text = NSLocalizedString("multiplayer_no_channels_add_first", comment: "")
            
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
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if(self.playerItems.isEmpty) {
            self.showChannelSelectorOverlay()
            return
        }
        
        self.showControlStripOverlay()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if(self.playerItems.isEmpty) {
            return CGSize(width: collectionView.frame.width, height: collectionView.frame.height)
        }
        
        let gridSize = CGFloat(collectionView.numberOfItems(inSection: indexPath.section)).squareRoot().rounded(.up)
        
        //24 between cells + 2*24 for left and right
        let width = collectionView.frame.width/gridSize
        return CGSize(width: width, height: width/16*9)
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
    
    func waitForPlayerReadyToPlay(playerItem: PlayerItem){
        if let player = playerItem.player {
            DispatchQueue.global().async {
                var tryCount = 0
                while(player.status != .readyToPlay) {
                    if(tryCount >= 240) { //Wait max 1 min before aborting
                        print("Took more than 1 min to load, aborting...")
                        return
                    }
                    tryCount += 1
                    
                    print("Waiting for ready to play for " + String(tryCount) + " times")
                    usleep(250000)
                }
                print("Now ready to play")
                usleep(500000)
                
                self.setPreferredChannelSettings(playerItem: playerItem)
                self.syncAllPlayers(with: self.playerItems.first?.id ?? "")
            }
        }
    }
    
    func setPreferredChannelSettings(playerItem: PlayerItem) {
        let playerSettings = CredentialHelper.getPlayerSettings()
        let channelType = playerItem.contentItem.container.metadata?.channelType ?? ChannelType()
        
        if let preferredLanguage = playerSettings.getPreferredLanguage(for: channelType) {
            let setLanguageResult = playerItem.playerItem?.select(type: .audio, name: preferredLanguage)
            print("Setting preferred language: " + String(setLanguageResult ?? false))
        }
        
        playerItem.player?.volume = playerSettings.getPreferredVolume(for: channelType)
        playerItem.player?.isMuted = playerSettings.getPreferredMute(for: channelType)
    }
    
    /*@objc func panGesturePerformed(_ panGesture: UIPanGestureRecognizer) {
        let translation = panGesture.translation(in: self.collectionView)
        let velocity = panGesture.velocity(in: self.collectionView)
        
        if(abs(translation.x) > 150 && abs(velocity.x) > 8000) {
            print("Horizontal Pan gesture performed: translation x -> \(translation.x), velocity -> \(velocity.x)")
            panGesture.isEnabled = false
            panGesture.isEnabled = true
            
            if(translation.x < 0){
                self.showChannelSelectorOverlay()
            }
            
            return
        }
        
        if(abs(translation.y) > 150 && abs(velocity.y) > 8000) {
            print("Vertical Pan gesture performed: translation y -> \(translation.y), velocity -> \(velocity.y)")
            panGesture.isEnabled = false
            panGesture.isEnabled = true
            
//            self.showChannelSelectorOverlay()
            
            return
        }
    }*/
    
//    @objc func swipeDownRecognized() {
//        self.showInfoOverlay()
//    }
    
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
    
    @objc func swipeUpRegognized() {
        if(self.playerItems.isEmpty || self.lastFocusedPlayer == nil) {
            return
        }
        
        self.showControlStripOverlay()
    }
    
    func showControlStripOverlay() {
        self.controlStripViewController = self.getViewControllerWith(viewIdentifier: ConstantsUtil.controlStripOverlayViewController) as? ControlStripOverlayViewController
        self.controlStripViewController?.modalPresentationStyle = .overCurrentContext
        
        let focusedPlayerItem = self.playerItems[self.lastFocusedPlayer?.item ?? 0]
        
        self.controlStripViewController?.initialize(playerItem: focusedPlayerItem, controlStripActionProtocol: self)
        
        if(self.controlStripViewController?.isBeingPresented ?? true) {
            return
        }
        
        self.present(self.controlStripViewController ?? UIViewController(), animated: true)
    }
    
    @objc func swipeLeftRegognized() {
        self.showChannelSelectorOverlay()
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
    
    func willCloseFocusedPlayer() {
        if(self.lastFocusedPlayer == nil) {
            return
        }
        
        let playerItem = self.playerItems[self.lastFocusedPlayer?.item ?? 0]
        playerItem.player?.pause()
        
        self.playerItems.removeAll(where: {$0.id == playerItem.id})
        self.orderChannels()
        
        if(self.playerItems.isEmpty) {
            self.collectionView.reloadItems(at: [self.lastFocusedPlayer ?? IndexPath()])
        }else{
            self.collectionView.deleteItems(at: [self.lastFocusedPlayer ?? IndexPath()])
        }
    }
    
    func enterFullScreenPlayer() {
        if(self.lastFocusedPlayer == nil) {
            return
        }
        
        let playerItem = self.playerItems[self.lastFocusedPlayer?.item ?? 0]
        self.fullscreenPlayerId = playerItem.id
        
        if let player = playerItem.player {
            self.pauseAll(excludeIds: [playerItem.id])
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                PlayerController.instance.openPlayer(player: player)
            }
        }
    }
    
    func playPausePlayer() {
        self.playPausePressed()
    }
    
    func rewindPlayer() {
        self.rewindAllPlayersBy(seconds: 15)
    }
    
    func forwardPlayer() {
        self.forwardAllPlayersBy(seconds: 15)
    }
    
    @objc func playPausePressed() {
        if let firstPlayer = self.playerItems.first {
            if(firstPlayer.player?.timeControlStatus == .paused){
                print("Resuming playback after syncing all channels")
                
                self.syncAllPlayers(with: firstPlayer.id)
                self.playAll()
            }else{
                print("Pausing playback")
                
                self.pauseAll()
            }
        }
    }
    
    @objc func menuPressed() {
        self.pauseAll()
        self.dismiss(animated: true)
    }
    
    func syncAllPlayers(with playerId: String) {
        DispatchQueue.main.async {
            print("Syncing all channels")
            let syncPlayerItem = self.playerItems.first(where: {$0.id == playerId})
            
            if let currentTime = syncPlayerItem?.player?.currentTime() {
                var syncTime = CMTimeGetSeconds(currentTime)
                
                for playerItem in self.playerItems {
                    if(playerItem.id == playerId){
                        continue
                    }
                    
                    if let player = playerItem.player, let duration = player.currentItem?.duration {
                        if syncTime >= CMTimeGetSeconds(duration) {
                            syncTime = CMTimeGetSeconds(duration)
                        }
                        player.seek(to: CMTime(value: CMTimeValue(syncTime * 1000), timescale: 1000))
                        
                        if(player.timeControlStatus == .paused) {
                            player.play()
                        }
                    }
                }
            }
        }
    }
    
    func forwardAllPlayersBy(seconds: Float64) {
        let syncPlayerItem = self.playerItems.first
        
        if let currentTime = syncPlayerItem?.player?.currentTime() {
            let syncTime = CMTimeGetSeconds(currentTime) + seconds
            self.seekAllPlayersTo(time: syncTime)
        }
    }
    
    func rewindAllPlayersBy(seconds: Float64) {
        let syncPlayerItem = self.playerItems.first
        
        if let currentTime = syncPlayerItem?.player?.currentTime() {
            let syncTime = CMTimeGetSeconds(currentTime) - seconds
            self.seekAllPlayersTo(time: syncTime)
        }
    }
    
    func seekAllPlayersTo(time: Float64) {
        DispatchQueue.main.async {
            var syncTime = time
            
            for playerItem in self.playerItems {
                if let player = playerItem.player, let duration = player.currentItem?.duration {
                    if syncTime >= CMTimeGetSeconds(duration) {
                        syncTime = CMTimeGetSeconds(duration)
                    }
                    player.seek(to: CMTime(value: CMTimeValue(syncTime * 1000), timescale: 1000))
                }
            }
        }
    }
    
    func pauseAll(excludeIds: [String]? = [String]()) {
        DispatchQueue.main.async {
            for playerItem in self.playerItems {
                if((excludeIds?.contains(playerItem.id) ?? false)){
                    continue
                }
                
                if let player = playerItem.player {
                    player.pause()
                }
            }
        }
    }
    
    func playAll(excludeIds: [String]? = [String]()) {
        DispatchQueue.main.async {
            for playerItem in self.playerItems {
                if((excludeIds?.contains(playerItem.id) ?? false)){
                    continue
                }
                
                if let player = playerItem.player {
                    player.play()
                }
            }
        }
    }
    
    func orderChannels() {
        if(self.playerItems.isEmpty) {
            return
        }
        
        for positionIndex in 0...self.playerItems.count-1 {
            self.playerItems[positionIndex].position = positionIndex
        }
    }
}

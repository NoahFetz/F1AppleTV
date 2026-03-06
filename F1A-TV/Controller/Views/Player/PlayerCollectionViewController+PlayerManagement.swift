//
//  PlayerCollectionViewController+PlayerManagement.swift
//  F1A-TV
//
//  Created by Noah Fetz on 29.03.21.
//

import UIKit
import AVKit

// MARK: - Player Lifecycle & Synchronization
extension PlayerCollectionViewController {
    
    func syncAllPlayers(with syncPlayerItem: PlayerItem) {
        DispatchQueue.main.async {
            print("Syncing all channels")
            
            if let currentTime = syncPlayerItem.player?.currentTime() {
                var syncTime = CMTimeGetSeconds(currentTime)
                
                for playerItem in self.playerItems {
                    if(playerItem.id == syncPlayerItem.id){
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
            
            if(syncPlayerItem.player?.timeControlStatus == .paused) {
                syncPlayerItem.player?.play()
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
    
    func setPreferredDisplayCriteria(displayCriteria: AVDisplayCriteria?) {
        let displayNamager = UserInteractionHelper.instance.getKeyWindow().avDisplayManager
        displayNamager.preferredDisplayCriteria = displayCriteria
    }
}

// MARK: - Stream Loading & Configuration
extension PlayerCollectionViewController {
    
    func loadStreamEntitlement(channelItem: ContentItem) {
        self.orderChannels()
        
        let oldCount = self.playerItems.count
        
        let playerItem = PlayerItem(contentItem: channelItem, position: self.playerItems.count)
        self.playerItems.append(playerItem)
        self.orderChannels()
        
        let newCount = self.playerItems.count
        
        // Determine update strategy
        let strategy = LayoutUpdateStrategy.determine(
            oldCount: oldCount,
            newCount: newCount,
            oldMainIndex: 0,
            newMainIndex: 0,
            changedIndex: newCount - 1
        )
        
        // Apply the layout update
        self.applyLayoutUpdate(strategy: strategy, changedIndex: newCount - 1, isAdding: true)
        
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
            
            playerItem.player = FairPlayer()
            playerItem.player?.playStream(streamEntitlement: streamEntitlement)
            playerItem.playerAsset = playerItem.player?.makeFairPlayReady()
            playerItem.playerItem = AVPlayerItem(asset: playerItem.playerAsset ?? AVAsset())
            playerItem.player?.replaceCurrentItem(with: playerItem.playerItem)
            playerItem.player?.appliesMediaSelectionCriteriaAutomatically = false
            
            if(self.playFromStart) {
                playerItem.player?.seek(to: CMTimeMakeWithSeconds(Float64(1), preferredTimescale: 1))
                self.playFromStart = false
            }
            
            self.setPreferredDisplayCriteria(displayCriteria: playerItem.playerAsset?.preferredDisplayCriteria)
            
            // Mute sidebar/bottom players (all players except the main player at index 0)
            if index != 0 {
                playerItem.player?.isMuted = true
                playerItem.player?.volume = 0.0
                print("Muting and silencing sidebar/bottom player at index \(index)")
            }
            
            self.playerItems[index] = playerItem
            
            self.collectionView.reloadItems(at: [IndexPath(item: playerItem.position, section: 0)])
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
                
                if let resumePlayHeadPosition = playerItem.contentItem.container.user?.resume?.playHeadPosition, self.isFirstPlayer {
                    self.seekAllPlayersTo(time: Float64(resumePlayHeadPosition))
                    self.isFirstPlayer = false
                }else{
                    self.syncAllPlayers(with: self.playerItems.first ?? PlayerItem())
                }
            }
        }
    }
    
    func setPreferredChannelSettings(playerItem: PlayerItem) {
        let playerSettings = CredentialHelper.getPlayerSettings()
        let channelType = playerItem.contentItem.container.metadata?.channelType ?? ChannelType()
        
        if let preferredLanguage = playerSettings.getPreferredLanguage(for: channelType) {
            let setLanguageResult = playerItem.playerItem?.select(type: .audio, languageDisplayName: preferredLanguage)
            print("Setting preferred language: " + String(setLanguageResult ?? false))
        }

        if let preferredCaptions = playerSettings.getPreferredCaptions(for: channelType) {
            let setCaptionResult = playerItem.playerItem?.select(type: .subtitle, languageDisplayName: preferredCaptions)
            print("Setting preferred caption: " + String(setCaptionResult ?? false))
        }
        
        // Only apply volume/mute preferences for the main player (position 0)
        // Sidebar/bottom players should remain muted with volume at 0
        if playerItem.position == 0 {
            playerItem.player?.volume = playerSettings.getPreferredVolume(for: channelType)
            playerItem.player?.isMuted = playerSettings.getPreferredMute(for: channelType)
            print("Applied preferred audio settings for main player: volume=\(playerSettings.getPreferredVolume(for: channelType)), muted=\(playerSettings.getPreferredMute(for: channelType))")
        } else {
            // Keep sidebar/bottom players muted and silent
            playerItem.player?.isMuted = true
            playerItem.player?.volume = 0.0
            print("Keeping sidebar/bottom player muted and silent at position \(playerItem.position)")
        }
    }
}

// MARK: - Play Time Reporting
extension PlayerCollectionViewController {
    
    func reportCurrentPlayTime() {
        if let firstItem = self.playerItems.first ,let contentId = firstItem.contentItem.container.contentId, let contentSubType = firstItem.contentItem.container.metadata?.contentSubtype, let playerDuration = firstItem.player?.currentTime() {
            DataManager.instance.reportContentPlayTime(reportingItem: PlayTimeReportingDto(contentId: contentId, contentSubType: contentSubType, playHeadPosition: Int(CMTimeGetSeconds(playerDuration)), timestamp: Int(Date().timeIntervalSince1970)), playTimeReportingProtocol: self)
        }
    }
    
    func didReportPlayTime() {
        print("Successfully reported current play time")
    }
}

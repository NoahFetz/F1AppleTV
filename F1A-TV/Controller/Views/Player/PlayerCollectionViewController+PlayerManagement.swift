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
    
    func updatePreferredDisplayCriteria(for player: FairPlayer) {
        displayCriteriaTask?.cancel()
        guard let asset = player.fairPlayAsset else { return }
        displayCriteriaTask = Task { @MainActor [weak self, weak player] in
            let criteria = try? await asset.load(.preferredDisplayCriteria)
            guard let self, let player, !Task.isCancelled,
                  self.playerItems.contains(where: { $0.player === player }),
                  player.currentItem?.asset === asset, self.viewIfLoaded?.window != nil else { return }
            self.setPreferredDisplayCriteria(displayCriteria: criteria)
        }
    }

    func setPreferredDisplayCriteria(displayCriteria: AVDisplayCriteria?) {
        let displayNamager = (view.window ?? UserInteractionHelper.instance.getKeyWindow())?.avDisplayManager
        displayNamager?.preferredDisplayCriteria = displayCriteria
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
        
        if let id = channelItem.contentId {
            if let additionalStream = channelItem.channel {
                
                
                self.loadStreamEntitlement(playerId: playerItem.id, contentId: additionalStream.target.uri)
                return
            }
            
            self.loadStreamEntitlement(playerId: playerItem.id, contentId: String(id))
        }
    }
    
    func loadStreamEntitlement(playerId: String, contentId: String) {
        entitlementTasks[playerId]?.cancel()
        let playback = services.playback
        let generation = UUID(); entitlementGenerations[playerId] = generation
        entitlementTasks[playerId] = Task { [weak self] in
            do {
                let entitlement = try await playback.entitlement(PlaybackTarget(uri: contentId, requiresVideoDetails: false))
                try Task.checkCancellation()
                guard let self, self.entitlementGenerations[playerId] == generation, !Task.isCancelled, self.playerItems.contains(where: { $0.id == playerId }) else { return }
                self.entitlementTasks.removeValue(forKey: playerId)
                self.didLoadStreamEntitlement(playerId: playerId, streamEntitlement: entitlement)
            } catch {
                guard let self, self.entitlementGenerations[playerId] == generation, !Task.isCancelled, self.playerItems.contains(where: { $0.id == playerId }), !(error is CancellationError) else { return }
                self.entitlementTasks.removeValue(forKey: playerId)
                recordServiceFailure(error, operation: .entitlement)
                UserInteractionHelper.instance.showError(title: "error".localizedString, message: "diagnostics_summary_operation".localizedString, recordsError: false, retry: { [weak self] in self?.loadStreamEntitlement(playerId: playerId, contentId: contentId) })
            }
        }
    }

    func didLoadStreamEntitlement(playerId: String, streamEntitlement: PlaybackEntitlement) {
        if let index = self.playerItems.firstIndex(where: {$0.id == playerId}) {
            var playerItem = self.playerItems[index]
            
            playerItem.entitlement = streamEntitlement
            
            playerItem.player = FairPlayer()
            playerItem.player?.fairPlayService = services.fairPlay
            playerItem.player?.playStream(streamEntitlement: streamEntitlement)
            playerItem.player?.appliesMediaSelectionCriteriaAutomatically = false
            let fromStart = self.playFromStart
            self.playFromStart = false
            
            // Mute sidebar/bottom players (all players except the main player at index 0)
            if index != 0 {
                playerItem.player?.isMuted = true
                playerItem.player?.volume = 0.0
                print("Muting and silencing sidebar/bottom player at index \(index)")
            }
            
            self.playerItems[index] = playerItem
            playerItem.player?.prepareStream(startupMaximumHeight: CredentialHelper.getPlayerSettings().startupMaximumHeight) { [weak self, weak player = playerItem.player] _ in
                guard let self = self, let player = player,
                      let currentIndex = self.playerItems.firstIndex(where: { $0.id == playerId && $0.player === player }) else { return }
                if fromStart { player.seek(to: CMTimeMakeWithSeconds(1, preferredTimescale: 1)) }
                if currentIndex == 0 { self.updatePreferredDisplayCriteria(for: player) }
                self.collectionView.reloadItems(at: [IndexPath(item: currentIndex, section: 0)])
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
                
                DispatchQueue.main.async { self.setPreferredChannelSettings(playerItem: playerItem) }
                
                if let resumePlayHeadPosition = playerItem.contentItem.resumePosition, self.isFirstPlayer {
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
        let channelType = playerItem.contentItem.channelType ?? ChannelType()
        
        if let item = playerItem.playerItem, defaultsAppliedPlayerIDs.insert(playerItem.id).inserted {
            defaultsTasks[playerItem.id]?.cancel()
            defaultsTasks[playerItem.id] = Task { @MainActor [weak self, weak player = playerItem.player] in
                await PlaybackDefaults.apply(to: item, channel: channelType, settings: playerSettings) {
                    guard let self, let player else { return false }
                    return self.playerItems.contains { $0.id == playerItem.id && $0.player === player } && player.currentItem === item
                }
            }
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
        guard reportingTask == nil, let first = playerItems.first, let id = first.contentItem.contentId, let subtype = first.contentItem.contentSubtype, let seconds = first.player?.currentTime().seconds, seconds.isFinite else { return }
        let playback = services.playback
        reportingTask = Task { [weak self] in
            defer { self?.reportingTask = nil }
            do { try await playback.report(contentID: id, subtype: subtype, position: Int(seconds), timestamp: Int(Date().timeIntervalSince1970)) }
            catch { guard !(error is CancellationError) else { return }; recordServiceFailure(error, operation: .action) }
        }
    }
}

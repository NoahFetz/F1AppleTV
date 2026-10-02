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
        guard let reference = syncPlayerItem.player else { return }
        let identity = synchronizationGeneration
        for playerItem in playerItems where playerItem.id != syncPlayerItem.id {
            guard let player = playerItem.player, player.currentItem?.status == .readyToPlay else { continue }
            StreamSynchronization.seek(player, to: reference, isCurrent: { [weak self, weak player] in
                guard let self, let player else { return false }; return self.synchronizationGeneration == identity && self.playerItems.contains { $0.player === player }
            }) { [weak self, weak player] done in
                guard let self, let player, done, self.synchronizationGeneration == identity,
                      self.playerItems.contains(where: { $0.player === player }) else { return }
                if reference.rate == 0 { player.pause() } else { player.play() }
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
        guard time.isFinite else { return }
        for playerItem in playerItems {
            guard let player = playerItem.player, let item = player.currentItem else { continue }
            let range = item.seekableTimeRanges.last?.timeRangeValue
            let lower = range?.start.seconds ?? 0
            let upper = range.map { CMTimeRangeGetEnd($0).seconds - 0.1 } ?? (item.duration.seconds.isFinite ? item.duration.seconds : time)
            player.seek(to: CMTime(seconds: max(lower, min(time, max(lower, upper))), preferredTimescale: 600))
        }
    }

    func pauseAll(excludeIds: [String]? = []) {
        if excludeIds?.isEmpty != false { wantsPlayback = false }
        for item in playerItems where !(excludeIds?.contains(item.id) ?? false) { item.player?.pause() }
    }

    func playAll(excludeIds: [String]? = []) {
        wantsPlayback = true
        for item in playerItems where !(excludeIds?.contains(item.id) ?? false) { item.player?.play() }
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
        
        guard !playerItems.contains(where: { $0.contentItem.previewIdentity == channelItem.previewIdentity }) else { return }
        let playerItem = PlayerItem(contentItem: channelItem, position: playerItems.count)
        playerItems.append(playerItem)
        orderChannels()
        layoutChoice = layoutChoice.afterAdding(count: playerItems.count)
        refreshPlayerLayout()

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
                self.observeReadiness(id: playerId, player: player)
            }
        }
    }
    
    func observeReadiness(id: String, player: FairPlayer) {
        guard let item = player.currentItem else { return }
        readyObservations[id] = item.observe(\.status, options: [.initial, .new]) { [weak self, weak player] item, _ in
            DispatchQueue.main.async {
                guard let self, let player, self.playerItems.contains(where: { $0.id == id && $0.player === player }),
                      player.currentItem === item else { return }
                guard item.status == .readyToPlay, self.initializedPlayerIDs.insert(id).inserted else { return }
                self.readyObservations.removeValue(forKey: id)
                guard let current = self.playerItems.first(where: { $0.id == id }) else { return }
                self.setPreferredChannelSettings(playerItem: current)
                if let audio = self.setupAudio.removeValue(forKey: id) { player.volume = audio.volume; player.isMuted = audio.muted }
                if self.liveCoordinator.hasJump { self.liveCoordinator.include(AVLiveSeekSession(player)); return }
                if let (anchor, generation) = self.startupAnchors.removeValue(forKey: id), generation == self.synchronizationGeneration {
                    anchor.apply(to: player, isCurrent: { [weak self, weak player] in
                        guard let self, let player else { return false }; return self.synchronizationGeneration == generation && self.playerItems.contains { $0.player === player }
                    }) { [weak self, weak player] done in
                        guard let self, let player, done, self.synchronizationGeneration == generation,
                              self.playerItems.contains(where: { $0.player === player }) else { return }
                        if !self.wantsPlayback { player.pause() } else { player.play() }
                    }
                    return
                }
                if let reference = self.playerItems.first?.player, reference !== player {
                    let generation = self.synchronizationGeneration
                    StreamSynchronization.seek(player, to: reference, isCurrent: { [weak self, weak player] in
                        guard let self, let player else { return false }; return self.synchronizationGeneration == generation && self.playerItems.contains { $0.player === player }
                    }) { [weak self, weak player] done in
                        guard let self, let player, done, self.synchronizationGeneration == generation,
                              self.playerItems.contains(where: { $0.player === player }) else { return }
                        if reference.rate == 0 { player.pause() } else { player.play() }
                    }
                } else {
                    if let resume = current.contentItem.resumePosition, self.isFirstPlayer {
                        player.seek(to: CMTime(seconds: resume, preferredTimescale: 600))
                    }
                    self.isFirstPlayer = false
                    if self.wantsPlayback { player.play() } else { player.pause() }
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

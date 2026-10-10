#if canImport(F1Core)
import F1Core
#endif
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
            let seekID = UUID(); playerSeekGenerations[playerItem.id] = seekID
            restoringPlayerIDs.insert(playerItem.id)
            StreamSynchronization.seek(player, to: reference, isCurrent: { [weak self, weak player] in
                guard let self, let player else { return false }; return self.synchronizationGeneration == identity && self.playerSeekGenerations[playerItem.id] == seekID && self.playerItems.contains { $0.player === player }
            }) { [weak self, weak player] done in
                guard let self, let player, self.synchronizationGeneration == identity,
                      self.playerSeekGenerations[playerItem.id] == seekID,
                      self.playerItems.contains(where: { $0.player === player }) else { return }
                self.restoringPlayerIDs.remove(playerItem.id)
                if !done { if self.startupTimeouts[playerItem.id] != nil { self.streamFailed(id: playerItem.id) }; return }
                self.startupTimeouts.removeValue(forKey: playerItem.id)?.cancel()
                self.restoringPlayerIDs.remove(playerItem.id)
                if !self.wantsPlayback { player.pause() } else { player.play() }
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
        guard let reference = synchronizationReference, let player = reference.player, let item = player.currentItem else { return }
        let generation = synchronizationGeneration
        pendingSeekTime = time
        pendingSeekReferenceID = reference.id
        playerItems.forEach { $0.player?.currentItem?.cancelPendingSeeks() }
        let range = item.seekableTimeRanges.last?.timeRangeValue
        let lower = range?.start.seconds ?? 0
        let upper = range.map { CMTimeRangeGetEnd($0).seconds - 0.1 } ?? (item.duration.seconds.isFinite ? item.duration.seconds : time)
        player.seek(to: CMTime(seconds: max(lower, min(time, max(lower, upper))), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, weak player] done in
            DispatchQueue.main.async {
                guard let self, let player, self.synchronizationGeneration == generation,
                      self.playerItems.contains(where: { $0.player === player }) else { return }
                self.pendingSeekTime = nil; self.pendingSeekReferenceID = nil
                if done { if self.wantsPlayback { player.play() } else { player.pause() } }
                // Join only after the reference lands: feeds may have different
                // live media origins, so synchronize by program date/live lag.
                self.syncAllPlayers(with: reference)
                if done { self.rememberPlaybackPosition(); self.reportCurrentPlayTime() }
            }
        }
    }

    var synchronizationReference: PlayerItem? {
        playerItems.first { !$0.hasFailed && !restoringPlayerIDs.contains($0.id) && $0.player?.currentItem?.status == .readyToPlay }
    }
    func cancelSynchronization() {
        liveCoordinator.cancel()
        synchronizationGeneration = UUID(); pendingSeekTime = nil; pendingSeekReferenceID = nil
        restoringPlayerIDs.removeAll()
        playerSeekGenerations.removeAll()
        playerItems.forEach { $0.player?.currentItem?.cancelPendingSeeks() }
        startupAnchors = startupAnchors.mapValues { ($0.0, synchronizationGeneration) }
    }
    func rememberPlaybackPosition() {
        guard pendingSeekTime == nil, let player = synchronizationReference?.player else { return }
        let snapshot = PlaybackPositionSnapshot(player)
        if snapshot.seconds.isFinite { lastPlaybackPosition = snapshot }
    }
    func updatePlaybackIdleTimer() {
        PlaybackIdleTimer.shared.setPlayers(isExitingPlayback ? [] : playerItems.compactMap(\.player), owner: self)
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
        guard !isExitingPlayback, let index = playerItems.firstIndex(where: { $0.id == playerId }) else { return }
        playerItems[index].hasFailed = false
        startupTimeouts.removeValue(forKey: playerId)?.cancel()
        entitlementTasks[playerId]?.cancel()
        let playback = services.playback
        let generation = UUID(); entitlementGenerations[playerId] = generation
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.entitlementGenerations[playerId] == generation else { return }
            let error = URLError(.timedOut)
            recordServiceFailure(error, operation: .preparation)
            self.streamFailed(id: playerId)
        }
        startupTimeouts[playerId] = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeout)
        entitlementTasks[playerId] = Task { [weak self] in
            do {
                let entitlement = try await playback.entitlement(PlaybackTarget(uri: contentId, requiresVideoDetails: false))
                try Task.checkCancellation()
                guard let self, self.entitlementGenerations[playerId] == generation, !Task.isCancelled, self.playerItems.contains(where: { $0.id == playerId }) else { return }
                self.entitlementTasks.removeValue(forKey: playerId)
                self.didLoadStreamEntitlement(playerId: playerId, streamEntitlement: entitlement, contentId: contentId)
            } catch {
                guard let self, self.entitlementGenerations[playerId] == generation, !Task.isCancelled, self.playerItems.contains(where: { $0.id == playerId }), !(error is CancellationError) else { return }
                self.entitlementTasks.removeValue(forKey: playerId)
                recordServiceFailure(error, operation: .entitlement)
                self.streamFailed(id: playerId)
            }
        }
    }

    func didLoadStreamEntitlement(playerId: String, streamEntitlement: PlaybackEntitlement, contentId: String) {
        if let index = self.playerItems.firstIndex(where: {$0.id == playerId}) {
            var playerItem = self.playerItems[index]
            playerItem.thumbnails?.reset()
            
            playerItem.entitlement = streamEntitlement
            
            let player = FairPlayer()
            player.preventsDisplaySleepDuringVideoPlayback = true
            player.onPlaybackError = { [weak self, weak player] _ in
                guard let self, let player, self.playerItems.contains(where: { $0.id == playerId && $0.player === player }) else { return }
                self.streamFailed(id: playerId)
            }
            playerItem.player = player
            playerItem.player?.fairPlayService = services.fairPlay
            playerItem.player?.playStream(streamEntitlement: streamEntitlement)
            if let player = playerItem.player {
                let playback = services.playback
                playerItem.thumbnails = StreamThumbnailProvider(player: player) {
                    try await playback.entitlement(PlaybackTarget(uri: contentId, requiresVideoDetails: false))
                }
            }
            playerItem.player?.appliesMediaSelectionCriteriaAutomatically = false
            self.playFromStart = false
            
            // Mute sidebar/bottom players (all players except the main player at index 0)
            if index != 0 {
                playerItem.player?.isMuted = true
                playerItem.player?.volume = 0.0
                print("Muting and silencing sidebar/bottom player at index \(index)")
            }
            
            self.playerItems[index] = playerItem
            updatePlaybackIdleTimer()
            playerItem.player?.prepareStream(startupMaximumHeight: CredentialHelper.getPlayerSettings().startupMaximumHeight) { [weak self, weak player = playerItem.player] _ in
                guard let self = self, let player = player,
                      let currentIndex = self.playerItems.firstIndex(where: { $0.id == playerId && $0.player === player }) else { return }
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
                if self.pendingSeekTime != nil { return }
                if self.liveCoordinator.hasJump {
                    self.startupTimeouts.removeValue(forKey: id)?.cancel()
                    self.liveCoordinator.include(AVLiveSeekSession(player)); return
                }
                if let (anchor, generation) = self.startupAnchors.removeValue(forKey: id), generation == self.synchronizationGeneration,
                   self.playerItems.first?.id == id || self.playerItems.first?.player?.currentItem?.status != .readyToPlay || self.playerItems.first.map({ self.restoringPlayerIDs.contains($0.id) }) == true {
                    self.restoringPlayerIDs.insert(id)
                    let seekID = UUID(); self.playerSeekGenerations[id] = seekID
                    anchor.apply(to: player, isCurrent: { [weak self, weak player] in
                        guard let self, let player else { return false }; return self.synchronizationGeneration == generation && self.playerSeekGenerations[id] == seekID && self.playerItems.contains { $0.player === player }
                    }) { [weak self, weak player] done in
                        guard let self, let player, self.synchronizationGeneration == generation,
                              self.playerSeekGenerations[id] == seekID,
                              self.playerItems.contains(where: { $0.player === player }) else { return }
                        self.restoringPlayerIDs.remove(id)
                        guard done else { self.streamFailed(id: id); return }
                        self.startupTimeouts.removeValue(forKey: id)?.cancel()
                        if !self.wantsPlayback { player.pause() } else { player.play() }
                        if self.playerItems.first?.id == id { self.syncAllPlayers(with: current) }
                    }
                    return
                }
                if let reference = self.synchronizationReference?.player, reference !== player {
                    let generation = self.synchronizationGeneration
                    self.restoringPlayerIDs.insert(id)
                    let seekID = UUID(); self.playerSeekGenerations[id] = seekID
                    StreamSynchronization.seek(player, to: reference, isCurrent: { [weak self, weak player] in
                        guard let self, let player else { return false }; return self.synchronizationGeneration == generation && self.playerSeekGenerations[id] == seekID && self.playerItems.contains { $0.player === player }
                    }) { [weak self, weak player] done in
                        guard let self, let player, self.synchronizationGeneration == generation,
                              self.playerSeekGenerations[id] == seekID,
                              self.playerItems.contains(where: { $0.player === player }) else { return }
                        self.restoringPlayerIDs.remove(id)
                        guard done else { self.streamFailed(id: id); return }
                        self.startupTimeouts.removeValue(forKey: id)?.cancel()
                        if !self.wantsPlayback { player.pause() } else { player.play() }
                    }
                } else {
                    let resume = self.startedFromBeginning ? 1 : current.contentItem.resumePosition
                    if let resume, resume.isFinite, self.isFirstPlayer {
                        self.isFirstPlayer = false
                        let generation = self.synchronizationGeneration
                        self.restoringPlayerIDs.insert(id)
                        let seekID = UUID(); self.playerSeekGenerations[id] = seekID
                        player.seek(to: CMTime(seconds: max(0, resume), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, weak player] done in
                            DispatchQueue.main.async {
                                guard let self, let player, self.synchronizationGeneration == generation,
                                      self.playerSeekGenerations[id] == seekID,
                                      self.playerItems.contains(where: { $0.id == id && $0.player === player }) else { return }
                                self.restoringPlayerIDs.remove(id)
                                guard done else { self.streamFailed(id: id); return }
                                self.startupTimeouts.removeValue(forKey: id)?.cancel()
                                if self.wantsPlayback { player.play() } else { player.pause() }
                                self.rememberPlaybackPosition(); self.syncAllPlayers(with: current)
                            }
                        }
                        return
                    }
                    self.startupTimeouts.removeValue(forKey: id)?.cancel()
                    self.isFirstPlayer = false
                    if self.wantsPlayback { player.play() } else { player.pause() }
                    self.rememberPlaybackPosition()
                }
            }
        }
    }

    func setPreferredChannelSettings(playerItem: PlayerItem) {
        let playerSettings = CredentialHelper.getPlayerSettings()
        let channelType = playerItem.contentItem.channelType ?? ChannelType()
        let feed = playerItem.contentItem.channel.map(StreamSelection.init)
        
        if let item = playerItem.playerItem, defaultsAppliedPlayerIDs.insert(playerItem.id).inserted {
            defaultsTasks[playerItem.id]?.cancel()
            defaultsTasks[playerItem.id] = Task { @MainActor [weak self, weak player = playerItem.player] in
                await PlaybackDefaults.apply(to: item, channel: channelType, settings: playerSettings, isF1Live: feed == .f1Live) {
                    guard let self, let player else { return false }
                    return self.playerItems.contains { $0.id == playerItem.id && $0.player === player } && player.currentItem === item
                }
                if feed == .f1Live, let group = try? await item.asset.loadMediaSelectionGroup(for: .audible),
                   !Task.isCancelled, let self, let player,
                   self.playerItems.contains(where: { $0.id == playerItem.id && $0.player === player }), player.currentItem === item {
                    var settings = CredentialHelper.getPlayerSettings()
                    settings.discoveredF1LiveAudioTracks = group.options.map(\.displayName)
                    CredentialHelper.setPlayerSettings(playerSettings: settings)
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
        rememberPlaybackPosition()
        guard !isLiveSession, let first = playerItems.first, let id = first.contentItem.contentId,
              let subtype = first.contentItem.contentSubtype, let seconds = lastPlaybackPosition?.seconds,
              seconds.isFinite, seconds >= 0, seconds < Double(Int.max) else { return }
        progressReporter.submit(.init(contentID: id, subtype: subtype, position: Int(seconds), timestamp: Int(Date().timeIntervalSince1970)))
    }
}

extension PlayerCollectionViewController {
    func discardPlayerResources(id: String) {
        entitlementTasks.removeValue(forKey: id)?.cancel(); entitlementGenerations.removeValue(forKey: id)
        startupTimeouts.removeValue(forKey: id)?.cancel()
        readyObservations.removeValue(forKey: id)
        defaultsTasks.removeValue(forKey: id)?.cancel()
        initializedPlayerIDs.remove(id); defaultsAppliedPlayerIDs.remove(id)
        restoringPlayerIDs.remove(id)
        playerSeekGenerations.removeValue(forKey: id)
        guard let index = playerItems.firstIndex(where: { $0.id == id }) else { return }
        playerItems[index].thumbnails?.reset(); playerItems[index].thumbnails = nil
        playerItems[index].player?.onPlaybackError = nil
        playerItems[index].player?.stopStream(); playerItems[index].player = nil
    }
    func streamFailed(id: String) {
        guard !isExitingPlayback, let index = playerItems.firstIndex(where: { $0.id == id }), !playerItems[index].hasFailed else { return }
        rememberPlaybackPosition()
        let item = playerItems[index]
        if let channel = item.contentItem.channel, let player = item.player {
            setupAudio[id] = SavedStream(selection: StreamSelection(channel: channel), volume: player.volume, muted: player.isMuted)
        }
        discardPlayerResources(id: id)
        playerItems[index].hasFailed = true
        if pendingSeekReferenceID == id, let target = pendingSeekTime {
            cancelSynchronization()
            seekAllPlayersTo(time: target)
        }
        updatePlaybackIdleTimer(); refreshPlayerLayout()
        guard viewIfLoaded?.window != nil else { return }
        UserInteractionHelper.instance.showError(title: "error".localizedString, message: "stream_failed_retry".localizedString, recordsError: false, retry: { [weak self] in self?.restartPlayer(id: id) })
    }
    func restartPlayer(id: String, anchor: PlaybackPositionSnapshot? = nil) {
        guard !isExitingPlayback, let item = playerItems.first(where: { $0.id == id }) else { return }
        rememberPlaybackPosition()
        let position = anchor ?? lastPlaybackPosition
        if let channel = item.contentItem.channel, let player = item.player {
            setupAudio[id] = SavedStream(selection: StreamSelection(channel: channel), volume: player.volume, muted: player.isMuted)
        }
        discardPlayerResources(id: id)
        if let position { startupAnchors[id] = (position, synchronizationGeneration) }
        if let uri = item.contentItem.channel?.target.uri ?? item.contentItem.contentId.map({ String($0) }) {
            loadStreamEntitlement(playerId: id, contentId: uri)
        }
        updatePlaybackIdleTimer(); refreshPlayerLayout()
    }
}

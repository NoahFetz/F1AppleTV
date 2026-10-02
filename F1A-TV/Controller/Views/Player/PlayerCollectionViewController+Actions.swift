//
//  PlayerCollectionViewController+Actions.swift
//  F1A-TV
//
//  Created by Noah Fetz on 29.03.21.
//

import UIKit

// MARK: - Gesture Actions & User Interactions
extension PlayerCollectionViewController {

    @objc func playPausePressed() {
        liveCoordinator.cancel()
        synchronizationGeneration = UUID()
        self.reportCurrentPlayTime()

        if let firstPlayer = self.playerItems.first {
            if !wantsPlayback {
                print("Resuming playback after syncing all channels")

                self.syncAllPlayers(with: firstPlayer)
                self.playAll()
            }else{
                print("Pausing playback")

                self.pauseAll()
            }
        }
    }

    @objc func menuPressed() {
        liveCoordinator.cancel()
        synchronizationGeneration = UUID()
        readyObservations.removeAll()
        self.reportCurrentPlayTime()

        self.pauseAll()
        entitlementTasks.values.forEach { $0.cancel() }; entitlementTasks.removeAll(); entitlementGenerations.removeAll()
        reportingTask?.cancel(); reportingTask = nil
        self.playerItems.forEach { $0.player?.stopStream() }
        displayCriteriaTask?.cancel(); displayCriteriaTask = nil
        defaultsTasks.values.forEach { $0.cancel() }; defaultsTasks.removeAll()
        self.setPreferredDisplayCriteria(displayCriteria: nil)
        self.dismiss(animated: true)
    }

    @objc func swipeUpRegognized() {
        guard !self.playerItems.isEmpty else {
            return
        }

        self.showControlStripOverlay()
    }

    @objc func swipeLeftRegognized() {
        self.showChannelSelectorOverlay()
    }

    @objc func selectLongPressed(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            self.showChannelSelectorOverlay()
        }
    }
}

// MARK: - Control Strip Actions
extension PlayerCollectionViewController {

    func enterFullScreenPlayer(id: String) {
        self.reportCurrentPlayTime()

        guard let playerItem = self.playerItems.first(where: { $0.id == id }) else {
            return
        }

        self.fullscreenPlayerId = playerItem.id

        if let player = playerItem.player {
            self.pauseAll(excludeIds: [playerItem.id])

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.services.playerController.openPlayer(player: player, fullscreenPlayerDismissedProtocol: self, isLive: self.isLiveSession)
            }
        }
    }

    func playPausePlayer() {
        self.reportCurrentPlayTime()

        self.playPausePressed()
    }

    func rewindPlayer() {
        liveCoordinator.cancel()
        synchronizationGeneration = UUID()
        self.reportCurrentPlayTime()

        self.rewindAllPlayersBy(seconds: 15)
    }

    func forwardPlayer() {
        liveCoordinator.cancel()
        synchronizationGeneration = UUID()
        self.reportCurrentPlayTime()

        self.forwardAllPlayersBy(seconds: 15)
    }

    func seekPlayersTo(time: Float64) {
        liveCoordinator.cancel()
        synchronizationGeneration = UUID()
        self.seekAllPlayersTo(time: time)
    }
    
    func didFinishSeeking() {
        self.reportCurrentPlayTime()
    }

    func willClosePlayer(id: String) {
        self.reportCurrentPlayTime()

        guard let removedIndex = self.playerItems.firstIndex(where: { $0.id == id }) else {
            return
        }

        let playerItem = self.playerItems[removedIndex]
        entitlementTasks.removeValue(forKey: id)?.cancel(); entitlementGenerations.removeValue(forKey: id)
        playerItem.player?.stopStream()

        liveCoordinator.cancel()
        synchronizationGeneration = UUID()
        readyObservations.removeValue(forKey: id)
        defaultsTasks.removeValue(forKey: id)?.cancel()
        initializedPlayerIDs.remove(id); defaultsAppliedPlayerIDs.remove(id); setupAudio.removeValue(forKey: id)
        self.playerItems.removeAll(where: { $0.id == id })
        startupAnchors.removeValue(forKey: id)
        self.orderChannels()
        if let main = playerItems.first { setPreferredChannelSettings(playerItem: main) }
        refreshPlayerLayout()

    }
}

// MARK: - Main Player Swapping
extension PlayerCollectionViewController {

    func swapMainPlayer(to newIndex: Int) {
        guard newIndex >= 0 && newIndex < self.playerItems.count else { return }
        guard newIndex != 0 else { return } // Already main

        if self.collectionView.collectionViewLayout is PlayerGridLayout {
            liveCoordinator.cancel()
            synchronizationGeneration = UUID()
            let focusedID = self.playerItems[newIndex].id
            // Store reference to players and their settings before swap
            let previousMainPlayer = self.playerItems[0].player
            let newMainPlayer = self.playerItems[newIndex].player
            let previousMainVolume = previousMainPlayer?.volume ?? 1.0

            // Swap the player items in the array
            let temp = self.playerItems[0]
            self.playerItems[0] = self.playerItems[newIndex]
            self.playerItems[newIndex] = temp
            self.orderChannels()

            // Handle audio: unmute and restore volume for new main player, mute and lower volume for previous main (now sidebar)
            newMainPlayer?.isMuted = false
            newMainPlayer?.volume = previousMainVolume  // Use the volume from what was the main player

            previousMainPlayer?.isMuted = true
            previousMainPlayer?.volume = 0.0  // Set volume to 0 to ensure no audio leaks

            print("Swapped main player: unmuted new main (volume: \(newMainPlayer?.volume ?? 0)), muted and silenced sidebar player")

            // Update layout and reload
            refreshPlayerLayout(focusedID: focusedID)

            // Sync all players after swap
            if let mainPlayerItem = self.playerItems.first {
                self.syncAllPlayers(with: mainPlayerItem)
            }
        }
    }

    func swapToMainPlayer(id: String) {
        guard let playerIndex = self.playerItems.firstIndex(where: { $0.id == id }) else { return }
        self.swapMainPlayer(to: playerIndex)
    }
}

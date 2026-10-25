#if canImport(F1Core)
import F1Core
#endif
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
        cancelSynchronization()
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
        stopPlayback()
        self.dismiss(animated: true)
    }

    func stopPlayback() {
        guard !isExitingPlayback else { return }
        transportPreviewSession = nil
        cancelSynchronization()
        readyObservations.removeAll()
        self.reportCurrentPlayTime()
        isExitingPlayback = true
        positionTimer?.invalidate(); positionTimer = nil
        pendingSeekTime = nil

        self.pauseAll()
        entitlementTasks.values.forEach { $0.cancel() }; entitlementTasks.removeAll(); entitlementGenerations.removeAll()
        startupTimeouts.values.forEach { $0.cancel() }; startupTimeouts.removeAll()
        self.playerItems.forEach { $0.thumbnails?.reset(); $0.player?.stopStream() }
        displayCriteriaTask?.cancel(); displayCriteriaTask = nil
        defaultsTasks.values.forEach { $0.cancel() }; defaultsTasks.removeAll()
        self.setPreferredDisplayCriteria(displayCriteria: nil)
        updatePlaybackIdleTimer()
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
        cancelSynchronization()
        self.reportCurrentPlayTime()

        self.rewindAllPlayersBy(seconds: 10)
    }

    func forwardPlayer() {
        cancelSynchronization()
        self.reportCurrentPlayTime()

        self.forwardAllPlayersBy(seconds: 10)
    }

    func seekPlayersTo(time: Float64) {
        cancelSynchronization()
        self.seekAllPlayersTo(time: time)
    }

    func isSeekingPlayer(id: String) -> Bool {
        // Secondary feeds seek after the reference lands. Keep their timeline
        // protected through both phases of the shared seek.
        pendingSeekTime != nil || restoringPlayerIDs.contains(id)
    }
    
    func didFinishSeeking() {
        // Progress is reported after the reference seek finishes.
    }

    func willClosePlayer(id: String) {
        self.reportCurrentPlayTime()

        guard let removedIndex = self.playerItems.firstIndex(where: { $0.id == id }) else {
            return
        }

        let playerItem = self.playerItems[removedIndex]
        startupTimeouts.removeValue(forKey: id)?.cancel()
        entitlementTasks.removeValue(forKey: id)?.cancel(); entitlementGenerations.removeValue(forKey: id)
        playerItem.thumbnails?.reset()
        playerItem.player?.stopStream()

        cancelSynchronization()
        readyObservations.removeValue(forKey: id)
        defaultsTasks.removeValue(forKey: id)?.cancel()
        initializedPlayerIDs.remove(id); defaultsAppliedPlayerIDs.remove(id); setupAudio.removeValue(forKey: id)
        self.playerItems.removeAll(where: { $0.id == id })
        startupAnchors.removeValue(forKey: id)
        self.orderChannels()
        if let main = playerItems.first { setPreferredChannelSettings(playerItem: main) }
        refreshPlayerLayout()
        updatePlaybackIdleTimer()

    }
}

// MARK: - Main Player Swapping
extension PlayerCollectionViewController {

    func swapMainPlayer(to newIndex: Int) {
        guard newIndex >= 0 && newIndex < self.playerItems.count else { return }
        guard newIndex != 0 else { return } // Already main

        if self.collectionView.collectionViewLayout is PlayerGridLayout {
            cancelSynchronization()
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

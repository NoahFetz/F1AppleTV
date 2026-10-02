import UIKit
import AVFoundation

extension PlayerCollectionViewController {
    func showLayoutPicker() {
        let picker = LayoutPickerViewController(selected: layoutChoice, streamCount: playerItems.count) { [weak self] choice in
            guard let self, choice.supports(count: self.playerItems.count) else { return }
            let focused = self.lastFocusedPlayer.flatMap { self.playerItems.indices.contains($0.item) ? self.playerItems[$0.item].id : nil }
            self.layoutChoice = choice
            self.refreshPlayerLayout(focusedID: focused)
        }
        (presentedViewController ?? self).present(picker, animated: true)
    }
    func showSetupPicker() {
        let picker = SetupPickerViewController()
        picker.snapshot = { [weak self] in
            guard let self else { return nil }
            let streams = self.playerItems.compactMap { item -> SavedStream? in
                guard let channel = item.contentItem.channel else { return nil }
                return SavedStream(selection: StreamSelection(channel: channel), volume: item.player?.volume ?? 1, muted: item.player?.isMuted ?? (item.position != 0))
            }
            guard !streams.isEmpty else { return nil }
            return MultiviewSetup(name: "setup_default_name".localizedString + " " + String(MultiviewSetupStore.shared.load().count + 1), layout: self.layoutChoice, streams: streams)
        }
        picker.onLoad = { [weak self] setup in
            guard let self else { return }
            if let overlay = self.presentedViewController { overlay.dismiss(animated: true) { self.applySetup(setup) } }
            else { self.applySetup(setup) }
        }
        (presentedViewController ?? self).present(picker, animated: true)
    }
    func applySetup(_ setup: MultiviewSetup) {
        let resolved = SetupResolver.resolve(setup, channels: channelItems.compactMap(\.channel))
        guard !resolved.channels.isEmpty else { showMissingStreams(); return }
        let anchor = playerItems.first?.player.map(PlaybackPositionSnapshot.init)
        let previous = playerItems
        liveCoordinator.cancel(); synchronizationGeneration = UUID()
        var next = [PlayerItem]()
        for (index, channel) in resolved.channels.enumerated() {
            guard let item = channelItems.first(where: { $0.channel?.id == channel.id }) else { continue }
            var playerItem = previous.first(where: { $0.contentItem.channel?.id == channel.id }) ?? PlayerItem(contentItem: item, position: index)
            playerItem.position = index
            let audio = resolved.audio[index]
            if initializedPlayerIDs.contains(playerItem.id) { playerItem.player?.volume = audio.volume; playerItem.player?.isMuted = audio.muted }
            else { setupAudio[playerItem.id] = audio }
            if let anchor { startupAnchors[playerItem.id] = (anchor, synchronizationGeneration) }
            next.append(playerItem)
        }
        let retained = Set(next.map(\.id))
        for removed in previous where !retained.contains(removed.id) {
            entitlementTasks.removeValue(forKey: removed.id)?.cancel(); entitlementGenerations.removeValue(forKey: removed.id)
            defaultsTasks.removeValue(forKey: removed.id)?.cancel(); readyObservations.removeValue(forKey: removed.id)
            initializedPlayerIDs.remove(removed.id); defaultsAppliedPlayerIDs.remove(removed.id)
            setupAudio.removeValue(forKey: removed.id); startupAnchors.removeValue(forKey: removed.id)
            removed.player?.stopStream()
        }
        playerItems = next; orderChannels(); layoutChoice = setup.layout.afterAdding(count: next.count)
        lastFocusedPlayer = IndexPath(item: 0, section: 0); controlTargetPlayerId = nil
        refreshPlayerLayout()
        for item in next where item.player == nil && entitlementTasks[item.id] == nil {
            guard let channel = item.contentItem.channel else { continue }
            loadStreamEntitlement(playerId: item.id, contentId: channel.target.uri)
        }
        if resolved.missingCount > 0 { showMissingStreams() }
    }
    private func showMissingStreams() {
        UserInteractionHelper.instance.showError(title: "saved_setups".localizedString, message: "setup_missing_streams".localizedString, recordsError: false)
    }
    func goLive() {
        guard isLiveSession, let reference = playerItems.first?.player else { return }
        synchronizationGeneration = UUID(); startupAnchors.removeAll(); wantsPlayback = true
        let ref = AVLiveSeekSession(reference)
        let sessions = playerItems.compactMap(\.player).filter { $0 !== reference }.map(AVLiveSeekSession.init)
        liveCoordinator.jump(reference: ref, sessions: [ref] + sessions)
    }
}

import UIKit
import F1Core

extension PlayerCollectionViewController {
    var transportReference: PlayerItem? {
        if let id = transportPreviewSession?.referenceID ?? pendingSeekReferenceID,
           let item = playerItems.first(where: { $0.id == id && !$0.hasFailed && $0.player?.currentItem?.status == .readyToPlay }) { return item }
        return synchronizationReference
    }

    var transportIsPlaying: Bool { wantsPlayback }

    func beginTransportPreview() -> MultiviewScrubSession? {
        if let session = transportPreviewSession { return session }
        guard let reference = transportReference else { return nil }
        let session = MultiviewScrubSession(id: UUID(), referenceID: reference.id, wasPlaying: wantsPlayback)
        cancelSynchronization()
        transportPreviewSession = session
        pauseAll()
        return session
    }

    func commitTransportPreview(_ session: MultiviewScrubSession, time: Double) {
        guard transportPreviewSession?.id == session.id,
              transportReference?.id == session.referenceID else { return }
        transportPreviewSession = nil
        wantsPlayback = true
        seekPlayersTo(time: time)
    }

    func cancelTransportPreview(_ session: MultiviewScrubSession, restorePlayback: Bool) {
        guard transportPreviewSession?.id == session.id else { return }
        transportPreviewSession = nil
        if restorePlayback && session.wasPlaying && !isExitingPlayback && UIApplication.shared.applicationState == .active { playAll() }
    }

    func audioMixSnapshot() -> [AudioMixStreamState] {
        playerItems.sorted { $0.position < $1.position }.map { item in
            AudioMixStreamState(id: item.id, title: item.contentItem.title ?? "Stream", volume: item.player?.volume ?? 0,
                                isMuted: item.player?.isMuted ?? true,
                                isAvailable: !item.hasFailed && item.player?.currentItem?.status == .readyToPlay)
        }
    }

    func setStreamVolume(id: String, volume: Float) {
        guard volume.isFinite, let item = playerItems.first(where: { $0.id == id && !$0.hasFailed }), let player = item.player else { return }
        player.volume = min(max(volume, 0), 1)
        var settings = CredentialHelper.getPlayerSettings()
        settings.setPreferredVolume(for: item.contentItem.channelType ?? ChannelType(), volume: player.volume)
        CredentialHelper.setPlayerSettings(playerSettings: settings)
    }

    func setStreamMuted(id: String, muted: Bool) {
        guard let item = playerItems.first(where: { $0.id == id && !$0.hasFailed }), let player = item.player else { return }
        player.isMuted = muted
        var settings = CredentialHelper.getPlayerSettings()
        settings.setPreferredMute(for: item.contentItem.channelType ?? ChannelType(), mute: muted)
        CredentialHelper.setPlayerSettings(playerSettings: settings)
    }
}

import UIKit
import F1Core

extension PlayerCollectionViewController {
    func updateNowPlaying() {
        guard !isExitingPlayback, fullscreenPlayerId == nil, viewIfLoaded?.window != nil else { nowPlaying.stop(); return }
        nowPlaying.update(feeds: playerItems, playing: wantsPlayback, live: isLiveSession)
    }
    func handleRemotePlayback(_ action: TVRemotePlaybackAction) {
        guard !isExitingPlayback, fullscreenPlayerId == nil, nowPlaying.ownerID != nil else { return }
        switch action {
        case .play: if !wantsPlayback { playPausePressed() }
        case .pause: if wantsPlayback { playPausePressed() }
        case .toggle: playPausePressed()
        case .skip(let offset):
            guard offset.isFinite, let position = transportReference?.player?.currentTime().seconds, position.isFinite else { return }
            seekPlayersTo(time: position + offset)
        case .seek(let time): if time.isFinite { seekPlayersTo(time: time) }
        }
        updateNowPlaying()
    }
    func bindPlaybackMetadata(player: FairPlayer, feed: PlayerItem) {
        let binding = PlaybackMetadataBinding()
        metadataBindings[feed.id]?.cancel(); metadataBindings[feed.id] = binding
        binding.bind(player: player, metadata: PlaybackMetadata(session: sessionItem ?? feed.contentItem,
                     channel: feed.contentItem.channel, feedTitle: feed.contentItem.title))
    }
}

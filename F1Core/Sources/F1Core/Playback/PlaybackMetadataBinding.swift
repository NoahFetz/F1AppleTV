import Foundation
import ImageIO

/// One binding per presented feed. Shared downloads may outlive a canceled
/// waiter, but they can never publish into a different player or session.
@MainActor public final class PlaybackMetadataBinding {
    private var generation = UUID()
    private var task: Task<Void, Never>?
    public init() {}
    public func bind(player: FairPlayer, metadata: PlaybackMetadata?, cache: PlaybackArtworkCache = .shared) {
        cancel()
        player.playbackMetadata = metadata
        guard let metadata, let request = CatalogArtworkRequest(pictureID: metadata.artworkID,
            size: CGSize(width: 512, height: 288), scale: 1, maximumPixelDimension: 512) else { return }
        let identity = generation
        task = Task { [weak self, weak player] in
            let data = await cache.data(for: request.url)
            guard let self, let player, !Task.isCancelled, self.generation == identity,
                  player.playbackMetadata == metadata, let data,
                  let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else { return }
            var value = metadata; value.artworkData = data
            player.playbackMetadata = value
        }
    }
    public func cancel() { generation = UUID(); task?.cancel(); task = nil }
    deinit { task?.cancel() }
}

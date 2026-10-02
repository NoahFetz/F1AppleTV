import Foundation

// The provider display names depend on the app's localization extension.
// Request provider identifiers and production DTOs are compiled unchanged.
extension String {
    var localizedString: String { self }
}

import AVFoundation

// Session doubles let the production pool's ownership and stale completion rules
// run without entitlements, UI cells, or account credentials.
final class FairPlayer: AVPlayer {}
final class StreamPreviewSession: PreviewPlaybackSession {
    var player: FairPlayer?
    var item: ContentItem?
    var height: Int?
    var completion: ((FairPlayer?) -> Void)?
    var stops = 0
    var lastVisible: Bool?
    weak var lastReference: AVPlayer?
    func start(item: ContentItem, referencePlayer: AVPlayer?, maximumHeight: Int, completion: @escaping (FairPlayer?) -> Void) {
        self.item = item; height = maximumHeight; self.completion = completion
    }
    func finish() { player = FairPlayer(); completion?(player) }
    func synchronize(reference: AVPlayer?, visible: Bool) { lastReference = reference; lastVisible = visible }
    func stop() { stops += 1; player = nil }
}

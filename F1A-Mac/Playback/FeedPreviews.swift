import SwiftUI
import AVFoundation
import F1Core

/// Session-owned warm previews use separate, muted players and independent FairPlay sessions.
@MainActor final class FeedPreviewPool: ObservableObject {
    @Published private(set) var feeds: [String: DesktopFeed] = [:]
    private weak var session: DesktopSession?
    private let linked: LinkedPreviewCoordinator
    private var channels: [PlaybackChannel] = []
    private var pickerChannels: [PlaybackChannel] = []
    private var visible = Set<String>()
    private var picking = false
    private var timer: Timer?
    init(session: DesktopSession) { self.session = session; linked = LinkedPreviewCoordinator(session: session.coordinator) }
    func configure(channels: [PlaybackChannel]) {
        guard !channels.isEmpty else { return }
        let changed = self.channels.map(\.id) != channels.map(\.id)
        if changed { stop(); self.channels = channels }
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    for feed in self.feeds.values where !feed.loading && feed.player.currentItem?.status == .failed { feed.error = "Preview unavailable" }
                    self.linked.tick()
                }
            }
        }
        replenish()
    }
    func beginPicking(channels: [PlaybackChannel]) {
        for id in Array(feeds.keys) where feeds[id]?.error != nil { linked.remove(id); feeds.removeValue(forKey: id)?.stop() }
        picking = true; pickerChannels = channels
        visible = visible.intersection(Set(channels.map(\.id)))
        replenish()
    }
    func endPicking() { picking = false; visible.removeAll(); linked.setVisible([]); replenish() }
    func setVisible(_ id: String, visible isVisible: Bool) {
        if isVisible { visible.insert(id) } else { visible.remove(id) }
        replenish()
    }
    private func replenish() {
        guard let session, !channels.isEmpty else { return }
        let source = picking ? pickerChannels : channels
        let indices = Set(source.indices.filter { visible.contains(source[$0].id) })
        let window = PreviewWindow.indices(visible: indices, count: source.count)
        // Prioritize visible rows, then their immediate neighbours. Idle warm-up is four feeds.
        let order = indices.sorted() + window.subtracting(indices).sorted()
        let candidates = picking && !order.isEmpty ? order.map { source[$0] } : Array(source.prefix(4))
        let wanted = Array(candidates.prefix(6)); let wantedIDs = Set(wanted.map(\.id))
        for id in Array(feeds.keys) where !wantedIDs.contains(id) { linked.remove(id); feeds.removeValue(forKey: id)?.stop() }
        for channel in wanted where feeds[channel.id] == nil {
            let feed = DesktopFeed(channel: channel, live: session.details?.isLive ?? false)
            feed.muted = true; feed.volume = 0; feed.player.reportsPlaybackErrors = false
            feed.player.automaticallyWaitsToMinimizeStalling = false
            feed.player.fairPlayService = session.services.fairPlay
            feed.player.onPlaybackError = { [weak feed] _ in feed?.error = "Preview unavailable"; feed?.loading = false }
            feeds[channel.id] = feed
            feed.loadTask = Task { [weak self, weak feed, weak session] in
                guard let self, let feed, let session else { return }
                do {
                    let main = session.feeds.first { $0.id == channel.id && $0.ready }
                    let entitlement: PlaybackEntitlement
                    if let prepared = main?.player.streamEntitlement { entitlement = prepared }
                    else { entitlement = try await session.entitlement(for: channel) }
                    try Task.checkCancellation(); guard feeds[channel.id] === feed else { return }
                    feed.player.playStream(streamEntitlement: entitlement)
                    feed.player.prepareStream(previewMaximumHeight: 360, cachedManifest: main?.player.previewManifest, cachedBaseURL: main?.player.previewBaseURL, dynamicRange: .sdr) { item in
                        item.preferredForwardBufferDuration = 1
                    }
                    for _ in 0..<400 {
                        try await Task.sleep(nanoseconds: 50_000_000)
                        guard feeds[channel.id] === feed else { throw CancellationError() }
                        if feed.player.currentItem?.status == .failed { throw APIError.invalidPlayback }
                        if feed.player.currentItem?.status == .readyToPlay { break }
                    }
                    try Task.checkCancellation()
                    guard feed.player.currentItem?.status == .readyToPlay else { throw URLError(.timedOut) }
                    feed.loading = false; feed.loadTask = nil; linked.add(feed)
                    linked.setVisible(picking ? visible : [])
                } catch {
                    guard !Task.isCancelled, feeds[channel.id] === feed else { return }
                    recordServiceFailure(error, operation: .preview)
                    feed.loading = false; feed.error = "Preview unavailable"; feed.loadTask = nil
                }
            }
        }
        linked.setVisible(picking ? visible : [])
    }
    func stop() {
        timer?.invalidate(); timer = nil; linked.reset()
        channels.removeAll(); pickerChannels.removeAll(); visible.removeAll(); picking = false
        feeds.values.forEach { $0.stop() }; feeds.removeAll()
    }
    deinit { timer?.invalidate() }
}

struct FeedPreviewThumbnail: View {
    let channel: PlaybackChannel
    let feed: DesktopFeed?
    var body: some View {
        ZStack {
            CatalogArtwork(picture: channel.artwork, size: CGSize(width: 144, height: 81))
            if let feed { PlayingPreview(feed: feed) }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
private struct PlayingPreview: View {
    @ObservedObject var feed: DesktopFeed
    @State private var displayed = false
    var body: some View {
        PreviewVideoSurface(player: feed.player, displayed: $displayed)
            .opacity(displayed && feed.error == nil ? 1 : 0)
            .overlay(alignment: .bottomLeading) {
                if displayed && feed.live && feed.error == nil {
                    Text("LIVE").font(.system(size: 9, weight: .bold)).padding(4).background(.red, in: .rect(cornerRadius: 3)).padding(5)
                }
            }
    }
}
private struct PreviewVideoSurface: NSViewRepresentable {
    let player: AVPlayer
    @Binding var displayed: Bool
    final class VideoView: NSView {
        let video = AVPlayerLayer()
        var observer: NSKeyValueObservation?
        override init(frame: NSRect) { super.init(frame: frame); wantsLayer = true; layer = video; video.videoGravity = .resizeAspectFill }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }
    func makeNSView(context: Context) -> VideoView {
        let view = VideoView(); view.video.player = player
        let binding = $displayed
        view.observer = view.video.observe(\.isReadyForDisplay, options: [.initial, .new]) { layer, _ in
            let ready = layer.isReadyForDisplay
            DispatchQueue.main.async { binding.wrappedValue = ready }
        }
        return view
    }
    func updateNSView(_ view: VideoView, context: Context) { if view.video.player !== player { view.video.player = player } }
    static func dismantleNSView(_ view: VideoView, coordinator: ()) { view.observer?.invalidate(); view.video.player = nil }
}

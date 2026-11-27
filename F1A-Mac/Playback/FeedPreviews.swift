import SwiftUI
import AVFoundation
import F1Core

/// Replay previews share a composite player where available. Individual feeds use muted players.
@MainActor final class FeedPreviewPool: ObservableObject {
    @Published private(set) var feeds: [String: DesktopFeed] = [:]
    @Published private var tileRects: [String: CGRect] = [:]
    private weak var session: DesktopSession?
    private let linked: LinkedPreviewCoordinator
    private var channels: [PlaybackChannel] = []
    private var pickerChannels: [PlaybackChannel] = []
    private var visible = Set<String>()
    private var picking = false
    private var timer: Timer?
    private var visibilityUpdate: Task<Void, Never>?
    private var composite: MacCompositePreview?
    private var compositeTask: Task<Void, Never>?
    private var compositeFailed = false
    private let previewFeeds: PreviewFeedLoader
    private var bundledPreviews = Set<String>()
    init(session: DesktopSession) {
        self.session = session
        linked = LinkedPreviewCoordinator(session: session.coordinator)
        previewFeeds = PreviewFeedLoader { [weak session] id in await session?.previewFeedBundle(contentID: id) }
    }
    func configure(channels: [PlaybackChannel]) {
        guard !channels.isEmpty else { return }
        let changed = self.channels.map(\.id) != channels.map(\.id)
        if changed {
            if !self.channels.isEmpty { stop() }
            self.channels = channels
        }
        if timer == nil {
            let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.recoverFailedPreviews()
                    self.syncPlayback()
                }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        replenish()
    }
    func beginPicking(channels: [PlaybackChannel]) {
        for id in Array(feeds.keys) where feeds[id]?.error != nil { removePreview(id) }
        picking = true; pickerChannels = channels
        visible = visible.intersection(Set(channels.map(\.id)))
        replenish()
    }
    func endPicking() {
        picking = false; pickerChannels.removeAll(); visible.removeAll()
        visibilityUpdate?.cancel(); visibilityUpdate = nil
        stopComposite()
        linked.setVisible([])
        replenish()
    }
    func setVisible(_ id: String, visible isVisible: Bool) {
        let changed = isVisible ? visible.insert(id).inserted : visible.remove(id) != nil
        guard changed, visibilityUpdate == nil else { return }
        // Batch row geometry callbacks before changing the observed preview pool.
        visibilityUpdate = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            visibilityUpdate = nil
            if picking { replenish() }
        }
    }

    func tile(for id: String) -> CompositeTileSurface? {
        guard let composite, let rect = tileRects[id] else { return nil }
        return CompositeTileSurface(preview: composite, rect: rect)
    }

    private func replenish() {
        guard let session, !channels.isEmpty else { return }
        let tryComposite = session.details?.item.contentSubtype == "REPLAY" && !compositeFailed
        if tryComposite && (!picking || composite == nil) {
            for id in Array(feeds.keys) { removePreview(id) }
            if picking, !pickerChannels.isEmpty, compositeTask == nil, let channel = channels.first {
                startComposite(session: session, contentID: channel.contentID)
            }
            return
        }
        let source = picking ? pickerChannels : channels
        let indices = Set(source.indices.filter { visible.contains(source[$0].id) })
        let window = PreviewWindow.indices(visible: indices, count: source.count)
        // Prioritize visible rows, then their immediate neighbours. Idle warm-up is four feeds.
        let order = indices.sorted() + window.subtracting(indices).sorted()
        let candidates = picking && !order.isEmpty ? order.map { source[$0] } : Array(source.prefix(4))
        let selected = candidates.prefix(6)
        var tileRects: [String: CGRect] = [:]
        if let composite {
            for channel in selected { tileRects[channel.id] = composite.rects[channel.id] }
        }
        if self.tileRects != tileRects { self.tileRects = tileRects }
        let wanted = selected.filter { tileRects[$0.id] == nil }
        let wantedIDs = Set(wanted.map(\.id))
        for id in Array(feeds.keys) where !wantedIDs.contains(id) { removePreview(id) }
        for channel in wanted where feeds[channel.id] == nil {
            let feed = DesktopFeed(channel: channel, live: session.details?.isLive ?? false)
            feed.muted = true; feed.volume = 0; feed.player.reportsPlaybackErrors = false
            feed.player.fairPlayService = session.services.fairPlay
            feed.player.onPlaybackError = { [weak feed] error in feed?.preparationError = error }
            feeds[channel.id] = feed
            loadPreview(feed, allowBundle: true)
        }
        linked.setVisible(picking ? visible : [])
    }

    private func startComposite(session: DesktopSession, contentID: String) {
        compositeTask = Task { [weak self, weak session] in
            guard let self, let session else { return }
            let bundle = await previewFeeds.bundle(for: contentID)
            guard !Task.isCancelled else { return }
            guard let bundle, let source = bundle.composite else { fallBackFromComposite(); return }
            var rects: [String: CGRect] = [:]
            for channel in channels {
                if let id = bundle.channelID(for: channel) { rects[channel.id] = source.videoRects[id] }
            }
            guard !rects.isEmpty, let player = CompositePreviewPlayer(source: source) else {
                fallBackFromComposite()
                return
            }
            do {
                try await player.start(at: session.coordinator.capture()?.seconds ?? 0)
                try Task.checkCancellation()
            } catch {
                player.stop()
                if !Task.isCancelled { fallBackFromComposite() }
                return
            }
            compositeTask = nil
            composite = MacCompositePreview(player: player, rects: rects)
            syncComposite()
            replenish()
        }
    }

    func syncPlayback() {
        syncComposite()
        linked.tick()
    }

    private func syncComposite() {
        guard let composite, let timeline = session?.coordinator, let anchor = timeline.capture() else { return }
        let suspended = timeline.isScrubbing || timeline.hasPendingSeek || timeline.participants.contains { $0.changingQuality }
        let rate: Float = timeline.wantsPlayback && !suspended ? timeline.playbackSpeed.rawValue : 0
        if !composite.player.sync(to: anchor.seconds, rate: rate) { fallBackFromComposite() }
    }

    private func fallBackFromComposite() {
        compositeFailed = true
        stopComposite()
        replenish()
    }

    private func stopComposite() {
        compositeTask?.cancel(); compositeTask = nil
        composite?.player.stop(); composite = nil
        if !tileRects.isEmpty { tileRects.removeAll() }
    }

    private func loadPreview(_ feed: DesktopFeed, allowBundle: Bool) {
        feed.loading = true
        feed.loadTask = Task { [weak self, weak feed] in
            guard let self, let feed, let session else { return }
            let channel = feed.channel
            do {
                let cachedPlayer = session.feeds.first { $0.id == channel.id && $0.ready }?.player
                let cached = cachedPlayer?.streamEntitlement
                let usesBundle = try await previewFeeds.prepare(channel: channel, allowBundle: allowBundle, cached: cached,
                                                               individual: { try await session.entitlement(for: channel) }) { entitlement, timeout in
                    guard self.feeds[channel.id] === feed else { throw CancellationError() }
                    feed.preparationError = nil
                    try await feed.player.prepareFeedPreview(entitlement, maximumHeight: session.services.preferences.player.previewHeight,
                                                             timeout: timeout, cachedPlayer: entitlement.url == cached?.url ? cachedPlayer : nil,
                                                             failure: { feed.preparationError })
                }
                try Task.checkCancellation()
                guard feeds[channel.id] === feed else { return }
                if usesBundle { bundledPreviews.insert(channel.id) }
                finishPreview(feed)
            } catch {
                guard !Task.isCancelled, feeds[channel.id] === feed else { return }
                recordServiceFailure(error, operation: .preview)
                feed.loading = false; feed.error = "Preview unavailable"; feed.loadTask = nil
            }
        }
    }

    private func finishPreview(_ feed: DesktopFeed) {
        feed.loading = false; feed.loadTask = nil
        linked.add(feed)
        linked.setVisible(picking ? visible : [])
    }

    private func recoverFailedPreviews() {
        for feed in feeds.values where !feed.loading && feed.error == nil {
            guard feed.preparationError != nil || feed.player.currentItem?.status == .failed else { continue }
            if bundledPreviews.remove(feed.id) != nil {
                linked.remove(feed.id)
                feed.player.stopStream()
                loadPreview(feed, allowBundle: false)
            } else {
                feed.error = "Preview unavailable"
            }
        }
    }

    private func removePreview(_ id: String) {
        bundledPreviews.remove(id)
        linked.remove(id)
        feeds.removeValue(forKey: id)?.stop()
    }

    func stop() {
        timer?.invalidate(); timer = nil; linked.reset()
        visibilityUpdate?.cancel(); visibilityUpdate = nil
        stopComposite(); compositeFailed = false
        previewFeeds.reset()
        bundledPreviews.removeAll()
        channels.removeAll(); pickerChannels.removeAll(); visible.removeAll(); picking = false
        feeds.values.forEach { $0.stop() }; feeds.removeAll()
    }
    deinit {
        timer?.invalidate()
        visibilityUpdate?.cancel()
        compositeTask?.cancel()
    }
}

struct FeedPreviewThumbnail: View {
    let channel: PlaybackChannel
    let feed: DesktopFeed?
    let compositeTile: CompositeTileSurface?
    var body: some View {
        ZStack {
            CatalogArtwork(picture: channel.artwork, size: CGSize(width: 144, height: 81))
            if let compositeTile { compositeTile }
            else if let feed { PlayingPreview(feed: feed) }
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

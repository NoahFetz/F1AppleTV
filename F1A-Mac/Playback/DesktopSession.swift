import SwiftUI
import AppKit
import AVKit
import F1Core

@MainActor final class DesktopFeed: ObservableObject, Identifiable, LinkedPlaybackParticipant {
    let id: String
    let channel: PlaybackChannel
    let player = FairPlayer()
    var refreshPreviewEntitlement: (() async throws -> PlaybackEntitlement)?
    lazy var thumbnails = PlaybackThumbnailProvider(player: player, allowUnprotectedVideoFallback: true, refreshEntitlement: refreshPreviewEntitlement)
    let live: Bool
    @Published var loading = true
    @Published var error: String?
    @Published var currentTime = 0.0
    var position: Double { player.currentTime().seconds }
    @Published var volume: Float = 1 { didSet { player.volume = volume } }
    @Published var alwaysOnTop = false
    @Published var dynamicRange = PlayerDynamicRange.automatic
    @Published var displayName = "Unknown display"
    @Published var displaySupportsHDR = false
    @Published var sourceDynamicRange = "Source range unknown"
    @Published var muted = false { didSet { player.isMuted = muted } }
    @Published var audio: [MediaTrackDto] = []
    @Published var captions: [MediaTrackDto] = []
    @Published var selectedAudio: AVMediaSelectionOption?
    @Published var selectedCaption: AVMediaSelectionOption?
    @Published var revision = 0
    private var tracksItem: AVPlayerItem?
    private var selectionObserver: NSObjectProtocol?
    var audioSelection: Int { audio.firstIndex { $0.option.isEqual(selectedAudio) } ?? -1 }
    var captionSelection: Int { captions.firstIndex { $0.option.isEqual(selectedCaption) } ?? -1 }
    var audioName: String { selectedAudio?.displayName ?? "Stream default" }
    var captionName: String { selectedCaption?.displayName ?? "Off" }
    var loadTask: Task<Void, Never>?
    var preparationError: Error?
    var startup = PlaybackStartup()
    private var resolutionObserver: NSObjectProtocol?
    var ready: Bool { !loading && error == nil && player.currentItem?.status == .readyToPlay }
    // Prefer the higher-resolution HDR source even on SDR displays. AVKit's
    // output policy still follows the display; explicit SDR remains available.
    var streamDynamicRange: StreamDynamicRange { dynamicRange == .sdr ? .sdr : .hdr }
    var streamRangeName: String {
        switch player.effectiveDynamicRange {
        case .sdr: return "SDR stream"
        case .hdr: return "HDR stream"
        case .automatic: return sourceDynamicRange
        }
    }
    func applyDynamicRange() {
        guard !loading, error == nil, player.resolutionStatus == .available || player.resolutionStatus == .switching,
              player.requestedDynamicRange != streamDynamicRange else { return }
        player.selectDynamicRange(streamDynamicRange)
    }
    var buffering: Bool { player.timeControlStatus == .waitingToPlayAtSpecifiedRate }
    var changingQuality: Bool { player.resolutionStatus == .switching }
    var programDate: Date? { player.currentItem?.currentDate() }
    var seekRange: ClosedRange<Double>? {
        guard let item = player.currentItem, item.status == .readyToPlay else { return nil }
        if let range = item.seekableTimeRanges.last?.timeRangeValue {
            let end = CMTimeRangeGetEnd(range).seconds, start = range.start.seconds
            if start.isFinite && end.isFinite && end > start { return start...end }
        }
        let duration = item.duration.seconds
        return duration.isFinite && duration > 0 ? 0...duration : nil
    }
    var title: String {
        channel.kind == .OnBoardCamera ? [channel.driverFirstName, channel.driverLastName].compactMap { $0 }.joined(separator: " ") : channel.title
    }
    init(channel: PlaybackChannel, live: Bool) {
        self.id = channel.id; self.channel = channel; self.live = live
        selectionObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.mediaSelectionDidChangeNotification, object: nil, queue: .main) { [weak self] note in
            guard let item = note.object as? AVPlayerItem else { return }
            Task { @MainActor in
                guard let self, self.player.currentItem === item else { return }; self.updateSelection()
            }
        }
        resolutionObserver = NotificationCenter.default.addObserver(forName: FairPlayer.resolutionDidChange, object: player, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }; self.revision += 1
                await self.refreshTracks()
            }
        }
    }
    func refreshTracks() async {
        guard let item = player.currentItem else { return }
        let newAudio = (try? await item.tracks(type: .audio)) ?? []
        let newCaptions = (try? await item.tracks(type: .subtitle)) ?? []
        let videoTracks = try? await item.asset.loadTracks(withMediaType: .video)
        var sourceHasHDR: Bool?
        if let videoTracks, !videoTracks.isEmpty {
            var characteristics: [AVMediaCharacteristic] = []
            for track in videoTracks {
                guard let values = try? await track.load(.mediaCharacteristics) else { continue }
                characteristics.append(contentsOf: values)
            }
            if !characteristics.isEmpty { sourceHasHDR = characteristics.contains(.containsHDRVideo) }
        }
        guard player.currentItem === item, !Task.isCancelled else { return }
        if let sourceHasHDR {
            sourceDynamicRange = sourceHasHDR ? "HDR source" : "SDR source"
        } else { sourceDynamicRange = "Source range unknown" }
        audio = newAudio; captions = newCaptions; tracksItem = item; updateSelection()
    }
    func updateSelection() {
        guard let item = tracksItem, player.currentItem === item else { return }
        selectedAudio = audio.first.map { item.currentMediaSelection.selectedMediaOption(in: $0.group) } ?? nil
        selectedCaption = captions.first.map { item.currentMediaSelection.selectedMediaOption(in: $0.group) } ?? nil
    }
    func selectAudio(_ index: Int) {
        guard let item = tracksItem, player.currentItem === item else { return }
        if audio.indices.contains(index) { item.select(track: audio[index]) }
        else if let group = audio.first?.group { item.selectMediaOptionAutomatically(in: group) }
        updateSelection()
    }
    func selectCaption(_ index: Int) {
        guard let item = tracksItem, player.currentItem === item else { return }
        if captions.indices.contains(index) { item.select(track: captions[index]) }
        else if let group = captions.first?.group, group.allowsEmptySelection { item.select(nil, in: group) }
        updateSelection()
    }
    func play() { if ready { player.play() } }
    func pause() { player.pause() }
    func cancelSeek() { player.currentItem?.cancelPendingSeeks() }
    func seek(seconds: Double, completion: @escaping (Bool) -> Void) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { result in
            DispatchQueue.main.async { completion(result) }
        }
    }
    func seek(date: Date, completion: @escaping (Bool) -> Void) {
        player.seek(to: date) { result in DispatchQueue.main.async { completion(result) } }
    }
    func stop() {
        startup.cancel(); loadTask?.cancel(); loadTask = nil; thumbnails.reset(); player.onPlaybackError = nil; player.stopStream()
        tracksItem = nil; audio = []; captions = []; selectedAudio = nil; selectedCaption = nil
        sourceDynamicRange = "Source range unknown"
    }
    deinit { loadTask?.cancel(); if let resolutionObserver { NotificationCenter.default.removeObserver(resolutionObserver) }; if let selectionObserver { NotificationCenter.default.removeObserver(selectionObserver) } }
}

@MainActor final class FeedWindowDelegate: NSObject, NSWindowDelegate {
    weak var session: DesktopSession?
    let id: String
    init(session: DesktopSession, id: String) { self.session = session; self.id = id }
    func windowWillClose(_ notification: Notification) { session?.remove(id: id) }
    func windowDidEnterFullScreen(_ notification: Notification) { refreshChrome(notification) }
    func windowDidExitFullScreen(_ notification: Notification) { refreshChrome(notification) }
    private func refreshChrome(_ notification: Notification) {
        guard let window = notification.object as? FeedPlaybackWindow else { return }
        window.setChromeVisible(window.chromeVisible, animated: false)
    }
}

@MainActor final class DesktopSession: ObservableObject {
    @Published var feeds: [DesktopFeed] = []
    @Published var details: VideoDetails?
    @Published var loading = false
    @Published var message: String?
    @Published var feedPickerAnchor: String?
    @Published var savingSetup = false { didSet { if savingSetup { presentUtility(SaveSetupView(session: self), title: "Save Setup") } else { utility?.close(); utility = nil } } }
    @Published var setupName = ""
    @Published var setups: [DesktopSetup] = []
    @Published var playing = true
    let services: MacServices
    let coordinator = LinkedPlaybackCoordinator()
    lazy var previews = FeedPreviewPool(session: self)
    private let setupStore = DesktopSetupStore()
    private var utility: NSWindow?
    private var windows: [String: FeedPlaybackWindow] = [:]
    private var delegates: [String: FeedWindowDelegate] = [:]
    private var requestTask: Task<Void, Never>?
    private var generation = UUID()
    private var suppressClose = false
    private var fromBeginning = false
    private var clockTimer: Timer?
    private var ticks = 0
    #if DEBUG
    private var fixtureURL: URL?
    #endif
    init(services: MacServices) {
        self.services = services; setups = setupStore.load()
        coordinator.onSeekFailure = { [weak self] _ in self?.message = "A feed could not synchronize. Use Sync All to retry." }
        clockTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }
    private func presentUtility<V: View>(_ view: V, title: String) {
        utility?.close()
        let panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 580, height: 520), styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = title; panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: view)
        panel.center(); panel.makeKeyAndOrderFront(nil); utility = panel
    }
    private func poll() {
        for feed in feeds {
            if feed.startup.expired(wantsPlayback: coordinator.wantsPlayback, isPlaying: feed.player.timeControlStatus == .playing),
               let attempt = feed.startup.attempt {
                fail(feed, attempt: attempt, error: URLError(.timedOut))
            }
            let time = feed.player.currentTime().seconds
            if time.isFinite && feed.currentTime != time { feed.currentTime = time }
        }
        ticks += 1
        if ticks % 8 == 0 { coordinator.tick() }
        if playing != coordinator.wantsPlayback { playing = coordinator.wantsPlayback }
    }
    func requestPlayback(_ item: ContentItem) {
        guard item.canPlay else { return }
        if details?.item.contentId == item.contentId { windows.values.first?.makeKeyAndOrderFront(nil); showFeedPicker(); return }
        if !feeds.isEmpty {
            let alert = NSAlert(); alert.messageText = "Replace the current session?"
            alert.informativeText = "The open feed windows will close before the selected video opens."
            alert.addButton(withTitle: "Replace Session"); alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        let loadGeneration = UUID(); generation = loadGeneration; requestTask?.cancel(); loading = true; message = nil
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard let id = item.contentId else { throw APIError.invalidPlayback }
                let video = try await services.playback.video(id)
                try Task.checkCancellation(); guard generation == loadGeneration else { return }
                var beginning = !video.isLive
                if video.isLive {
                    switch services.preferences.player.liveStart {
                    case .beginning: beginning = true
                    case .live: beginning = false
                    case .ask:
                        loading = false
                        let alert = NSAlert(); alert.messageText = "Watch live or from the beginning?"
                        alert.addButton(withTitle: "Watch Live"); alert.addButton(withTitle: "From Beginning"); alert.addButton(withTitle: "Cancel")
                        let choice = alert.runModal()
                        guard choice != .alertThirdButtonReturn else { loading = false; return }
                        beginning = choice == .alertSecondButtonReturn
                    }
                }
                closeAll(preservingRequest: true); details = video; fromBeginning = beginning; loading = false
                if let initial = PlaybackSelection.initialChannel(in: video.channels, preference: services.preferences.player.defaultFeed) { open(initial) }
            } catch {
                guard !Task.isCancelled, generation == loadGeneration else { return }
                recordServiceFailure(error, operation: .video); loading = false; message = "Could not load playback. Sign in and try again."
            }
        }
    }
    func showFeedPicker(anchor: String? = nil) {
        guard details != nil else { return }
        feedPickerAnchor = anchor ?? windows.first(where: { $0.value === NSApp.keyWindow })?.key ?? "catalog"
    }
    func entitlement(for channel: PlaybackChannel) async throws -> PlaybackEntitlement {
        #if DEBUG
        if let fixtureURL { return PlaybackEntitlement(url: fixtureURL.absoluteString, channelID: channel.id, drmType: nil, licenseURL: nil, entitlementToken: "") }
        #endif
        return try await services.playback.entitlement(channel.target)
    }
    func open(_ channel: PlaybackChannel, saved: DesktopSavedFeed? = nil) {
        if let window = windows[channel.id] { window.makeKeyAndOrderFront(nil); return }
        guard let details else { return }
        let first = feeds.isEmpty
        let feed = DesktopFeed(channel: channel, live: details.isLive)
        feed.refreshPreviewEntitlement = { [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.entitlement(for: channel)
        }
        let settings = services.preferences.player
        feed.dynamicRange = services.preferences.dynamicRange
        feed.volume = saved?.stream.volume ?? (first ? settings.getPreferredVolume(for: channel.kind) : 1)
        feed.muted = saved?.stream.muted ?? (first ? settings.getPreferredMute(for: channel.kind) : true)
        feeds.append(feed)
        let window = FeedPlaybackWindow(contentRect: CGRect(x: 0, y: 0, width: 800, height: 450), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.playbackKey = { [weak self, weak feed] key in
            guard let self, let feed else { return }
            switch key {
            case " ": self.togglePlayback()
            case "m": feed.muted.toggle()
            case "\u{f702}": self.coordinator.skip(from: feed.id, seconds: -10)
            case "\u{f703}": self.coordinator.skip(from: feed.id, seconds: 10)
            default: break
            }
        }
        window.title = feed.title; window.isReleasedWhenClosed = false; window.minSize = CGSize(width: 480, height: 270)
        window.configure(player: feed.player)
        window.collectionBehavior = [.fullScreenPrimary]
        window.contentView = NSHostingView(rootView: FeedPlayerView(feed: feed, session: self).preferredColorScheme(.dark))
        let delegate = FeedWindowDelegate(session: self, id: feed.id)
        delegates[feed.id] = delegate; window.delegate = delegate; windows[feed.id] = window
        if let frame = saved?.window {
            let screen = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == frame.displayID } ?? NSScreen.main ?? NSScreen.screens.first
            if let screen { window.setFramePreservingAspect(frame.visibleRect(on: screen.visibleFrame), on: screen.visibleFrame) }
        } else { window.center(); if !first { window.setFrameOrigin(window.frame.origin.applying(CGAffineTransform(translationX: Double(feeds.count - 1) * 28, y: -Double(feeds.count - 1) * 28))) } }
        window.makeKeyAndOrderFront(nil)
        feed.displayName = window.screen?.localizedName ?? "Unknown display"
        feed.displaySupportsHDR = (window.screen?.maximumPotentialExtendedDynamicRangeColorComponentValue ?? 1) > 1
        load(feed, first: first)
    }
    func setAlwaysOnTop(_ feed: DesktopFeed, enabled: Bool) {
        guard let window = windows[feed.id] else { return }
        feed.alwaysOnTop = enabled
        window.setAlwaysOnTop(enabled)
    }
    func load(_ feed: DesktopFeed, first: Bool = false) {
        let priorAnchor = coordinator.capture()
        feed.stop(); coordinator.remove(id: feed.id)
        feed.loading = true; feed.error = nil; feed.preparationError = nil
        feed.player.fairPlayService = services.fairPlay
        let attempt = feed.startup.begin()
        feed.player.onPlaybackError = { [weak self, weak feed] error in
            guard let self, let feed else { return }
            guard feed.startup.accepts(attempt) else { return }
            if feed.loading { feed.preparationError = error }
            else { self.fail(feed, attempt: attempt, error: error) }
        }
        let settings = services.preferences.player
        let begin = fromBeginning
        let fallbackResume = feed.channel.resumePosition
        if let priorAnchor, coordinator.participants.isEmpty { coordinator.restore(priorAnchor) }
        feed.loadTask = Task { [weak self, weak feed] in
            guard let self, let feed else { return }
            var operation = AppErrorOperation.entitlement
            do {
                var accessRetry = PlaybackAccessRetry()
                var preparedItem: AVPlayerItem?
                while preparedItem == nil {
                    do {
                        operation = .entitlement
                        let entitlement = try await entitlement(for: feed.channel)
                        try Task.checkCancellation(); guard feed.startup.accepts(attempt), feeds.contains(where: { $0 === feed }) else { return }
                        operation = .playback
                        feed.preparationError = nil
                        feed.player.playStream(streamEntitlement: entitlement)
                        feed.player.prepareStream(startupMaximumHeight: settings.startupMaximumHeight, dynamicRange: feed.streamDynamicRange) { _ in }
                        for _ in 0..<150 {
                            try await Task.sleep(nanoseconds: 200_000_000)
                            guard feed.startup.accepts(attempt), feeds.contains(where: { $0 === feed }) else { throw CancellationError() }
                            if let item = feed.player.currentItem, item.status == .failed { throw await FairPlayer.playbackFailure(for: item) }
                            if let error = feed.preparationError { throw error }
                            if feed.player.currentItem?.status == .readyToPlay { break }
                        }
                        guard let item = feed.player.currentItem, item.status == .readyToPlay else { throw URLError(.timedOut) }
                        preparedItem = item
                    } catch {
                        try Task.checkCancellation()
                        guard feed.startup.accepts(attempt), feeds.contains(where: { $0 === feed }) else { return }
                        guard accessRetry.consume(error) else { throw error }
                        recordServiceFailure(error, operation: .playback)
                        feed.player.stopStream(); feed.preparationError = nil
                        try await Task.sleep(nanoseconds: 500_000_000)
                    }
                }
                guard let item = preparedItem else { return }
                await PlaybackDefaults.apply(to: item, channel: feed.channel.kind, settings: settings) { [weak self, weak feed] in
                    guard let self, let feed else { return false }; return feed.startup.accepts(attempt) && feeds.contains(where: { $0 === feed }) && feed.player.currentItem === item
                }
                try Task.checkCancellation(); guard feeds.contains(where: { $0 === feed }), feed.player.currentItem === item else { return }
                feed.loading = false
                if first && coordinator.capture() == nil {
                    let target = feed.live ? (begin ? feed.seekRange?.lowerBound : feed.seekRange.map { max($0.lowerBound, $0.upperBound - 3) }) : fallbackResume ?? feed.seekRange?.lowerBound
                    if let target {
                        coordinator.restore(PlaybackAnchor(seconds: target, date: nil,
                            lag: feed.live ? feed.seekRange.map { $0.upperBound - target } : nil,
                            capturedAt: Date(), playing: coordinator.wantsPlayback))
                    }
                }
                try Task.checkCancellation(); guard feed.startup.accepts(attempt), feeds.contains(where: { $0 === feed }) else { return }
                feed.startup.prepared(attempt)
                coordinator.add(feed); feed.applyDynamicRange()
                previews.configure(channels: details?.channels ?? [])
                // Track labels and HDR metadata must not hold up transport startup.
                await feed.refreshTracks()
                if feed.startup.accepts(attempt) { feed.loadTask = nil }
            } catch {
                guard !Task.isCancelled else { return }
                fail(feed, attempt: attempt, error: error, operation: operation)
            }
        }
    }
    private func fail(_ feed: DesktopFeed, attempt: UUID, error: Error, operation: AppErrorOperation = .playback) {
        guard feed.startup.accepts(attempt), feeds.contains(where: { $0 === feed }) else { return }
        recordServiceFailure(error, operation: operation)
        feed.stop(); feed.loading = false
        feed.error = "This feed could not start or continue playback. Please retry."
        message = "\(feed.title) could not play. Retry in its player window."
        coordinator.tick()
    }
    func remove(id: String) {
        guard !suppressClose else { return }
        if feedPickerAnchor == id { feedPickerAnchor = nil }
        feeds.first { $0.id == id }?.stop(); coordinator.remove(id: id)
        feeds.removeAll { $0.id == id }; windows.removeValue(forKey: id); delegates.removeValue(forKey: id)
        if feeds.isEmpty { previews.stop(); details = nil; requestTask?.cancel(); generation = UUID(); loading = false }
    }
    func closeAll(preservingRequest: Bool = false) {
        if !preservingRequest { requestTask?.cancel(); requestTask = nil; generation = UUID(); loading = false }
        feedPickerAnchor = nil; savingSetup = false; previews.stop()
        suppressClose = true
        feeds.forEach { $0.stop() }; coordinator.reset(); windows.values.forEach { $0.close() }
        windows.removeAll(); delegates.removeAll(); feeds.removeAll(); details = nil; suppressClose = false
        #if DEBUG
        fixtureURL = nil
        #endif
    }
    func togglePlayback() { coordinator.setPlaying(!coordinator.wantsPlayback); playing = coordinator.wantsPlayback }
    func saveSetup() {
        let saved = feeds.map { feed in
            let window = windows[feed.id]
            let display = window?.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            return DesktopSavedFeed(stream: SavedStream(selection: StreamSelection(channel: feed.channel), volume: feed.volume, muted: feed.muted), window: window.map { DesktopWindowFrame(rect: $0.frame, displayID: display?.uint32Value) })
        }
        do { try setupStore.save(DesktopSetup(name: setupName, feeds: saved)); setups = setupStore.load(); savingSetup = false; setupName = "" }
        catch { recordServiceFailure(error, operation: .credentials); message = "Could not save this setup." }
    }
    func restore(_ setup: DesktopSetup) {
        guard let current = details else { return }
        let resolved = setup.resolve(channels: current.channels)
        guard !resolved.isEmpty else { message = "None of this setup’s feeds are available in this session."; return }
        let anchor = coordinator.capture()
        #if DEBUG
        let restoringFixture = fixtureURL
        #endif
        closeAll(); details = current; coordinator.restore(anchor)
        #if DEBUG
        fixtureURL = restoringFixture
        #endif
        for (channel, saved) in resolved { open(channel, saved: saved) }
        let skipped = setup.feeds.count - resolved.count
        if skipped > 0 { message = "Skipped \(skipped) unavailable feed(s)." }
    }
    func deleteSetup(_ id: UUID) {
        do { try setupStore.delete(id); setups = setupStore.load() }
        catch { recordServiceFailure(error, operation: .credentials); message = "Could not delete this setup." }
    }
    #if DEBUG
    func promptLocalFixture() {
        let alert = NSAlert(); alert.messageText = "Open Local HLS Fixture"
        let field = NSTextField(string: "http://127.0.0.1:8000/master.m3u8")
        field.frame = CGRect(x: 0, y: 0, width: 360, height: 24); alert.accessoryView = field
        alert.addButton(withTitle: "Open"); alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn, let url = URL(string: field.stringValue),
              ["127.0.0.1", "localhost", "::1"].contains(url.host ?? "") else { return }
        openLocalFixture(url)
    }
    func openLocalFixture(_ url: URL) {
        closeAll(); fixtureURL = url; fromBeginning = true
        var item = ContentItem(); item.id = "local"; item.contentId = "1"; item.title = "Local playback"
        let channels = (0..<3).map { PlaybackChannel(id: "fixture:\($0)", target: PlaybackTarget(uri: "1", requiresVideoDetails: false), kind: .MainFeed, contentID: "1", title: "Local feed \($0 + 1)") }
        details = VideoDetails(item: item, channels: channels)
        channels.forEach { open($0) }
    }
    #endif
    deinit { requestTask?.cancel(); clockTimer?.invalidate() }
}

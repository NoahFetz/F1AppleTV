// Compiled only into the isolated app created by run-tvos-playback-tests.sh.
import UIKit
import AVKit
import F1Core

private struct RegressionCatalog: CatalogService {
    func menu() async throws -> [CatalogMenuEntry] { [] }
    func page(_ destination: CatalogDestination) async throws -> CatalogDocument { throw APIError.invalidPlayback }
}
private struct RegressionAuth: AuthService {
    func account() async throws -> AccountProfile? { nil }
    func prepareLogin(using provider: any LoginChallengeProviding) async throws -> LoginChallenge { throw APIError.authentication }
    func signIn(email: String, password: String, challenge: LoginChallenge) async throws -> AccountProfile { throw APIError.authentication }
    func signOut() async throws {}
}
private struct RegressionFairPlay: FairPlayService {
    func certificate() async throws -> Data { throw APIError.invalidPlayback }
    func license(entitlement: PlaybackEntitlement, spc: Data, assetID: String) async throws -> Data { throw APIError.invalidPlayback }
}
private actor RegressionPlayback: PlaybackService {
    let url: URL
    var requests: [String] = []
    var positions: [Int] = []
    init(url: URL) { self.url = url }
    func video(_ id: String) async throws -> VideoDetails { throw APIError.invalidPlayback }
    func entitlement(_ target: PlaybackTarget) async throws -> PlaybackEntitlement {
        requests.append(target.uri)
        return PlaybackEntitlement(url: url.absoluteString, channelID: target.uri, drmType: nil, licenseURL: nil, entitlementToken: "")
    }
    func report(contentID: String, subtype: String, position: Int, timestamp: Int) async throws { positions.append(position) }
}

private final class RegressionScrubActions: ControlStripActionProtocol {
    var seeking = false
    var target: Double?
    func seekPlayersTo(time: Float64) { target = time; seeking = true }
    func isSeekingPlayer(id: String) -> Bool { seeking }
    func willClosePlayer(id: String) {}
    func enterFullScreenPlayer(id: String) {}
    func playPausePlayer() {}
    func rewindPlayer() {}
    func forwardPlayer() {}
    func didFinishSeeking() {}
    func showChannelSelectorOverlay() {}
    func swapToMainPlayer(id: String) {}
    func showLayoutPicker() {}
    func showSetupPicker() {}
    func goLive() {}
    func restartStreams() {}
}

@MainActor
enum TVPlaybackRegressionHarness {
    static var results: [[String: Any]] = []
    static var stage = "Starting harness"
    static var diagnostics: () -> String = { "" }
    static func check(_ name: String, _ result: Bool) { results.append(["name": name, "passed": result]) }
    static func wait(_ predicate: () -> Bool) async throws {
        for _ in 0..<200 {
            if predicate() { return }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        throw URLError(.timedOut)
    }
    static func content(_ id: String, title: String, kind: ChannelType) -> ContentItem {
        var item = ContentItem()
        item.id = id; item.title = title; item.contentId = "999"; item.contentSubtype = "REPLAY"
        item.channel = PlaybackChannel(id: id, target: PlaybackTarget(uri: id, requiresVideoDetails: false), kind: kind, contentID: "999", title: title)
        return item
    }
    static func player(_ url: URL) async throws -> FairPlayer {
        let player = FairPlayer()
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        try await wait { player.currentItem?.status == .readyToPlay }
        return player
    }
    static func timelineSlider(in view: UIView) -> TvOSSlider? {
        if let slider = view as? TvOSSlider, slider.panSensitivity == 0.25 { return slider }
        return view.subviews.lazy.compactMap { timelineSlider(in: $0) }.first
    }
    static func run(window: UIWindow) async {
        do { try await exercise(window: window) }
        catch { results.append(["name": "\(stage): \(error); \(diagnostics())", "passed": false]) }
        let data = try! JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("results.json")
        try! data.write(to: output)
        print("TV_PLAYBACK_REGRESSIONS_COMPLETE \(results.count)")
    }
    private static func exercise(window: UIWindow) async throws {
        let url = Bundle.main.url(forResource: "fixture", withExtension: "mp4")!
        let playback = RegressionPlayback(url: url)
        let services = AppServices(catalog: RegressionCatalog(), auth: RegressionAuth(), playback: playback, fairPlay: RegressionFairPlay(), language: "ENG")
        let main = content("main", title: "INTERNATIONAL", kind: .MainFeed)
        let live = content("live", title: "F1 LIVE", kind: .AdditionalFeed)
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: ConstantsUtil.playerCollectionViewController) as! PlayerCollectionViewController
        controller.services = services; controller.channelItems = [main, live]
        window.rootViewController = controller; window.makeKeyAndVisible()
        controller.loadViewIfNeeded(); controller.wantsPlayback = false
        stage = "Preparing fixture players"
        let a = try await player(url), b = try await player(url)
        diagnostics = { "feeds=\(controller.playerItems.map { "\($0.contentItem.title ?? ""): time=\($0.player?.currentTime().seconds ?? .nan), status=\($0.player?.currentItem?.status.rawValue ?? -1), failed=\($0.hasFailed)" }), pending=\(String(describing: controller.pendingSeekTime)), restoring=\(controller.restoringPlayerIDs.count)" }
        var first = PlayerItem(contentItem: main, position: 0); first.player = a
        var second = PlayerItem(contentItem: live, position: 1); second.player = b
        controller.playerItems = [first]; controller.initializedPlayerIDs.insert(first.id)
        controller.refreshPlayerLayout()

        // Real native seeks and readiness callbacks exercise the late-join race.
        stage = "Joining during reference seek"
        controller.seekPlayersTo(time: 8)
        controller.playerItems.append(second); controller.refreshPlayerLayout()
        controller.observeReadiness(id: second.id, player: b)
        try await wait { controller.pendingSeekTime == nil && abs(a.currentTime().seconds - 8) < 0.1 && abs(b.currentTime().seconds - 8) < 0.1 }
        check("Feed becoming ready during seek joins the selected time", true)
        check("Paused late join remains paused", a.rate == 0 && b.rate == 0)
        stage = "Superseding seek"
        controller.seekPlayersTo(time: 12); controller.seekPlayersTo(time: 4)
        try await wait { controller.pendingSeekTime == nil && abs(a.currentTime().seconds - 4) < 0.1 && abs(b.currentTime().seconds - 4) < 0.1 }
        check("Superseded seek cannot restore an older position", true)

        stage = "Scrubbing"
        let overlay = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: ConstantsUtil.controlStripOverlayViewController) as! ControlStripOverlayViewController
        overlay.initialize(playerItem: controller.playerItems[0], playerCount: 2, controlStripActionProtocol: controller, isLiveSession: false, onDismiss: {})
        overlay.loadViewIfNeeded(); overlay.updateTimeline()
        let slider = TvOSSlider(); slider.value = 0.5
        let before = a.currentTime().seconds
        overlay.timelineSliderChanged(slider: slider); overlay.updateTimeline()
        check("Scrub adjustment leaves playback unchanged until release", abs(a.currentTime().seconds - before) < 0.1)
        overlay.timelineSeekingFinished()
        try await wait { controller.pendingSeekTime == nil && abs(a.currentTime().seconds - 10) < 0.1 && abs(b.currentTime().seconds - 10) < 0.1 }
        check("Scrub release seeks all feeds once to previewed time", true)

        // Hold seek completion to deterministically exercise periodic updates
        // while AVPlayer still exposes the previous playback position.
        stage = "Timeline while a released seek is pending"
        let delayedActions = RegressionScrubActions()
        let delayedOverlay = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: ConstantsUtil.controlStripOverlayViewController) as! ControlStripOverlayViewController
        delayedOverlay.initialize(playerItem: controller.playerItems[1], playerCount: 2, controlStripActionProtocol: delayedActions, isLiveSession: false, onDismiss: {})
        delayedOverlay.loadViewIfNeeded(); delayedOverlay.updateTimeline()
        let actualSlider = timelineSlider(in: delayedOverlay.view)!
        let playbackValue = actualSlider.value
        actualSlider.value = 0.75
        actualSlider.sendActions(for: .valueChanged)
        actualSlider.sendActions(for: .editingDidEnd)
        delayedOverlay.updateTimeline()
        check("Released scrub thumb stays at its target while the displayed feed seeks", abs(actualSlider.value - 0.75) < 0.001)
        actualSlider.value = 0.6
        actualSlider.sendActions(for: .valueChanged)
        actualSlider.sendActions(for: .editingDidEnd)
        delayedOverlay.updateTimeline()
        check("A second scrub preserves the latest target during an outstanding seek", abs(actualSlider.value - 0.6) < 0.001 && abs((delayedActions.target ?? 0) - 12) < 0.1)
        delayedActions.seeking = false
        delayedOverlay.updateTimeline()
        check("Timeline resumes following playback after the seek completes", abs(actualSlider.value - playbackValue) < 0.001)
        actualSlider.value = 0.8
        actualSlider.sendActions(for: .valueChanged)
        actualSlider.sendActions(for: .editingDidEnd)
        delayedActions.seeking = false
        delayedOverlay.updateTimeline()
        check("A canceled seek releases the held scrub position", abs(actualSlider.value - playbackValue) < 0.001)

        // Two owners simulate custom-player/fullscreen handoff.
        stage = "Playback sleep ownership"
        let owner = NSObject(), fullscreen = NSObject()
        a.preventsDisplaySleepDuringVideoPlayback = false
        PlaybackIdleTimer.shared.setPlayers([a], owner: owner)
        check("Registering playback explicitly restores native sleep prevention", a.preventsDisplaySleepDuringVideoPlayback)
        controller.wantsPlayback = true; a.play()
        try await wait { a.timeControlStatus == .playing && UIApplication.shared.isIdleTimerDisabled }
        check("Playing video keeps the TV awake", true)
        PlaybackIdleTimer.shared.setPlayers([a], owner: fullscreen)
        PlaybackIdleTimer.shared.setPlayers([], owner: owner)
        check("Fullscreen ownership preserves the idle guard", UIApplication.shared.isIdleTimerDisabled)
        a.pause()
        try await wait { !UIApplication.shared.isIdleTimerDisabled }
        check("Pausing all registered video permits idle", true)
        a.play(); try await wait { UIApplication.shared.isIdleTimerDisabled }
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        check("Leaving the foreground releases the idle guard", !UIApplication.shared.isIdleTimerDisabled)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        try await wait { UIApplication.shared.isIdleTimerDisabled }
        PlaybackIdleTimer.shared.setPlayers([], owner: fullscreen)
        check("Removing the last playback owner releases the idle guard", !UIApplication.shared.isIdleTimerDisabled)
        a.pause(); controller.wantsPlayback = false

        // Saving a failed slot stores its semantic selection; loading must retry.
        stage = "Saved layout recovery"
        controller.playerItems[1].hasFailed = true
        let setup = MultiviewSetup(name: "Failure recovery", layout: .grid, streams: [SavedStream(selection: .international, volume: 0.6, muted: false), SavedStream(selection: .f1Live, volume: 0.2, muted: true)])
        controller.applySetup(setup)
        try await wait { controller.playerItems[1].player?.currentItem?.status == .readyToPlay && controller.initializedPlayerIDs.contains(second.id) }
        let requests = await playback.requests
        check("Loading a saved layout retries the failed slot", requests == ["live"] && controller.playerItems[1].player !== b)
        try await wait { abs((controller.playerItems[1].player?.currentTime().seconds ?? 0) - a.currentTime().seconds) < 0.1 }
        check("Recovered layout feed preserves playback time and audio", controller.playerItems[1].player?.isMuted == true && abs((controller.playerItems[1].player?.volume ?? 0) - 0.2) < 0.001)

        stage = "Restarting all feeds"
        controller.restartStreams()
        try await wait { controller.playerItems.allSatisfy { $0.player?.currentItem?.status == .readyToPlay && controller.initializedPlayerIDs.contains($0.id) } }
        try await wait { controller.playerItems.allSatisfy { abs(($0.player?.currentTime().seconds ?? 0) - 10) < 0.1 } }
        check("Restart retains the paused playback position", controller.playerItems.allSatisfy { $0.player?.rate == 0 })
        check("Restart retains saved volume and mute", abs((controller.playerItems[0].player?.volume ?? 0) - 0.6) < 0.001 && controller.playerItems[1].player?.isMuted == true)

        stage = "Failed tile retry"
        controller.streamFailed(id: second.id)
        check("Failed startup leaves an explicit retryable tile", controller.playerItems[1].hasFailed && controller.playerItems[1].player == nil)
        controller.collectionView(controller.collectionView, didSelectItemAt: IndexPath(item: 1, section: 0))
        try await wait { controller.playerItems[1].player?.currentItem?.status == .readyToPlay && !controller.playerItems[1].hasFailed && controller.initializedPlayerIDs.contains(second.id) }
        try await wait { abs((controller.playerItems[1].player?.currentTime().seconds ?? 0) - 10) < 0.1 }
        check("Selecting a failed tile retries at the preserved time", true)

        stage = "Removing picker selection and exiting"
        let picker = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: ConstantsUtil.channelSelectorOverlayViewController) as! ChannelSelectorOverlayViewController
        picker.services = services; picker.initialize(channelItems: [main, live], selectionReturnProtocol: controller)
        picker.activeChannelKeys = [main.previewIdentity, live.previewIdentity]
        picker.loadViewIfNeeded()
        picker.tableView(picker.channelsTableView!, didSelectRowAt: IndexPath(row: 1, section: 0))
        check("Selecting an active picker row removes its feed", controller.playerItems.count == 1 && !picker.activeChannelKeys.contains(live.previewIdentity))
        controller.stopPlayback()
        await controller.progressReporter.flush()
        let positions = await playback.positions
        check("Exiting delivers the final replay position", positions.last == 10)
        check("Exit releases playback idle prevention", !UIApplication.shared.isIdleTimerDisabled)
    }
}

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
    var transportReference: PlayerItem?
    var transportIsPlaying = false
    var session: MultiviewScrubSession?
    var playPauseCount = 0
    func beginTransportPreview() -> MultiviewScrubSession? {
        guard let reference = transportReference else { return nil }
        let session = MultiviewScrubSession(id: UUID(), referenceID: reference.id, wasPlaying: transportIsPlaying)
        self.session = session; transportIsPlaying = false; seeking = false
        return session
    }
    func commitTransportPreview(_ session: MultiviewScrubSession, time: Double) {
        guard self.session?.id == session.id else { return }
        self.session = nil; transportIsPlaying = true
        seekPlayersTo(time: time)
    }
    func cancelTransportPreview(_ session: MultiviewScrubSession, restorePlayback: Bool) {
        self.session = nil
        if restorePlayback { transportIsPlaying = session.wasPlaying }
    }
    func audioMixSnapshot() -> [AudioMixStreamState] { [] }
    func setStreamVolume(id: String, volume: Float) {}
    func setStreamMuted(id: String, muted: Bool) {}
    var seeking = false
    var target: Double?
    func seekPlayersTo(time: Float64) { target = time; seeking = true }
    func isSeekingPlayer(id: String) -> Bool { seeking }
    func willClosePlayer(id: String) {}
    func enterFullScreenPlayer(id: String) {}
    func playPausePlayer() { transportIsPlaying.toggle(); playPauseCount += 1 }
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
    static func timelineSlider(in view: UIView) -> RemoteTimelineControl? {
        if let slider = view as? RemoteTimelineControl { return slider }
        return view.subviews.lazy.compactMap { timelineSlider(in: $0) }.first
    }
    static func run(window: UIWindow) async {
        do { try await exercise(window: window) }
        catch {
            results.append(["name": "\(stage): \(error); \(diagnostics())", "passed": false])
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? Data().write(to: directory.appendingPathComponent("failure-ready"))
            try? await Task.sleep(nanoseconds: 2_500_000_000)
        }
        let data = try! JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("results.json")
        try! data.write(to: output)
        print("TV_PLAYBACK_REGRESSIONS_COMPLETE \(results.count)")
        if ProcessInfo.processInfo.arguments.contains("--interactive-controls") { try? await showInteractiveControls(window: window) }
    }

    private static func showInteractiveControls(window: UIWindow) async throws {
        let url = Bundle.main.url(forResource: "fixture", withExtension: "mp4")!
        let services = AppServices(catalog: RegressionCatalog(), auth: RegressionAuth(), playback: RegressionPlayback(url: url), fairPlay: RegressionFairPlay(), language: "ENG")
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: ConstantsUtil.playerCollectionViewController) as! PlayerCollectionViewController
        controller.services = services
        let main = content("main", title: "INTERNATIONAL", kind: .MainFeed)
        let onboard = content("onboard", title: "Driver onboard commentary", kind: .OnBoardCamera)
        controller.channelItems = [main, onboard]
        window.rootViewController = controller
        controller.loadViewIfNeeded()
        let a = try await player(url), b = try await player(url)
        a.volume = 0.6; b.volume = 0.2; b.isMuted = true
        var first = PlayerItem(contentItem: main, position: 0); first.player = a
        var second = PlayerItem(contentItem: onboard, position: 1); second.player = b
        controller.playerItems = [first, second]
        controller.initializedPlayerIDs = [first.id, second.id]
        controller.defaultsAppliedPlayerIDs = [first.id, second.id]
        controller.pauseAll(); controller.refreshPlayerLayout()
        controller.showControlStripOverlay(for: IndexPath(item: 0, section: 0))
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
        overlay.initialize(playerItem: controller.playerItems[1], playerCount: 2, controlStripActionProtocol: controller, isLiveSession: false, onDismiss: {})
        overlay.loadViewIfNeeded(); overlay.updateTimeline()
        let before = a.currentTime().seconds
        overlay.timelinePan(seconds: 6)
        overlay.updateTimeline()
        check("Preview movement leaves every stream untouched", abs(a.currentTime().seconds - before) < 0.1 && abs(b.currentTime().seconds - before) < 0.1)
        check("Shared timeline binds the synchronization reference instead of the selected tile", overlay.transport.referenceID == first.id)
        check("Preview uses the requested time", abs(overlay.transport.displayTime - 10) < 0.1)
        overlay.playPausePressed()
        try await wait { controller.pendingSeekTime == nil && controller.restoringPlayerIDs.isEmpty && abs(a.currentTime().seconds - 10) < 0.3 && abs(b.currentTime().seconds - 10) < 0.3 }
        check("Confirmation seeks all feeds and resumes playback", controller.wantsPlayback)
        controller.pauseAll()
        overlay.updateTimeline()
        let canceledPosition = a.currentTime().seconds
        overlay.timelinePan(seconds: 3)
        overlay.backPressed()
        check("Back cancels the preview without seeking or unpausing", controller.pendingSeekTime == nil && !controller.wantsPlayback && abs(a.currentTime().seconds - canceledPosition) < 0.1)
        overlay.timelinePan(seconds: 2)
        overlay.viewWillDisappear(false)
        check("Disappearance never commits a preview", controller.pendingSeekTime == nil && controller.transportPreviewSession == nil && abs(a.currentTime().seconds - canceledPosition) < 0.1)

        stage = "Timeline while a confirmed seek is pending"
        let delayedActions = RegressionScrubActions()
        delayedActions.transportReference = controller.playerItems[0]
        let delayedOverlay = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: ConstantsUtil.controlStripOverlayViewController) as! ControlStripOverlayViewController
        delayedOverlay.initialize(playerItem: controller.playerItems[1], playerCount: 2, controlStripActionProtocol: delayedActions, isLiveSession: false, onDismiss: {})
        delayedOverlay.loadViewIfNeeded(); delayedOverlay.updateTimeline()
        let actualSlider = timelineSlider(in: delayedOverlay.view)!
        let playbackValue = actualSlider.value
        delayedOverlay.timelinePan(seconds: 15 - a.currentTime().seconds)
        delayedOverlay.commitTimelinePreview()
        delayedOverlay.updateTimeline()
        check("Confirmed scrub thumb stays at its target during seeking", abs(actualSlider.value - 0.75) < 0.001)
        delayedActions.transportIsPlaying = false
        delayedOverlay.timelinePan(seconds: -3)
        delayedOverlay.commitTimelinePreview()
        delayedOverlay.updateTimeline()
        check("A second scrub preserves the latest target during an outstanding seek", abs(actualSlider.value - 0.6) < 0.001 && abs((delayedActions.target ?? 0) - 12) < 0.1)
        delayedActions.seeking = false
        delayedOverlay.updateTimeline()
        check("Timeline resumes following playback after completion or cancellation", abs(actualSlider.value - playbackValue) < 0.001)
        delayedActions.transportIsPlaying = false
        delayedOverlay.playPausePressed()
        check("Play Pause is delivered once", delayedActions.playPauseCount == 1 && delayedActions.transportIsPlaying)
        delayedOverlay.timelineHold(.backward)
        delayedOverlay.timelinePan(seconds: 1)
        delayedOverlay.cancelTimelinePreview()
        check("Canceling a scan restores its entry playback intent", delayedActions.transportIsPlaying && delayedActions.session == nil)
        delayedActions.transportIsPlaying = false
        delayedOverlay.timelinePan(seconds: 1)
        delayedActions.transportReference = nil
        delayedOverlay.updateTimeline()
        check("Reference removal cancels the preview and disables seeking", delayedActions.session == nil && !actualSlider.isEnabled)

        stage = "Audio mixer and focus"
        controller.pauseAll()
        controller.setStreamVolume(id: first.id, volume: 0.6)
        controller.setStreamVolume(id: second.id, volume: 0.2)
        controller.setStreamMuted(id: second.id, muted: true)
        overlay.modalPresentationStyle = .overCurrentContext
        controller.present(overlay, animated: false)
        try await wait { overlay.view.window != nil }
        overlay.setNeedsFocusUpdate(); overlay.updateFocusIfNeeded()
        try await wait { overlay.playPauseButton?.isFocused == true }
        check("Opening the strip initially focuses Play Pause", true)
        diagnostics = { "focused=\(String(describing: UIFocusSystem.focusSystem(for: overlay.view)?.focusedItem)), timelineEnabled=\(overlay.timelineSlider?.isEnabled ?? false), frame=\(String(describing: overlay.timelineSlider?.frame)), reference=\(String(describing: controller.transportReference?.id))" }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try Data().write(to: directory.appendingPathComponent("controls-ready"))
        try await Task.sleep(nanoseconds: 2_500_000_000)
        stage = "Focusing the timeline"
        overlay.focusControl(overlay.timelineSlider)
        try await wait { overlay.timelineSlider?.isFocused == true }
        stage = "Leaving the timeline"
        overlay.focusControl(overlay.playPauseButton)
        try await wait { overlay.playPauseButton?.isFocused == true }
        check("Timeline does not trap navigation back to the transport buttons", true)
        stage = "Opening the mixer"
        overlay.showAudioMixer()
        try await wait { overlay.presentedViewController is AudioMixerViewController }
        let mixer = overlay.presentedViewController as! AudioMixerViewController
        stage = "Initial mixer focus"
        try await wait { mixer.tableView.visibleCells.contains { ($0 as? AudioMixerRow)?.stream?.id == second.id && $0.isFocused } }
        check("Mixer initially focuses the selected stream", true)
        let row = mixer.tableView.visibleCells.compactMap { $0 as? AudioMixerRow }.first { $0.stream?.id == second.id }!
        row.adjust(.forward)
        check("Volume changes only the selected row in five percent steps", abs(b.volume - 0.25) < 0.001 && abs(a.volume - 0.6) < 0.001)
        check("Volume adjustment preserves mute state", b.isMuted)
        mixer.tableView(mixer.tableView, didSelectRowAt: IndexPath(row: 1, section: 0))
        check("Select toggles mute only for the selected stream", !b.isMuted)
        controller.setStreamVolume(id: second.id, volume: 1)
        mixer.refresh(); row.adjust(.forward)
        check("Mixer clamps the upper volume boundary", b.volume == 1)
        controller.setStreamVolume(id: second.id, volume: 0)
        mixer.refresh(); row.adjust(.backward)
        check("Mixer clamps the lower volume boundary", b.volume == 0)
        let extras = (0..<7).map { AudioMixStreamState(id: "extra-\($0)", title: "Driver \($0): A very long international commentary stream name with additional race information", volume: 0.5, isMuted: true, isAvailable: true) }
        mixer.snapshot = { controller.audioMixSnapshot() + extras }
        mixer.refresh()
        try Data().write(to: directory.appendingPathComponent("mixer-ready"))
        try await Task.sleep(nanoseconds: 2_500_000_000)
        check("Mixer supports a scrollable list with long stream names", mixer.tableView.contentSize.height > mixer.tableView.bounds.height)
        mixer.snapshot = { controller.audioMixSnapshot().filter { $0.id != second.id } }
        mixer.refresh()
        let mixerFocus = UIFocusSystem.focusSystem(for: mixer.view)!
        mixerFocus.updateFocusIfNeeded()
        try await wait { mixer.tableView.visibleCells.contains { ($0 as? AudioMixerRow)?.stream?.id == first.id && $0.isFocused } }
        check("Removing the focused audio row moves focus to a remaining stream", true)
        let dismissal = mixer.onDismiss
        mixer.onDismiss = { check("Mixer dismissal callback is delivered", true); dismissal?() }
        mixer.close()
        stage = "Returning focus from mixer"
        try await wait { overlay.presentedViewController == nil && overlay.audioMixerButton?.isFocused == true }
        check("Closing the mixer restores Audio focus without losing edits", a.volume == 0.6 && b.volume == 0)
        overlay.dismiss(animated: false)
        try await wait { controller.presentedViewController == nil }

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

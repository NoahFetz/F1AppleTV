import AVFoundation
import XCTest
import Combine

private final class KeyRoutingService: FairPlayService, @unchecked Sendable {
    private let lock = NSLock()
    private var attempts = 0
    var certificateAttempts: Int { lock.lock(); defer { lock.unlock() }; return attempts }
    private func countAttempt() { lock.lock(); attempts += 1; lock.unlock() }
    func certificate() async throws -> Data {
        countAttempt()
        // Stop before SPC generation. This fixture has no real certificate or license.
        throw URLError(.cannotDecodeContentData)
    }
    func license(entitlement: PlaybackEntitlement, spc: Data, assetID: String) async throws -> Data {
        XCTFail("Synthetic key-routing check must not exchange a license")
        throw URLError(.cannotDecodeContentData)
    }
}

final class FairPlayerResolutionTests: XCTestCase {
    func testFilteredMasterAllowsCDNReferencesButRejectsLocalFiles() throws {
        let player = try makePlayer()
        defer { player.stopStream() }
        let asset = try XCTUnwrap(player.currentItem?.asset)
        let restrictions = asset.referenceRestrictions
        XCTAssertFalse(restrictions.contains(.forbidLocalReferenceToRemote))
        XCTAssertTrue(restrictions.contains(.forbidRemoteReferenceToLocal))
    }

    func testProtectedPlaylistHandsCustomKeysToNativeSession() throws {
        try checkProtectedKeyRouting(path: "fairplay/master.m3u8")
    }

    func testProtectedNativePlaylistHandsCustomKeysToNativeSession() throws {
        try checkProtectedKeyRouting(path: "fairplay/media.m3u8")
    }

    private func checkProtectedKeyRouting(path: String) throws {
        guard let base = ProcessInfo.processInfo.environment["F1_RESOLUTION_FIXTURE_URL"] else {
            throw XCTSkip("Local fixture server required")
        }
        let service = KeyRoutingService()
        let player = FairPlayer()
        defer { player.stopStream() }
        player.reportsPlaybackErrors = false
        player.fairPlayService = service
        player.playStream(streamEntitlement: PlaybackEntitlement(url: base + "/" + path, channelID: "fixture", drmType: "fairplay", licenseURL: "https://license.example/fixture", entitlementToken: "fixture"))
        let prepared = expectation(description: "Protected fixture prepared")
        player.prepareStream { _ in prepared.fulfill() }
        wait(for: [prepared], timeout: 12)
        player.isMuted = true
        player.play()
        let routed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in service.certificateAttempts > 0 }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [routed], timeout: 8), .completed, "Custom key URLs must reach AVContentKeySession before certificate loading")
    }

    private func makePlayer(path: String = "master.m3u8", maximumHeight: Int? = nil) throws -> FairPlayer {
        guard let base = ProcessInfo.processInfo.environment["F1_RESOLUTION_FIXTURE_URL"] else {
            throw XCTSkip("Run Tests/run-resolution-tests.sh --playback to generate local HLS fixtures.")
        }
        let player = FairPlayer()
        player.playStream(streamEntitlement: PlaybackEntitlement(url: base + "/" + path, channelID: "fixture", drmType: nil, licenseURL: nil, entitlementToken: "fixture"))
        let prepared = expectation(description: "Stream prepared")
        player.prepareStream(startupMaximumHeight: maximumHeight) { _ in prepared.fulfill() }
        wait(for: [prepared], timeout: 12)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in player.currentItem?.status == .readyToPlay }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 12), .completed, "\(String(describing: player.currentItem?.error))")
        return player
    }

    private func waitForSwitch(_ player: FairPlayer) {
        let switched = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in player.resolutionStatus == .available }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [switched], timeout: 25), .completed)
    }

    func testRangeSwitchFallbackPreservesPausedPositionAndAudio() throws {
        let player = try makePlayer(maximumHeight: 90)
        defer { player.stopStream() }
        let seeked = expectation(description: "Seek before range switch")
        player.seek(to: CMTime(seconds: 5, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { _ in seeked.fulfill() }
        wait(for: [seeked], timeout: 5)
        player.volume = 0.25; player.isMuted = true
        player.selectDynamicRange(.hdr)
        waitForSwitch(player)
        XCTAssertNil(player.resolutionError)
        XCTAssertEqual(player.selectedDynamicRange, .hdr)
        XCTAssertEqual(player.effectiveDynamicRange, .sdr, "SDR-only fixture must fall back without pretending to supply HDR")
        XCTAssertEqual(player.selectedResolution?.height, 90)
        XCTAssertEqual(player.currentTime().seconds, 5, accuracy: 0.15)
        XCTAssertEqual(player.rate, 0)
        XCTAssertEqual(player.volume, 0.25)
        XCTAssertTrue(player.isMuted)
        player.selectDynamicRange(.sdr)
        player.selectDynamicRange(.automatic)
        player.cancelResolutionSwitch()
        let settled = expectation(description: "Allow stale range tasks to complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 1)
        XCTAssertEqual(player.selectedDynamicRange, .hdr, "Cancellation must keep the committed range")
        XCTAssertEqual(player.requestedDynamicRange, .hdr)
        XCTAssertEqual(player.currentTime().seconds, 5, accuracy: 0.15)
        XCTAssertEqual(player.rate, 0)
    }

    func testHighestDefaultAndFixedSwitchPreservePausedPositionAndAudio() throws {
        let player = try makePlayer(path: "redirect.m3u8")
        defer { player.stopStream() }
        XCTAssertEqual(player.availableResolutions.map { $0.height }, [180, 90])
        XCTAssertEqual(player.currentItem?.presentationSize.height, 180)
        let seeked = expectation(description: "Seek complete")
        player.seek(to: CMTime(seconds: 5, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { _ in seeked.fulfill() }
        wait(for: [seeked], timeout: 5)
        player.volume = 0.25
        player.isMuted = true
        player.selectResolution(StreamResolution(attribute: "160x90"))
        waitForSwitch(player)
        XCTAssertNil(player.resolutionError)
        XCTAssertEqual(player.selectedResolution?.height, 90)
        XCTAssertEqual(player.currentItem?.presentationSize.height, 90)
        XCTAssertEqual(player.currentTime().seconds, 5, accuracy: 0.15)
        XCTAssertEqual(player.rate, 0)
        XCTAssertEqual(player.volume, 0.25)
        XCTAssertTrue(player.isMuted)
        player.selectResolution(nil)
        waitForSwitch(player)
        XCTAssertNil(player.selectedResolution)
        XCTAssertEqual(player.currentItem?.presentationSize.height, 180)
    }

    func testPlayingSwitchResumesAndAccountsForElapsedTime() throws {
        let player = try makePlayer()
        defer { player.stopStream() }
        player.isMuted = true
        player.play()
        let before = player.currentTime().seconds
        player.selectResolution(StreamResolution(attribute: "160x90"))
        waitForSwitch(player)
        XCTAssertNil(player.resolutionError)
        XCTAssertEqual(player.rate, 1)
        XCTAssertGreaterThanOrEqual(player.currentTime().seconds, before)
        XCTAssertEqual(player.currentItem?.presentationSize.height, 90)
    }

    func testFailedSwitchRestoresOriginalItemAndChoice() throws {
        let player = try makePlayer(path: "broken/master.m3u8")
        defer { player.stopStream() }
        let original = player.currentItem
        player.selectResolution(StreamResolution(attribute: "160x90"))
        waitForSwitch(player)
        XCTAssertTrue(player.currentItem === original)
        XCTAssertNil(player.selectedResolution)
        XCTAssertNotNil(player.resolutionError)
    }

    func testRapidSwitchAndClosingCannotCommitStaleItem() throws {
        let player = try makePlayer()
        player.selectResolution(StreamResolution(attribute: "160x90"))
        player.selectResolution(StreamResolution(attribute: "320x180"))
        waitForSwitch(player)
        XCTAssertEqual(player.selectedResolution?.height, 180)
        XCTAssertEqual(player.currentItem?.presentationSize.height, 180)
        player.selectResolution(StreamResolution(attribute: "160x90"))
        player.stopStream()
        let drained = expectation(description: "Pending callbacks drained")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { drained.fulfill() }
        wait(for: [drained], timeout: 2)
        XCTAssertNil(player.currentItem)
        XCTAssertEqual(player.rate, 0)
        XCTAssertEqual(player.selectedResolution?.height, 180)
    }

    func testMediaPlaylistWithoutMetadataStillPlays() throws {
        let player = try makePlayer(path: "variant0.m3u8")
        defer { player.stopStream() }
        XCTAssertEqual(player.resolutionStatus, .unavailable)
        XCTAssertTrue(player.availableResolutions.isEmpty)
        XCTAssertEqual(player.currentItem?.presentationSize.height, 180)
    }

    func testChoicesAreIndependentPerStream() throws {
        let first = try makePlayer()
        let second = try makePlayer()
        defer { first.stopStream(); second.stopStream() }
        let secondItem = second.currentItem
        first.selectResolution(StreamResolution(attribute: "160x90"))
        waitForSwitch(first)
        XCTAssertEqual(first.currentItem?.presentationSize.height, 90)
        XCTAssertTrue(second.currentItem === secondItem)
        XCTAssertNil(second.selectedResolution)
        XCTAssertEqual(second.currentItem?.presentationSize.height, 180)
    }

    func testFullscreenCancellationCannotResumeAfterDismissal() throws {
        let player = try makePlayer()
        defer { player.stopStream() }
        let original = player.currentItem
        player.isMuted = true
        player.play()
        player.selectResolution(StreamResolution(attribute: "160x90"))
        player.cancelResolutionSwitch()
        let drained = expectation(description: "Cancelled seek completion drained")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { drained.fulfill() }
        wait(for: [drained], timeout: 2)
        XCTAssertTrue(player.currentItem === original)
        XCTAssertNil(player.selectedResolution)
        XCTAssertEqual(player.rate, 0)
    }

    func testCloseDuringDiscoveryCannotCreatePlaybackItem() throws {
        guard let base = ProcessInfo.processInfo.environment["F1_RESOLUTION_FIXTURE_URL"] else {
            throw XCTSkip("Local fixture server required")
        }
        let player = FairPlayer()
        player.playStream(streamEntitlement: PlaybackEntitlement(url: base + "/master.m3u8", channelID: "fixture", drmType: nil, licenseURL: nil, entitlementToken: "fixture"))
        let obsoleteCompletion = expectation(description: "Obsolete preparation must not finish")
        obsoleteCompletion.isInverted = true
        player.prepareStream { _ in obsoleteCompletion.fulfill() }
        player.stopStream()
        wait(for: [obsoleteCompletion], timeout: 0.5)
        XCTAssertNil(player.currentItem)
    }

    func testLiveSwitchPreservesDistanceFromLiveEdge() throws {
        let player = try makePlayer(path: "live/master.m3u8")
        defer { player.stopStream() }
        let range = try XCTUnwrap(player.currentItem?.seekableTimeRanges.last?.timeRangeValue)
        XCTAssertFalse(player.currentItem!.duration.seconds.isFinite)
        let seeked = expectation(description: "Seek behind live edge")
        player.seek(to: CMTime(seconds: CMTimeRangeGetEnd(range).seconds - 6, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { _ in seeked.fulfill() }
        wait(for: [seeked], timeout: 5)
        player.isMuted = true
        player.play()
        player.selectResolution(StreamResolution(attribute: "160x90"))
        waitForSwitch(player)
        XCTAssertNil(player.resolutionError)
        XCTAssertEqual(player.currentItem?.presentationSize.height, 90)
        let newRange = try XCTUnwrap(player.currentItem?.seekableTimeRanges.last?.timeRangeValue)
        XCTAssertEqual(CMTimeRangeGetEnd(newRange).seconds - player.currentTime().seconds, 6, accuracy: 1.5)
    }

    func testStartupCapAndMissingMetadataUsePlaybackFallback() throws {
        let capped = try makePlayer(maximumHeight: 100)
        defer { capped.stopStream() }
        XCTAssertEqual(capped.selectedResolution?.height, 90)
        XCTAssertEqual(capped.currentItem?.presentationSize.height, 90)
        let native = try makePlayer(path: "no-resolution-master.m3u8", maximumHeight: 100)
        defer { native.stopStream() }
        XCTAssertTrue(native.availableResolutions.isEmpty)
        XCTAssertEqual(native.resolutionStatus, .unavailable)
        XCTAssertNil(native.selectedResolution)
        XCTAssertEqual(native.currentItem?.status, .readyToPlay)
    }

    func testPreviewUsesLowerResolutionWithoutChangingNormalDefault() throws {
        guard let base = ProcessInfo.processInfo.environment["F1_RESOLUTION_FIXTURE_URL"] else {
            throw XCTSkip("Local fixture server required")
        }
        let preview = FairPlayer()
        defer { preview.stopStream() }
        preview.playStream(streamEntitlement: PlaybackEntitlement(url: base + "/master.m3u8", channelID: "fixture", drmType: nil, licenseURL: nil, entitlementToken: "fixture"))
        let prepared = expectation(description: "Preview prepared")
        preview.prepareStream(previewMaximumHeight: 100) { _ in prepared.fulfill() }
        wait(for: [prepared], timeout: 12)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in preview.currentItem?.status == .readyToPlay }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 12), .completed)
        XCTAssertEqual(preview.currentItem?.presentationSize.height, 90)
        XCTAssertNotNil(preview.previewManifest)
        XCTAssertNotNil(preview.previewBaseURL)
        let normal = try makePlayer()
        defer { normal.stopStream() }
        XCTAssertNil(normal.selectedResolution)
        XCTAssertEqual(normal.currentItem?.presentationSize.height, 180)
    }
    private func checkMedia(_ operation: @escaping @MainActor () async throws -> Void) {
        let finished = expectation(description: "Media selection loaded")
        Task { @MainActor in
            do { try await operation() }
            catch { XCTFail("Media selection failed: \(error)") }
            finished.fulfill()
        }
        wait(for: [finished], timeout: 8)
    }

    func testAsynchronousTrackSelectionSurvivesResolutionSwitchAndCaptionsOff() throws {
        let player = try makePlayer(path: "tracks/master.m3u8")
        defer { player.stopStream() }
        let item = try XCTUnwrap(player.currentItem)
        checkMedia {
            let tracks = try await item.tracks(type: .subtitle)
            XCTAssertEqual(Set(tracks.compactMap { $0.option.extendedLanguageTag }), ["en", "de"])
            let german = try XCTUnwrap(tracks.first { $0.option.extendedLanguageTag == "de" })
            item.select(track: german)
        }
        player.selectResolution(StreamResolution(attribute: "160x90"))
        waitForSwitch(player)
        checkMedia {
            let current = try XCTUnwrap(player.currentItem)
            let loaded = try await current.asset.loadMediaSelectionGroup(for: .legible)
            let group = try XCTUnwrap(loaded)
            XCTAssertEqual(current.currentMediaSelection.selectedMediaOption(in: group)?.extendedLanguageTag, "de")
            current.select(nil, in: group)
        }
        player.selectResolution(nil)
        waitForSwitch(player)
        checkMedia {
            let current = try XCTUnwrap(player.currentItem)
            let loaded = try await current.asset.loadMediaSelectionGroup(for: .legible)
            let group = try XCTUnwrap(loaded)
            XCTAssertNil(current.currentMediaSelection.selectedMediaOption(in: group))
        }
    }

    func testAsynchronousDefaultsRespectUnavailableLanguageAndStaleOwnership() throws {
        let player = try makePlayer(path: "tracks/master.m3u8")
        defer { player.stopStream() }
        let item = try XCTUnwrap(player.currentItem)
        checkMedia {
            let loaded = try await item.asset.loadMediaSelectionGroup(for: .legible)
            let group = try XCTUnwrap(loaded)
            var settings = PlayerSettings()
            settings.captionDefaults[0] = "de"
            await PlaybackDefaults.apply(to: item, channel: .MainFeed, settings: settings) { true }
            XCTAssertEqual(item.currentMediaSelection.selectedMediaOption(in: group)?.extendedLanguageTag, "de")
            settings.captionDefaults[0] = "off"
            await PlaybackDefaults.apply(to: item, channel: .MainFeed, settings: settings) { false }
            XCTAssertEqual(item.currentMediaSelection.selectedMediaOption(in: group)?.extendedLanguageTag, "de")
            await PlaybackDefaults.apply(to: item, channel: .MainFeed, settings: settings) { true }
            XCTAssertNil(item.currentMediaSelection.selectedMediaOption(in: group))
            // Give automatic selection a deterministic target, independent of system settings.
            player.setMediaSelectionCriteria(AVPlayerMediaSelectionCriteria(preferredLanguages: ["en"], preferredMediaCharacteristics: nil), forMediaCharacteristic: .legible)
            let german = try XCTUnwrap(group.options.first { $0.extendedLanguageTag == "de" })
            item.select(german, in: group)
            settings.captionDefaults[0] = "zz"
            await PlaybackDefaults.apply(to: item, channel: .MainFeed, settings: settings) { true }
            player.isMuted = true
            player.play()
            for _ in 0..<50 where item.currentMediaSelection.selectedMediaOption(in: group)?.extendedLanguageTag != "en" {
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTAssertEqual(item.currentMediaSelection.selectedMediaOption(in: group)?.extendedLanguageTag, "en", "An unavailable preference must restore the player's automatic language choice")
        }
    }

    func testCachedPreviewManifestAvoidsMasterRequestAndUsesLowerResolution() throws {
        let main = try makePlayer()
        let preview = FairPlayer()
        defer { main.stopStream(); preview.stopStream() }
        // This master URL is deliberately unreachable; only cached rendition URLs can succeed.
        preview.playStream(streamEntitlement: PlaybackEntitlement(url: "http://127.0.0.1:1/missing.m3u8", channelID: "preview", drmType: nil, licenseURL: nil, entitlementToken: "fixture"))
        let prepared = expectation(description: "Cached preview prepared")
        preview.prepareStream(previewMaximumHeight: 90, cachedManifest: main.previewManifest, cachedBaseURL: main.previewBaseURL) { _ in prepared.fulfill() }
        wait(for: [prepared], timeout: 5)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in preview.currentItem?.status == .readyToPlay }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        XCTAssertEqual(preview.currentItem?.presentationSize.height, 90)
        XCTAssertEqual(preview.currentItem?.preferredMaximumResolution.height, 90)
        XCTAssertEqual(main.currentItem?.presentationSize.height, 180)
    }
    func testClosingCachedPreviewBeforePreparationRejectsStaleCompletion() throws {
        let main = try makePlayer(), preview = FairPlayer()
        defer { main.stopStream(); preview.stopStream() }
        preview.playStream(streamEntitlement: try XCTUnwrap(main.streamEntitlement))
        let stale = expectation(description: "Closed cached preview must not finish")
        stale.isInverted = true
        preview.prepareStream(previewMaximumHeight: 90, cachedManifest: main.previewManifest, cachedBaseURL: main.previewBaseURL) { _ in stale.fulfill() }
        preview.stopStream()
        wait(for: [stale], timeout: 0.5)
        XCTAssertNil(preview.currentItem)
    }

    func testScrubImageRenditionDoesNotSeekOrStartTheMainFeed() throws {
        let player = try makePlayer(path: "images/master.m3u8")
        let provider = MainActor.assumeIsolated { PlaybackThumbnailProvider(player: player) }
        defer { MainActor.assumeIsolated { provider.reset() }; player.stopStream() }
        let before = player.currentTime().seconds
        let image = expectation(description: "Scrub image loaded")
        MainActor.assumeIsolated {
            provider.request(at: 20) {
                XCTAssertEqual($0?.width, 160); XCTAssertEqual($0?.height, 90); image.fulfill()
            }
        }
        wait(for: [image], timeout: 10)
        XCTAssertEqual(player.currentTime().seconds, before, accuracy: 0.05)
        XCTAssertEqual(player.rate, 0)
    }

    func testNativeIFrameScrubbingCoalescesTargetsAndLeavesMainPlaybackUntouched() throws {
        let player = try makePlayer(path: "iframes/master.m3u8")
        let provider = MainActor.assumeIsolated { PlaybackThumbnailProvider(player: player) }
        defer { MainActor.assumeIsolated { provider.reset() }; player.stopStream() }
        let before = player.currentTime().seconds
        let ready = expectation(description: "Latest scrub target displayed")
        var layer: AVPlayerLayer?
        MainActor.assumeIsolated {
            // Simulate continuous pointer movement while the native asset prepares.
            for second in 1...20 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(second) * 0.01) {
                    MainActor.assumeIsolated {
                        provider.requestPreview(at: Double(second)) { result in
                            XCTAssertEqual(second, 20, "Superseded completions must not update the scrub UI")
                            guard case .video(let rendered) = result else { XCTFail("Expected a native I-frame surface"); ready.fulfill(); return }
                            layer = rendered
                            XCTAssertTrue(rendered.isReadyForDisplay)
                            XCTAssertEqual(rendered.player?.rate, 0)
                            XCTAssertTrue(rendered.player?.isMuted == true)
                            XCTAssertEqual(rendered.player?.volume, 0)
                            XCTAssertEqual(rendered.player?.currentTime().seconds ?? -1, 20, accuracy: 2.1)
                            XCTAssertEqual(rendered.player?.currentItem?.presentationSize.height, 90)
                            ready.fulfill()
                        }
                    }
                }
            }
        }
        wait(for: [ready], timeout: 15)
        XCTAssertEqual(player.currentTime().seconds, before, accuracy: 0.05)
        XCTAssertEqual(player.rate, 0)
        MainActor.assumeIsolated { provider.reset() }
        XCTAssertNil(layer?.player, "Reset must release the independent player and key session")
    }

    func testCancelledScrubCannotDeliverStaleCompletionAndCanRestart() throws {
        let player = try makePlayer(path: "iframes/master.m3u8")
        let provider = MainActor.assumeIsolated { PlaybackThumbnailProvider(player: player) }
        defer { MainActor.assumeIsolated { provider.reset() }; player.stopStream() }
        let stale = expectation(description: "Cancelled scrub completion")
        stale.isInverted = true
        let ready = expectation(description: "Reopened scrub surface")
        MainActor.assumeIsolated {
            provider.requestPreview(at: 4) { _ in stale.fulfill() }
            provider.cancel()
            provider.requestPreview(at: 18) { result in
                guard case .video(let layer) = result else { XCTFail("Expected native preview after cancellation"); ready.fulfill(); return }
                XCTAssertEqual(layer.player?.currentTime().seconds ?? -1, 18, accuracy: 2.1)
                ready.fulfill()
            }
        }
        wait(for: [ready], timeout: 15)
        wait(for: [stale], timeout: 0.25)
    }

    func testMacHoverExitLetsFirstFrameFinishAndReusesItsRenderer() throws {
        let player = try makePlayer(path: "iframes/master.m3u8")
        let provider = MainActor.assumeIsolated { PlaybackThumbnailProvider(player: player) }
        let model = MainActor.assumeIsolated { ScrubPreviewModel(provider: provider) }
        defer { MainActor.assumeIsolated { model.reset() }; player.stopStream() }
        let before = player.currentTime().seconds
        let hiddenFrame = expectation(description: "First frame finishes after pointer exit")
        let movedFrame = expectation(description: "Re-entry follows the latest pointer target")
        var surface: AVPlayerLayer?
        var observation: AnyCancellable?
        MainActor.assumeIsolated {
            observation = provider.$nativePreviewState.sink { state in
                switch state {
                case .loading(let layer) where surface == nil:
                    surface = layer
                    // @Published delivers in willSet; let all subscribers apply
                    // the state before simulating an independent pointer event.
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated {
                            XCTAssertTrue(model.loading)
                            model.hide()
                            guard case .video(let mounted) = model.preview else {
                                XCTFail("Hover exit must retain the preparing renderer"); return
                            }
                            XCTAssertTrue(mounted === layer)
                            XCTAssertTrue(model.loading, "Presentation changes must not cancel first-frame preparation")
                        }
                    }
                case .ready(let layer):
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated {
                            XCTAssertTrue(layer === surface)
                            XCTAssertFalse(model.loading)
                            if abs((layer.player?.currentTime().seconds ?? -1) - 18) < 2.1 {
                                movedFrame.fulfill()
                            } else {
                                hiddenFrame.fulfill()
                            }
                        }
                    }
                default: break
                }
            }
            model.request(4)
        }
        wait(for: [hiddenFrame], timeout: 15)
        MainActor.assumeIsolated { model.request(18) }
        wait(for: [movedFrame], timeout: 12)
        observation?.cancel()
        MainActor.assumeIsolated { model.reset() }
        XCTAssertNil(surface?.player)
        XCTAssertEqual(player.currentTime().seconds, before, accuracy: 0.05)
        XCTAssertEqual(player.rate, 0)
    }

    func testMacRejectedPreviewEndsLoadingAndOnlyRetriesOnReentry() throws {
        let player = try makePlayer(path: "preview-rejection/master.m3u8")
        let provider = MainActor.assumeIsolated { PlaybackThumbnailProvider(player: player) }
        let model = MainActor.assumeIsolated { ScrubPreviewModel(provider: provider) }
        defer { MainActor.assumeIsolated { model.reset() }; player.stopStream() }
        let failed = expectation(description: "Rejection ends the Mac loading state")
        var surface: AVPlayerLayer?
        var observation: AnyCancellable?
        MainActor.assumeIsolated {
            observation = provider.$nativePreviewState.sink { state in
                if case .loading(let layer) = state { surface = layer }
                if case .unavailable = state { failed.fulfill() }
            }
            model.request(4)
        }
        wait(for: [failed], timeout: 15)
        let rejectedSurface = try XCTUnwrap(surface)
        observation?.cancel()
        MainActor.assumeIsolated {
            XCTAssertFalse(model.loading)
            XCTAssertNil(model.preview)
            model.request(18)
            XCTAssertFalse(model.loading)
            guard case .unavailable = provider.nativePreviewState else { return XCTFail("Movement must not retry rejected assets") }
            model.hide()
        }
        let reopened = expectation(description: "Next hover can retry")
        MainActor.assumeIsolated {
            observation = provider.$nativePreviewState.sink { state in
                if case .loading(let layer) = state {
                    XCTAssertFalse(layer === rejectedSurface)
                    reopened.fulfill()
                }
            }
            model.request(18)
        }
        wait(for: [reopened], timeout: 2)
        observation?.cancel()
        MainActor.assumeIsolated { model.reset() }
        let settled = expectation(description: "Reset cannot resurrect a hidden preview")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            MainActor.assumeIsolated {
                XCTAssertFalse(model.loading)
                XCTAssertNil(model.preview)
                XCTAssertNil(provider.nativePreviewSurface)
            }
            settled.fulfill()
        }
        wait(for: [settled], timeout: 2)
    }

    func testNativeSurfaceAppearsEvenWhenItsTimestampRequestIsSuperseded() throws {
        let player = try makePlayer(path: "iframes/master.m3u8")
        let provider = MainActor.assumeIsolated { PlaybackThumbnailProvider(player: player) }
        defer { MainActor.assumeIsolated { provider.reset() }; player.stopStream() }
        let stale = expectation(description: "Superseded timestamp completion")
        stale.isInverted = true
        let ready = expectation(description: "Latest target after renderer becomes available")
        var surface: AVPlayerLayer?
        var observation: AnyCancellable?
        let host = CALayer()
        var loadingSeen = false
        MainActor.assumeIsolated {
            observation = provider.$nativePreviewState.sink { state in
                if case .loading(let layer) = state {
                    loadingSeen = true
                    host.addSublayer(layer)
                }
                guard case .ready(let layer) = state, surface == nil else { return }
                surface = layer
                XCTAssertTrue(loadingSeen, "The UI must receive the rendering layer before readiness")
                XCTAssertTrue(layer.superlayer === host)
                XCTAssertTrue(layer.isReadyForDisplay)
                // Movement arrives as the first frame becomes ready. Its renderer
                // must be usable even though that request's callback is suppressed.
                provider.requestPreview(at: 22) { result in
                    guard case .video(let latest) = result else { XCTFail("Expected native preview"); ready.fulfill(); return }
                    XCTAssertTrue(latest === surface)
                    XCTAssertEqual(latest.player?.currentTime().seconds ?? -1, 22, accuracy: 2.1)
                    ready.fulfill()
                }
            }
            provider.requestPreview(at: 4) { _ in stale.fulfill() }
        }
        wait(for: [ready], timeout: 15)
        wait(for: [stale], timeout: 0.1)
        XCTAssertNotNil(surface)
        observation?.cancel()
    }

    func testFailedNativePreviewLeavesLoadingAndDoesNotRetryUntilReopened() throws {
        let player = try makePlayer(path: "preview-rejection/master.m3u8")
        let provider = MainActor.assumeIsolated { PlaybackThumbnailProvider(player: player) }
        defer { MainActor.assumeIsolated { provider.reset() }; player.stopStream() }
        let before = player.currentTime().seconds
        let started = Date()
        let failed = expectation(description: "Rejected preview finished")
        var loadingSeen = false
        let observation = MainActor.assumeIsolated {
            provider.$nativePreviewState.sink { state in
                if case .loading = state { loadingSeen = true }
            }
        }
        MainActor.assumeIsolated {
            provider.requestPreview(at: 4) { result in
                XCTAssertNil(result)
                guard case .unavailable = provider.nativePreviewState else { XCTFail("Failure must end loading"); failed.fulfill(); return }
                XCTAssertNil(provider.nativePreviewSurface)
                failed.fulfill()
            }
        }
        wait(for: [failed], timeout: 15)
        XCTAssertTrue(loadingSeen)
        XCTAssertTrue(AppErrorStore.shared.records().contains { $0.operation == .preview && $0.httpStatus == 403 && $0.lastTimestamp >= started })
        MainActor.assumeIsolated {
            var completed = false
            provider.requestPreview(at: 18) { result in XCTAssertNil(result); completed = true }
            XCTAssertTrue(completed, "Continued mouse movement must not restart a rejected preview")
            provider.suspend()
            guard case .idle = provider.nativePreviewState else { return XCTFail("Reopening must allow another attempt") }
        }
        XCTAssertEqual(player.currentTime().seconds, before, accuracy: 0.05)
        XCTAssertEqual(player.rate, 0)
        observation.cancel()
    }

    func testPreview403RefreshesAccessOnceWithoutReplacingTheMainFeed() throws {
        let player = try makePlayer(path: "preview-rejection/master.m3u8")
        let base = try XCTUnwrap(ProcessInfo.processInfo.environment["F1_RESOLUTION_FIXTURE_URL"])
        let mainItem = player.currentItem
        let mainEntitlement = player.streamEntitlement?.url
        let before = player.currentTime().seconds
        var attempts = 0
        let provider = MainActor.assumeIsolated {
            PlaybackThumbnailProvider(player: player, refreshEntitlement: {
                attempts += 1
                return PlaybackEntitlement(url: base + "/iframes/master.m3u8", channelID: "fixture", drmType: nil, licenseURL: nil, entitlementToken: "")
            })
        }
        defer { MainActor.assumeIsolated { provider.reset() }; player.stopStream() }
        let ready = expectation(description: "Preview recovered with independent fresh access")
        MainActor.assumeIsolated {
            provider.requestPreview(at: 18) { result in
                guard case .video(let layer) = result else { XCTFail("Expected recovered preview"); ready.fulfill(); return }
                XCTAssertTrue(layer.isReadyForDisplay)
                XCTAssertEqual(layer.player?.currentTime().seconds ?? -1, 18, accuracy: 2.1)
                ready.fulfill()
            }
        }
        wait(for: [ready], timeout: 25)
        XCTAssertEqual(attempts, 1)
        XCTAssertTrue(player.currentItem === mainItem)
        XCTAssertEqual(player.streamEntitlement?.url, mainEntitlement)
        XCTAssertEqual(player.currentTime().seconds, before, accuracy: 0.05)
        XCTAssertEqual(player.rate, 0)
    }

    func testPreview403RefreshIsBoundedWhenFreshAccessIsAlsoRejected() throws {
        let player = try makePlayer(path: "preview-rejection/master.m3u8")
        let original = try XCTUnwrap(player.streamEntitlement)
        var attempts = 0
        let provider = MainActor.assumeIsolated {
            PlaybackThumbnailProvider(player: player, refreshEntitlement: { attempts += 1; return original })
        }
        defer { MainActor.assumeIsolated { provider.reset() }; player.stopStream() }
        let failed = expectation(description: "Second rejection ends preview loading")
        MainActor.assumeIsolated {
            provider.requestPreview(at: 4) { result in
                XCTAssertNil(result)
                guard case .unavailable = provider.nativePreviewState else { XCTFail("Expected final unavailable state"); failed.fulfill(); return }
                failed.fulfill()
            }
        }
        wait(for: [failed], timeout: 30)
        XCTAssertEqual(attempts, 1)
    }

    func testSuspendedNativePreviewReusesPlayerAndReleasesAfterIdle() throws {
        let player = try makePlayer(path: "iframes/master.m3u8")
        let provider = MainActor.assumeIsolated { PlaybackThumbnailProvider(player: player) }
        defer { MainActor.assumeIsolated { provider.reset() }; player.stopStream() }
        let before = player.currentTime().seconds
        let first = expectation(description: "First native preview")
        var surface: AVPlayerLayer?
        MainActor.assumeIsolated {
            provider.requestPreview(at: 4) { result in
                guard case .video(let layer) = result else { XCTFail("Expected native preview"); first.fulfill(); return }
                surface = layer; first.fulfill()
            }
        }
        wait(for: [first], timeout: 15)
        let retained = try XCTUnwrap(surface)
        let previewPlayer = try XCTUnwrap(retained.player)
        let reopened = expectation(description: "Reopened warm preview")
        MainActor.assumeIsolated {
            provider.suspend(releaseAfter: .milliseconds(80))
            XCTAssertNil(provider.nativePreviewSurface, "Hiding must detach the published surface")
            XCTAssertTrue(retained.player === previewPlayer, "Brief hover exits must retain the player/key owner")
            provider.requestPreview(at: 18) { result in
                guard case .video(let layer) = result else { XCTFail("Expected reopened native preview"); reopened.fulfill(); return }
                XCTAssertTrue(layer === retained)
                XCTAssertTrue(layer.player === previewPlayer)
                XCTAssertEqual(layer.player?.currentTime().seconds ?? -1, 18, accuracy: 2.1)
                reopened.fulfill()
            }
        }
        wait(for: [reopened], timeout: 15)
        let active = expectation(description: "Old idle timer cancelled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            XCTAssertTrue(retained.player === previewPlayer)
            XCTAssertEqual(previewPlayer.rate, 0)
            XCTAssertTrue(previewPlayer.isMuted)
            active.fulfill()
        }
        wait(for: [active], timeout: 2)
        MainActor.assumeIsolated { provider.suspend(releaseAfter: .milliseconds(40)) }
        let released = expectation(description: "Idle player released")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            MainActor.assumeIsolated {
                XCTAssertNil(retained.player)
                XCTAssertNil(previewPlayer.currentItem)
                XCTAssertNil(provider.nativePreviewSurface)
            }
            released.fulfill()
        }
        wait(for: [released], timeout: 2)
        XCTAssertEqual(player.currentTime().seconds, before, accuracy: 0.05)
        XCTAssertEqual(player.rate, 0)
    }

    func testNativeScrubStaysPausedForTheFeedLifetimeUntilReset() throws {
        let player = try makePlayer(path: "iframes/master.m3u8")
        let provider = MainActor.assumeIsolated { PlaybackThumbnailProvider(player: player) }
        defer { MainActor.assumeIsolated { provider.reset() }; player.stopStream() }
        let before = player.currentTime().seconds
        let ready = expectation(description: "Initial preview")
        var surface: AVPlayerLayer?
        MainActor.assumeIsolated {
            provider.requestPreview(at: 4) { result in
                if case .video(let layer) = result { surface = layer }
                ready.fulfill()
            }
        }
        wait(for: [ready], timeout: 15)
        let layer = try XCTUnwrap(surface)
        let previewPlayer = try XCTUnwrap(layer.player)
        MainActor.assumeIsolated { provider.suspend() }
        // Regress the previous 15-second expiry: the default now belongs to the
        // playback session, even when controls remain hidden for longer.
        let retained = expectation(description: "Retained beyond the former idle timeout")
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.2) {
            MainActor.assumeIsolated {
                XCTAssertTrue(layer.player === previewPlayer)
                XCTAssertNotNil(previewPlayer.currentItem)
                XCTAssertEqual(previewPlayer.rate, 0)
                XCTAssertTrue(previewPlayer.isMuted)
                XCTAssertNil(provider.nativePreviewSurface)
            }
            retained.fulfill()
        }
        wait(for: [retained], timeout: 17)
        let reopened = expectation(description: "Same renderer after reopening")
        MainActor.assumeIsolated {
            provider.requestPreview(at: 18) { result in
                guard case .video(let nextLayer) = result else { XCTFail("Expected reused preview"); reopened.fulfill(); return }
                XCTAssertTrue(nextLayer === layer)
                XCTAssertTrue(nextLayer.player === previewPlayer)
                reopened.fulfill()
            }
        }
        wait(for: [reopened], timeout: 12)
        MainActor.assumeIsolated { provider.reset() }
        XCTAssertNil(layer.player)
        XCTAssertNil(previewPlayer.currentItem)
        XCTAssertEqual(player.currentTime().seconds, before, accuracy: 0.05)
        XCTAssertEqual(player.rate, 0)
    }

    func testNativeScrubProgramDateMatchesMainFeedAfterSeeking() throws {
        let player = try makePlayer(path: "dated/master.m3u8")
        let provider = MainActor.assumeIsolated { PlaybackThumbnailProvider(player: player) }
        defer { MainActor.assumeIsolated { provider.reset() }; player.stopStream() }
        let positioned = expectation(description: "Main feed positioned")
        player.seek(to: CMTime(seconds: 7, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { _ in positioned.fulfill() }
        wait(for: [positioned], timeout: 5)
        let date = try XCTUnwrap(player.currentItem?.currentDate())
        let ready = expectation(description: "Date-aligned scrub surface")
        MainActor.assumeIsolated {
            provider.requestPreview(at: 20) { result in
                guard case .video(let layer) = result, let previewDate = layer.player?.currentItem?.currentDate() else {
                    XCTFail("Expected a dated native preview"); ready.fulfill(); return
                }
                XCTAssertEqual(previewDate.timeIntervalSince(date), 13, accuracy: 2.1)
                ready.fulfill()
            }
        }
        wait(for: [ready], timeout: 15)
        XCTAssertEqual(player.currentTime().seconds, 7, accuracy: 0.1)
        XCTAssertEqual(player.rate, 0)
    }

    @MainActor func testNativeCDN403IsPreservedInsteadOfGenericFilePermissionError() async throws {
        guard let base = ProcessInfo.processInfo.environment["F1_RESOLUTION_FIXTURE_URL"] else { throw XCTSkip("Local fixture server required") }
        let player = FairPlayer()
        defer { player.stopStream() }
        player.reportsPlaybackErrors = false
        player.playStream(streamEntitlement: PlaybackEntitlement(url: base + "/cdn-rejection/master.m3u8", channelID: "fixture", drmType: nil, licenseURL: nil, entitlementToken: ""))
        player.prepareStream { _ in }
        player.play()
        for _ in 0..<100 {
            if player.currentItem?.status == .failed { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let item = try XCTUnwrap(player.currentItem)
        XCTAssertEqual(item.status, .failed)
        let error = await FairPlayer.playbackFailure(for: item)
        XCTAssertEqual(AppErrorStore.httpStatus(for: error), 403)
        XCTAssertEqual(error.domain, NSURLErrorDomain)
        XCTAssertEqual(error.code, -1102)
        XCTAssertEqual((error.userInfo[NSUnderlyingErrorKey] as? NSError)?.code, -12660)
    }

}

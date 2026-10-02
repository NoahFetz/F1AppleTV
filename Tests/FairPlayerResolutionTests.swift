import AVFoundation
import XCTest

final class FairPlayerResolutionTests: XCTestCase {
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
            settings.captionDefaults[0] = "zz"
            await PlaybackDefaults.apply(to: item, channel: .MainFeed, settings: settings) { true }
            XCTAssertTrue(item.currentMediaSelection.mediaSelectionCriteriaCanBeAppliedAutomatically(to: group))
        }
    }

}

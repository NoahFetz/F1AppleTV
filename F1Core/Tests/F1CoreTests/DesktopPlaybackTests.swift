import XCTest
@testable import F1Core

@MainActor private final class TestFeed: LinkedPlaybackParticipant {
    let id: String
    var ready = true, buffering = false, changingQuality = false, live = false
    var position: Double = 20
    var programDate: Date?
    var seekRange: ClosedRange<Double>? = 0...120
    var playing = false
    var plays = 0, cancels = 0
    var seeks: [Double] = []
    var dates: [Date] = []
    var deferred = false
    var dateSucceeds = true
    var completions: [(Bool) -> Void] = []
    init(_ id: String) { self.id = id }
    func play() { playing = true; plays += 1 }
    func pause() { playing = false }
    func cancelSeek() { cancels += 1 }
    func seek(seconds: Double, completion: @escaping (Bool) -> Void) {
        seeks.append(seconds)
        if deferred { completions.append { [weak self] result in if result { self?.position = seconds }; completion(result) } }
        else { position = seconds; completion(true) }
    }
    func seek(date: Date, completion: @escaping (Bool) -> Void) {
        dates.append(date)
        if dateSucceeds { programDate = date }
        completion(dateSucceeds)
    }
}

final class DesktopPlaybackTests: XCTestCase {
    @MainActor func testFirstLiveFeedStartsBeforeSeekRangeAppears() async {
        let session = LinkedPlaybackCoordinator(), feed = TestFeed("live")
        feed.live = true; feed.seekRange = nil
        session.add(feed)
        XCTAssertTrue(feed.playing); XCTAssertTrue(feed.seeks.isEmpty)
        feed.seekRange = 0...120; session.tick()
        XCTAssertFalse(feed.seeks.isEmpty); XCTAssertTrue(feed.playing)
    }
    @MainActor func testPausedFeedWithoutRangeDoesNotStart() async {
        let session = LinkedPlaybackCoordinator(), feed = TestFeed("live")
        session.setPlaying(false); feed.seekRange = nil; session.add(feed)
        XCTAssertFalse(feed.playing)
    }
    @MainActor func testLateJoinUsesReferencePosition() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a"), b = TestFeed("b")
        session.add(a); a.position = 45; b.position = 0; session.add(b)
        XCTAssertEqual(b.position, 45); XCTAssertTrue(b.playing)
    }
    @MainActor func testPauseAndResumeAffectEveryFeed() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a"), b = TestFeed("b")
        session.add(a); session.add(b); session.setPlaying(false)
        XCTAssertFalse(a.playing); XCTAssertFalse(b.playing)
        session.setPlaying(true); XCTAssertTrue(a.playing); XCTAssertTrue(b.playing)
    }
    @MainActor func testSeekFromSecondaryMovesWholeSession() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a"), b = TestFeed("b")
        session.add(a); session.add(b); session.seek(from: "b", seconds: 55)
        XCTAssertEqual(a.position, 55); XCTAssertEqual(b.position, 55)
        XCTAssertEqual(session.reference?.id, "a")
    }
    @MainActor func testPausedLateJoinDoesNotStartPlayback() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a"), b = TestFeed("b")
        session.add(a); session.setPlaying(false); a.position = 35; session.add(b)
        XCTAssertEqual(b.position, 35); XCTAssertFalse(b.playing)
    }
    @MainActor func testDriftThresholdAndScrubbing() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a"), b = TestFeed("b")
        session.add(a); session.add(b); b.seeks = []; b.position = 20.4; session.tick()
        XCTAssertTrue(b.seeks.isEmpty)
        b.position = 18; session.isScrubbing = true; session.tick(); XCTAssertTrue(b.seeks.isEmpty)
        session.isScrubbing = false; session.tick(); XCTAssertEqual(b.position, 20)
    }
    @MainActor func testQualitySwitchSuppressesCorrections() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a"), b = TestFeed("b")
        session.add(a); session.add(b); b.seeks = []; b.position = 12; b.changingQuality = true
        session.tick(); XCTAssertTrue(b.seeks.isEmpty)
        b.changingQuality = false; session.tick(); XCTAssertEqual(b.position, 20)
    }
    @MainActor func testBufferingFeedRejoinsWhenReady() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a"), b = TestFeed("b")
        session.add(a); session.add(b); b.buffering = true; b.position = 5; session.tick()
        XCTAssertEqual(b.position, 5)
        b.buffering = false; session.tick(); XCTAssertEqual(b.position, 20)
    }
    @MainActor func testReferenceRemovalPromotesReadyFeed() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a"), b = TestFeed("b")
        session.add(a); session.add(b); session.remove(id: "a")
        XCTAssertEqual(session.reference?.id, "b"); XCTAssertTrue(b.playing)
    }
    @MainActor func testFailedReferencePromotesReadyFeed() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a"), b = TestFeed("b")
        session.add(a); session.add(b); a.ready = false
        XCTAssertEqual(session.reference?.id, "b")
    }
    @MainActor func testClosedFeedIgnoresStaleSeekCompletion() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a"), b = TestFeed("b")
        session.add(a); session.add(b); b.deferred = true; session.seek(from: "a", seconds: 30)
        session.remove(id: "b"); b.pause(); b.completions[0](true)
        XCTAssertFalse(b.playing)
    }
    @MainActor func testReplacingSessionIgnoresStaleCompletion() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a")
        session.add(a); a.deferred = true; session.seek(from: "a", seconds: 30); session.reset()
        a.completions[0](true); XCTAssertFalse(a.playing); XCTAssertTrue(session.participants.isEmpty)
    }
    @MainActor func testRetriedFeedIgnoresItsPreviousSeekCompletion() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a"), b = TestFeed("b")
        session.add(a); session.add(b); b.deferred = true
        session.seek(from: "a", seconds: 30)
        let previous = b.completions[0]
        session.remove(id: "b"); b.pause(); session.add(b)
        XCTAssertTrue(session.hasPendingSeek)
        previous(true)
        XCTAssertFalse(b.playing); XCTAssertTrue(session.hasPendingSeek)
        b.completions[1](true)
        XCTAssertTrue(b.playing); XCTAssertFalse(session.hasPendingSeek)
    }
    @MainActor func testSupersedingSeekDoesNotResumeOldCommand() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a")
        session.add(a); a.deferred = true; session.seek(from: "a", seconds: 30); session.setPlaying(false)
        a.completions[0](true); XCTAssertFalse(a.playing)
    }
    @MainActor func testGoLiveUsesRelativeLagAcrossDifferentWindows() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a"), b = TestFeed("b")
        a.live = true; a.seekRange = 0...100; b.live = true; b.seekRange = 20...200
        session.add(a); session.add(b); session.goLive(from: "a")
        XCTAssertEqual(100 - a.position, 200 - b.position, accuracy: 0.01)
        XCTAssertLessThan(100 - a.position, 5)
    }
    @MainActor func testProgramDateIsPreferredToPosition() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a"), b = TestFeed("b")
        a.programDate = Date(timeIntervalSince1970: 1000); b.programDate = Date(timeIntervalSince1970: 990)
        session.add(a); session.add(b)
        XCTAssertEqual(b.dates.last, a.programDate)
    }
    @MainActor func testFailedDateSeekFallsBackToClampedSeconds() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a"), b = TestFeed("b")
        a.programDate = Date(timeIntervalSince1970: 1000); b.programDate = Date(timeIntervalSince1970: 995); b.dateSucceeds = false
        session.add(a); session.add(b)
        XCTAssertEqual(b.seeks.last, 25)
    }
    @MainActor func testSeekClampsEachAvailableRange() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a"), b = TestFeed("b")
        session.add(a); session.add(b); b.seekRange = 0...40; session.seek(from: "a", seconds: 90)
        XCTAssertEqual(a.position, 90); XCTAssertEqual(b.position, 39.9, accuracy: 0.01)
    }
    @MainActor func testRestoringSetupKeepsPausedAnchor() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a")
        session.restore(PlaybackAnchor(seconds: 50, date: nil, lag: nil, capturedAt: Date(), playing: false)); session.add(a)
        XCTAssertEqual(a.position, 50); XCTAssertFalse(a.playing)
    }
    @MainActor func testUnreadyFeedJoinsAfterPreparation() async {
        let session = LinkedPlaybackCoordinator(clock: { Date(timeIntervalSince1970: 2000) }), a = TestFeed("a"), b = TestFeed("b")
        session.add(a); b.ready = false; session.add(b); a.position = 32
        b.ready = true; session.tick(); XCTAssertEqual(b.position, 32)
    }
    @MainActor func testPendingSeekTimesOutAndStaleCallbackCannotResume() async {
        var now = Date(timeIntervalSince1970: 2000)
        let session = LinkedPlaybackCoordinator(clock: { now }), a = TestFeed("a")
        session.add(a); a.deferred = true; session.seek(from: "a", seconds: 40)
        let old = a.completions[0]
        a.ready = false; now = now.addingTimeInterval(21); session.tick()
        XCTAssertFalse(session.hasPendingSeek)
        old(true); XCTAssertFalse(a.playing)
    }
    @MainActor func testRestoredPlayingAnchorAdvancesWhileFeedLoads() async {
        let now = Date(timeIntervalSince1970: 2000)
        let session = LinkedPlaybackCoordinator(clock: { now }), a = TestFeed("a")
        session.restore(PlaybackAnchor(seconds: 40, date: nil, lag: nil, capturedAt: now.addingTimeInterval(-5), playing: true))
        session.add(a); XCTAssertEqual(a.position, 45)
    }
    func testWindowRestoreClampsOffscreenGeometry() {
        let screen = CGRect(x: 100, y: 100, width: 1200, height: 800)
        let frame = DesktopWindowFrame(rect: CGRect(x: -3000, y: 8000, width: 600, height: 400), displayID: 1)
        XCTAssertTrue(screen.contains(frame.visibleRect(on: screen)))
    }
    func testInvalidWindowGeometryGetsVisibleDefault() {
        let screen = CGRect(x: 0, y: 0, width: 800, height: 600)
        let frame = DesktopWindowFrame(rect: CGRect(x: CGFloat.infinity, y: 0, width: -1, height: CGFloat.nan), displayID: nil)
        let result = frame.visibleRect(on: screen)
        XCTAssertTrue(screen.contains(result)); XCTAssertTrue(result.width.isFinite)
    }
    func testSetupSkipsMissingFeedAndProtectsDriverIdentity() {
        let channel = PlaybackChannel(id: "new", target: PlaybackTarget(uri: "1", requiresVideoDetails: false), kind: .OnBoardCamera, contentID: "1", title: "New driver", racingNumber: 7, driverFirstName: "New", driverLastName: "Driver")
        let setup = DesktopSetup(name: "Saved", feeds: [DesktopSavedFeed(stream: SavedStream(selection: .driver(number: 7, name: "old driver"), volume: 1, muted: false), window: nil)])
        XCTAssertTrue(setup.resolve(channels: [channel]).isEmpty)
    }
    @MainActor func testDesktopSetupsRemainIndependentFromTVStorage() async throws {
        let suite = "DesktopSetupTests.\(UUID())", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("existing tv setup".utf8), forKey: "MultiviewSetups.v1")
        let store = DesktopSetupStore(defaults: defaults)
        let setup = DesktopSetup(name: suite, feeds: [DesktopSavedFeed(stream: SavedStream(selection: .international, volume: 0.3, muted: true), window: nil)])
        try store.save(setup); XCTAssertEqual(store.load(), [setup])
        XCTAssertEqual(defaults.data(forKey: "MultiviewSetups.v1"), Data("existing tv setup".utf8))
        try store.delete(setup.id); XCTAssertTrue(store.load().isEmpty)
    }
}

final class LinkedPreviewTests: XCTestCase {
    @MainActor private func fixture() -> (LinkedPlaybackCoordinator, LinkedPreviewCoordinator, TestFeed, TestFeed) {
        let now = { Date(timeIntervalSince1970: 2000) }
        let main = LinkedPlaybackCoordinator(clock: now), reference = TestFeed("main"), preview = TestFeed("preview")
        main.add(reference)
        return (main, LinkedPreviewCoordinator(session: main, clock: now), reference, preview)
    }
    @MainActor func testWarmHiddenPreviewAlignsImmediatelyOnShowAndReopen() async {
        let (main, previews, reference, preview) = fixture()
        preview.position = 0; previews.add(preview)
        XCTAssertTrue(preview.seeks.isEmpty); XCTAssertFalse(preview.playing)
        reference.position = 45; previews.setVisible([preview.id])
        XCTAssertEqual(preview.position, 45); XCTAssertTrue(preview.playing)
        previews.setVisible([]); XCTAssertFalse(preview.playing)
        main.setPlaying(false); reference.position = 70; previews.setVisible([preview.id])
        XCTAssertEqual(preview.position, 70); XCTAssertFalse(preview.playing)
    }
    @MainActor func testDateAlignmentAndFallbackUseMainClock() async {
        let (_, previews, reference, preview) = fixture()
        reference.programDate = Date(timeIntervalSince1970: 1000)
        preview.programDate = Date(timeIntervalSince1970: 990)
        previews.add(preview); previews.setVisible([preview.id])
        XCTAssertEqual(preview.dates.last, reference.programDate)
        preview.dateSucceeds = false; preview.programDate = Date(timeIntervalSince1970: 980)
        previews.tick(); XCTAssertEqual(preview.seeks.last, 40)
    }
    @MainActor func testLivePreviewUsesRelativeLagAndClampsItsRange() async {
        let (_, previews, reference, preview) = fixture()
        reference.live = true; reference.seekRange = 0...100; reference.position = 90
        preview.live = true; preview.seekRange = 10...200
        previews.add(preview); previews.setVisible([preview.id]); XCTAssertEqual(preview.position, 190)
        reference.live = false; reference.position = 500; previews.tick()
        XCTAssertEqual(preview.position, 199.9, accuracy: 0.01)
    }
    @MainActor func testPauseDuringBufferingAndRecovery() async {
        let (main, previews, reference, preview) = fixture()
        previews.add(preview); previews.setVisible([preview.id]); preview.buffering = true
        main.setPlaying(false); previews.tick(); XCTAssertFalse(preview.playing)
        reference.position = 65; previews.tick(); XCTAssertEqual(preview.position, 20)
        preview.buffering = false; previews.tick(); XCTAssertEqual(preview.position, 65); XCTAssertFalse(preview.playing)
        main.setPlaying(true); previews.tick(); XCTAssertTrue(preview.playing)
    }
    @MainActor func testDriftThresholdScrubAndQualitySuppression() async {
        let (main, previews, reference, preview) = fixture()
        previews.add(preview); previews.setVisible([preview.id]); preview.position = 20.4; previews.tick()
        XCTAssertTrue(preview.seeks.isEmpty)
        preview.position = 5; main.isScrubbing = true; previews.tick()
        XCTAssertTrue(preview.seeks.isEmpty); XCTAssertFalse(preview.playing)
        main.isScrubbing = false; reference.changingQuality = true; previews.tick(); XCTAssertTrue(preview.seeks.isEmpty)
        reference.changingQuality = false; previews.tick(); XCTAssertEqual(preview.position, 20); XCTAssertTrue(preview.playing)
    }
    @MainActor func testPendingMainSeekSuspendsPreviewsUntilCompletion() async {
        let (main, previews, reference, preview) = fixture()
        previews.add(preview); previews.setVisible([preview.id]); reference.deferred = true
        main.seek(from: reference.id, seconds: 60); previews.tick(); XCTAssertFalse(preview.playing); XCTAssertTrue(preview.seeks.isEmpty)
        reference.completions[0](true); previews.tick(); XCTAssertEqual(preview.position, 60); XCTAssertTrue(preview.playing)
    }
    @MainActor func testRemovalAndResetIgnoreOldCompletions() async {
        let (_, previews, reference, preview) = fixture()
        preview.deferred = true; preview.position = 0
        previews.add(preview); previews.setVisible([preview.id]); previews.remove(preview.id)
        preview.completions[0](true); XCTAssertFalse(preview.playing)
        preview.position = 0; reference.position = 55; previews.add(preview); previews.setVisible([preview.id]); previews.reset()
        preview.completions[1](true); XCTAssertFalse(preview.playing)
    }
    @MainActor func testClosingReferencePromotesMainFeedForPreviewAlignment() async {
        let (main, previews, reference, preview) = fixture(), second = TestFeed("second")
        main.add(second); previews.add(preview); previews.setVisible([preview.id])
        main.remove(id: reference.id); second.position = 80; previews.tick()
        XCTAssertEqual(preview.position, 80); XCTAssertEqual(main.reference?.id, second.id)
    }
    @MainActor func testTimedOutSeekCannotResumeAfterNewSeek() async {
        var now = Date(timeIntervalSince1970: 2000)
        let main = LinkedPlaybackCoordinator(clock: { now }), reference = TestFeed("main"), preview = TestFeed("preview")
        main.add(reference)
        let previews = LinkedPreviewCoordinator(session: main, clock: { now })
        preview.position = 0; preview.deferred = true; previews.add(preview); previews.setVisible([preview.id])
        now = now.addingTimeInterval(6); reference.position = 60; previews.tick()
        preview.completions[0](true); XCTAssertFalse(preview.playing)
        preview.completions[1](true); XCTAssertTrue(preview.playing)
    }
    @MainActor func testUnavailableMainReferencePausesPreview() async {
        let (main, previews, reference, preview) = fixture()
        previews.add(preview); previews.setVisible([preview.id]); XCTAssertTrue(preview.playing)
        reference.buffering = true; previews.tick(); XCTAssertFalse(preview.playing)
        reference.buffering = false; reference.position = 55; previews.tick(); XCTAssertEqual(preview.position, 55)
        main.reset(); previews.tick(); XCTAssertFalse(preview.playing)
    }

}

import XCTest
@testable import F1Core

final class PlaybackStartupTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 100)
    func testPreparationTimeoutIncludesHungMetadata() {
        var state = PlaybackStartup(); state.begin(now: start)
        XCTAssertFalse(state.expired(now: start.addingTimeInterval(44), wantsPlayback: false, isPlaying: false))
        XCTAssertTrue(state.expired(now: start.addingTimeInterval(45), wantsPlayback: false, isPlaying: false))
    }
    func testPreparedButNeverPlayingTimesOut() {
        var state = PlaybackStartup(); let id = state.begin(now: start); state.prepared(id, now: start)
        XCTAssertTrue(state.expired(now: start.addingTimeInterval(20), wantsPlayback: true, isPlaying: false))
    }
    func testPauseDoesNotCountTowardStartupDeadline() {
        var state = PlaybackStartup(); let id = state.begin(now: start); state.prepared(id, now: start)
        XCTAssertFalse(state.expired(now: start.addingTimeInterval(100), wantsPlayback: false, isPlaying: false))
        XCTAssertFalse(state.expired(now: start.addingTimeInterval(119), wantsPlayback: true, isPlaying: false))
        XCTAssertTrue(state.expired(now: start.addingTimeInterval(120), wantsPlayback: true, isPlaying: false))
    }
    func testSuccessfulPlaybackDisarmsDeadline() {
        var state = PlaybackStartup(); let id = state.begin(now: start); state.prepared(id, now: start)
        XCTAssertFalse(state.expired(now: start.addingTimeInterval(1), wantsPlayback: true, isPlaying: true))
        XCTAssertFalse(state.expired(now: start.addingTimeInterval(100), wantsPlayback: true, isPlaying: false))
        XCTAssertTrue(state.accepts(id)) // Later real playback errors still belong to this attempt.
    }
    func testClosingAndRetryRejectOldCompletions() {
        var state = PlaybackStartup(); let old = state.begin(now: start); state.cancel()
        XCTAssertFalse(state.accepts(old))
        let current = state.begin(now: start); state.prepared(old, now: start)
        XCTAssertTrue(state.accepts(current)); XCTAssertFalse(state.accepts(old))
        XCTAssertFalse(state.expired(now: start.addingTimeInterval(20), wantsPlayback: true, isPlaying: false))
    }
    func testCDNAccessRetryIsBoundedAndExcludesOtherFailures() {
        let rejected = NSError(domain: NSURLErrorDomain, code: -1102, userInfo: [AppErrorStore.httpStatusKey: 403])
        var retry = PlaybackAccessRetry()
        XCTAssertFalse(retry.consume(URLError(.timedOut)))
        XCTAssertFalse(retry.consume(NSError(domain: NSURLErrorDomain, code: -1102)))
        XCTAssertFalse(retry.consume(NSError(domain: "Application", code: 403, userInfo: [AppErrorStore.httpStatusKey: 403])))
        XCTAssertFalse(retry.consume(URLError(.cancelled)))
        XCTAssertTrue(retry.consume(rejected))
        XCTAssertFalse(retry.consume(rejected))
    }

    func testLegacySettingsDisableOptionalScrubPlayerAndRetainFeedPreviews() throws {
        let settings = try JSONDecoder().decode(PlayerSettings.self, from: Data("{\"livePreviews\":true}".utf8))
        XCTAssertFalse(settings.scrubPreviews)
        XCTAssertTrue(settings.livePreviews)
        var enabled = settings; enabled.scrubPreviews = true
        let restored = try JSONDecoder().decode(PlayerSettings.self, from: JSONEncoder().encode(enabled))
        XCTAssertTrue(restored.scrubPreviews)
    }

}

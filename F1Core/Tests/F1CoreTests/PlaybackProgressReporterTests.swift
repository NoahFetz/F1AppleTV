import XCTest
@testable import F1Core

final class PlaybackProgressReporterTests: XCTestCase {
    private func progress(_ position: Int, id: String = "race") -> PlaybackProgressReporter.Progress {
        .init(contentID: id, subtype: "REPLAY", position: position, timestamp: position)
    }
    @MainActor func testFinalPositionWaitsForInflightReportAndReplacesIntermediatePositions() async {
        let started = expectation(description: "First report started")
        var delivered: [PlaybackProgressReporter.Progress] = []
        var gate: CheckedContinuation<Void, Never>?
        let reporter = PlaybackProgressReporter(deliver: { value in
            delivered.append(value)
            if delivered.count == 1 {
                await withCheckedContinuation { gate = $0; started.fulfill() }
            }
        }, onError: { _ in XCTFail("Unexpected reporting failure") })
        reporter.submit(progress(10))
        await fulfillment(of: [started], timeout: 2)
        reporter.submit(progress(20)); reporter.submit(progress(30))
        reporter.submit(progress(40, id: "another-race"))
        gate?.resume()
        await reporter.flush()
        XCTAssertEqual(delivered.map(\.position), [10, 30, 40])
    }
    @MainActor func testExitDoesNotCancelFinalPositionWhenViewerReleasesReporter() async {
        let started = expectation(description: "Report started")
        let finished = expectation(description: "Final report delivered")
        var delivered: [Int] = []
        var gate: CheckedContinuation<Void, Never>?
        var reporter: PlaybackProgressReporter? = PlaybackProgressReporter(deliver: { value in
            delivered.append(value.position)
            if value.position == 10 {
                await withCheckedContinuation { gate = $0; started.fulfill() }
            } else { finished.fulfill() }
        }, onError: { _ in XCTFail("Unexpected reporting failure") })
        reporter?.submit(progress(10))
        await fulfillment(of: [started], timeout: 2)
        reporter?.submit(progress(99)); reporter = nil
        gate?.resume()
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertEqual(delivered, [10, 99])
    }
    @MainActor func testFailedIntermediateReportDoesNotDiscardFinalPosition() async {
        let started = expectation(description: "Report started")
        var gate: CheckedContinuation<Void, Never>?
        var delivered: [Int] = []; var failures = 0
        let reporter = PlaybackProgressReporter(deliver: { value in
            delivered.append(value.position)
            if value.position == 10 {
                await withCheckedContinuation { gate = $0; started.fulfill() }
                throw URLError(.notConnectedToInternet)
            }
        }, onError: { _ in failures += 1 })
        reporter.submit(progress(10))
        await fulfillment(of: [started], timeout: 2)
        reporter.submit(progress(99)); gate?.resume()
        await reporter.flush()
        XCTAssertEqual(delivered, [10, 99]); XCTAssertEqual(failures, 1)
    }
    func testF1LiveAudioDefaultsDecodeOldSettingsAndPreserveDistinctTrackNames() throws {
        let legacy = try JSONDecoder().decode(PlayerSettings.self, from: Data("{}".utf8))
        XCTAssertNil(legacy.f1LiveAudioTrack); XCTAssertTrue(legacy.discoveredF1LiveAudioTracks.isEmpty)
        var settings = legacy
        settings.discoveredF1LiveAudioTracks = ["English Commentary", "English FX"]
        settings.f1LiveAudioTrack = "English FX"
        let restored = try JSONDecoder().decode(PlayerSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored.f1LiveAudioTrack, "English FX")
        XCTAssertEqual(restored.discoveredF1LiveAudioTracks, settings.discoveredF1LiveAudioTracks)
        XCTAssertEqual(restored.audioDefaults, legacy.audioDefaults)
    }
}

import Foundation
import AVFoundation
import XCTest

extension String { var localizedString: String { self } }

@MainActor
private final class LiveDouble: LiveSeekSession {
    var ready = true
    var range: (start: Double, end: Double)? = (100, 400)
    var position = 200.0
    var date: Date?
    var times = [Double]()
    var dates = [Date]()
    var plays = 0
    var cancels = 0
    var dateSucceeds = true
    var deferCompletion = false
    var completion: ((Bool) -> Void)?
    func seek(time: Double, completion: @escaping (Bool) -> Void) {
        times.append(time)
        if deferCompletion { self.completion = completion; return }
        if let date { self.date = date.addingTimeInterval(time - position) }
        position = time; completion(true)
    }
    func seek(date: Date, completion: @escaping (Bool) -> Void) { dates.append(date); completion(dateSucceeds) }
    func play() { plays += 1 }
    func cancelSeek() { cancels += 1 }
}

@MainActor
final class MultiviewFeatureTests: XCTestCase {
    private func channel(_ id: String, title: String = "INTERNATIONAL", kind: ChannelType = .MainFeed, number: Int = 0, name: String? = nil) -> PlaybackChannel {
        PlaybackChannel(id: id, target: PlaybackTarget(uri: "https://fixture.invalid/" + id + "?token=DO_NOT_SAVE", requiresVideoDetails: false), kind: kind, contentID: "999", title: title, racingNumber: number, driverLastName: name)
    }
    private func setup(_ streams: [StreamSelection], layout: MultiviewLayout = .grid) -> MultiviewSetup {
        MultiviewSetup(name: "Test", layout: layout, streams: streams.map { SavedStream(selection: $0, volume: 0.4, muted: false) })
    }
    func testGridFourAndSixteen() {
        for (count, size) in [(4, 2), (16, 4)] {
            let frames = PlayerLayoutGeometry(layout: .grid, count: count, bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)).frames
            XCTAssertEqual(frames.count, count)
            XCTAssertEqual(frames.first?.width, 1920 / CGFloat(size))
            XCTAssertEqual(frames.last?.maxX, 1920)
            XCTAssertEqual(frames.last?.maxY, 1080)
        }
    }
    func testLayoutsStayInBoundsWithoutOverlapExceptInset() {
        let bounds = CGRect(x: 20, y: 35, width: 1280, height: 720)
        for layout in MultiviewLayout.allCases {
            for count in 0...32 where layout.supports(count: count) {
                let frames = PlayerLayoutGeometry(layout: layout, count: count, bounds: bounds).frames
                XCTAssertEqual(frames.count, layout.slotCount(players: count))
                for (index, frame) in frames.enumerated() {
                    XCTAssertGreaterThan(frame.width, 0); XCTAssertGreaterThan(frame.height, 0)
                    XCTAssertGreaterThanOrEqual(frame.minX, bounds.minX - 0.001)
                    XCTAssertLessThanOrEqual(frame.maxX, bounds.maxX + 0.001)
                    XCTAssertLessThanOrEqual(frame.maxY, bounds.maxY + 0.001)
                    if layout != .inset {
                        for other in frames.dropFirst(index + 1) { XCTAssertTrue(frame.intersection(other).isNull || frame.intersection(other).width < 0.001 || frame.intersection(other).height < 0.001) }
                    }
                }
            }
        }
    }
    func testCapacityAndEmptySlots() {
        XCTAssertEqual(MultiviewLayout.mainPlusThree.slotCount(players: 1), 4)
        XCTAssertFalse(MultiviewLayout.single.supports(count: 2))
        XCTAssertEqual(MultiviewLayout.inset.afterAdding(count: 3), .auto)
        XCTAssertEqual(MultiviewLayout.grid.afterAdding(count: 20), .grid)
        XCTAssertEqual(PlayerLayoutGeometry(layout: .inset, count: 2, bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)).frames[1].width, 576)
    }
    func testAutoRetainsExistingFiveAndSixArrangements() {
        for count in [5, 6] {
            let frames = PlayerLayoutGeometry(layout: .auto, count: count, bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)).frames
            XCTAssertEqual(frames.count, count)
            XCTAssertEqual(frames[0].height, 1080 * 0.666, accuracy: 0.001)
            XCTAssertEqual(frames[4].minY, frames[0].maxY)
        }
    }
    func testDefaultFeedResolutionAndAbsenceFallback() {
        let main = channel("main"), live = channel("live", title: "F1 LIVE", kind: .AdditionalFeed)
        XCTAssertEqual(PlaybackSelection.initialChannel(in: [main, live], preference: .f1Live)?.id, "live")
        XCTAssertEqual(PlaybackSelection.initialChannel(in: [live, main], preference: .international)?.id, "main")
        XCTAssertEqual(PlaybackSelection.initialChannel(in: [main], preference: .f1Live)?.id, "main")
        XCTAssertEqual(PlaybackSelection.initialChannel(in: [live], preference: .international)?.id, "live")
        XCTAssertNil(PlaybackSelection.initialChannel(in: [], preference: .f1Live))
    }
    func testSettingsMigrationAndRoundTrip() throws {
        XCTAssertEqual(try JSONDecoder().decode(PlayerSettings.self, from: Data("{}".utf8)).defaultFeed, .international)
        XCTAssertEqual(try JSONDecoder().decode(PlayerSettings.self, from: Data("{\"defaultFeed\":\"unknown\"}".utf8)).defaultFeed, .international)
        var settings = PlayerSettings(); settings.defaultFeed = .f1Live; settings.preferredChannelVolume[0] = 0.3; settings.liveStart = .beginning
        let result = try JSONDecoder().decode(PlayerSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(result.defaultFeed, .f1Live); XCTAssertEqual(result.preferredChannelVolume[0], 0.3); XCTAssertEqual(result.liveStart, .beginning)
    }
    func testSelectionsResolveAcrossSessionURLsAndDriverNumbers() {
        let saved = setup([.f1Live, .driver(number: 1, name: "max verstappen"), .additional(name: "extra camera")])
        let channels = [channel("new1", title: "F1 Live", kind: .AdditionalFeed), channel("new2", title: "VER", kind: .OnBoardCamera, number: 33, name: "Max Verstappen"), channel("new3", title: "EXTRA CAMERA", kind: .AdditionalFeed)]
        let result = SetupResolver.resolve(saved, channels: channels)
        XCTAssertEqual(result.channels.map(\.id), ["new1", "new2", "new3"]); XCTAssertEqual(result.missingCount, 0)
    }
    func testMissingMainPromotionAndDuplicatePrevention() {
        let channels = [channel("main"), channel("live", title: "F1 LIVE", kind: .AdditionalFeed)]
        let result = SetupResolver.resolve(setup([.driver(number: 99, name: "missing"), .f1Live, .f1Live, .international]), channels: channels)
        XCTAssertEqual(result.channels.map(\.id), ["live", "main"])
        XCTAssertEqual(result.audio.count, 2); XCTAssertEqual(result.missingCount, 2)
    }
    func testDriverNumberReuseDoesNotSelectDifferentDriver() {
        let selected = StreamSelection.driver(number: 1, name: "max verstappen")
        XCTAssertFalse(selected.matches(channel("new", kind: .OnBoardCamera, number: 1, name: "Different Driver")))
        XCTAssertTrue(StreamSelection.driver(number: 16, name: "").matches(channel("new", kind: .OnBoardCamera, number: 16)))
    }
    func testPersistenceRenameDeleteAndNotifications() throws {
        let suite = "multiview-tests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let store = MultiviewSetupStore(defaults: defaults)
        var notifications = 0
        let observer = NotificationCenter.default.addObserver(forName: MultiviewSetupStore.didChange, object: store, queue: nil) { _ in notifications += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }
        var saved = setup([.international]); try store.save(saved)
        XCTAssertEqual(MultiviewSetupStore(defaults: defaults).load(), [saved])
        saved.name = "Renamed"; try store.save(saved)
        XCTAssertEqual(store.load().map(\.name), ["Renamed"])
        try store.delete(id: saved.id); XCTAssertTrue(store.load().isEmpty)
        XCTAssertEqual(notifications, 3)
    }
    func testMalformedSetupStorageAndAudioSanitization() throws {
        let suite = "multiview-tests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("invalid".utf8), forKey: "MultiviewSetups.v1")
        let store = MultiviewSetupStore(defaults: defaults); XCTAssertTrue(store.load().isEmpty)
        var saved = setup([.international]); saved.streams[0].volume = .nan; try store.save(saved)
        XCTAssertEqual(store.load().first?.streams.first?.volume, 1)
        saved.streams[0].volume = 5; try store.save(saved)
        XCTAssertEqual(store.load().first?.streams.first?.volume, 1)
    }
    func testPersistenceDoesNotIncludeTargetsOrEntitlements() throws {
        let original = channel("session-sensitive", title: "F1 LIVE", kind: .AdditionalFeed)
        let encoded = try JSONEncoder().encode(setup([StreamSelection(channel: original)]))
        let text = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        for privateField in ["https", "DO_NOT_SAVE", "session-sensitive", "uri", "entitlement"] { XCTAssertFalse(text.contains(privateField)) }
    }
    func testLiveWindowClampingAndStatus() {
        XCTAssertEqual(LiveTimeline.target(start: 100, end: 400), 397)
        XCTAssertEqual(LiveTimeline.target(start: 100, end: 102), 100)
        XCTAssertNil(LiveTimeline.target(start: 100, end: 100)); XCTAssertNil(LiveTimeline.target(start: .nan, end: 100))
        XCTAssertTrue(LiveTimeline.isAtLive(position: 397, end: 400)); XCTAssertFalse(LiveTimeline.isAtLive(position: 370, end: 400))
    }
    func testLiveLagSynchronizationWithDifferentMediaOrigins() {
        let main = LiveDouble(), other = LiveDouble(); other.range = (1000, 1300)
        let coordinator = LivePlaybackCoordinator(); defer { coordinator.cancel() }
        coordinator.jump(reference: main, sessions: [main, other])
        XCTAssertEqual(main.times, [397]); XCTAssertEqual(other.times, [1297]); XCTAssertEqual(other.plays, 1)
        main.range = (200, 500); coordinator.jump(reference: main, sessions: [main, other])
        XCTAssertEqual(main.times.last, 497)
    }
    func testProgramDatesAndFailedDateFallback() {
        let main = LiveDouble(), other = LiveDouble(); main.date = Date(timeIntervalSince1970: 10000); other.date = Date(timeIntervalSince1970: 9500)
        other.dateSucceeds = false; other.range = (1000, 1300)
        let coordinator = LivePlaybackCoordinator(); defer { coordinator.cancel() }
        coordinator.jump(reference: main, sessions: [main, other])
        XCTAssertEqual(other.dates, [Date(timeIntervalSince1970: 10197)])
        XCTAssertEqual(other.times, [1297]); XCTAssertEqual(other.plays, 1)
    }
    func testPreparingStreamJoinsCurrentJump() {
        let main = LiveDouble(), pending = LiveDouble(); pending.ready = false
        let coordinator = LivePlaybackCoordinator(); defer { coordinator.cancel() }
        coordinator.jump(reference: main, sessions: [main, pending]); XCTAssertTrue(pending.times.isEmpty)
        pending.ready = true; coordinator.include(pending)
        XCTAssertEqual(pending.times, [397]); XCTAssertEqual(pending.plays, 1)
    }
    func testSuccessfulDateSeekAvoidsMediaTimeFallback() {
        let main = LiveDouble(), other = LiveDouble(); main.date = Date(timeIntervalSince1970: 10000); other.date = Date(timeIntervalSince1970: 9500)
        let coordinator = LivePlaybackCoordinator(); defer { coordinator.cancel() }
        coordinator.jump(reference: main, sessions: [main, other])
        XCTAssertEqual(other.dates.count, 1); XCTAssertTrue(other.times.isEmpty); XCTAssertEqual(other.plays, 1)
    }
    func testEmptyWindowTimesOutOnceWithoutPlayingOrStaleCallbacks() {
        let main = LiveDouble(); main.range = nil
        var now = Date(timeIntervalSince1970: 10000)
        let coordinator = LivePlaybackCoordinator(clock: { now }); var failures = 0
        coordinator.onFailure = { failures += 1 }
        coordinator.jump(reference: main, sessions: [main]); XCTAssertTrue(main.times.isEmpty)
        now.addTimeInterval(21); coordinator.preparePending(); coordinator.preparePending()
        XCTAssertEqual(failures, 1); XCTAssertEqual(main.plays, 0); XCTAssertFalse(coordinator.hasJump)
    }
    func testCancelAndSupersededJumpIgnoreStaleCompletion() {
        let main = LiveDouble(); main.deferCompletion = true
        let coordinator = LivePlaybackCoordinator(); var failures = 0; coordinator.onFailure = { failures += 1 }
        coordinator.jump(reference: main, sessions: [main]); let old = main.completion
        coordinator.cancel(); old?(true)
        XCTAssertEqual(main.plays, 0); XCTAssertEqual(failures, 0)
        coordinator.jump(reference: main, sessions: [main]); let superseded = main.completion
        coordinator.jump(reference: main, sessions: [main]); superseded?(true)
        XCTAssertEqual(main.plays, 0); coordinator.cancel()
    }
}

@main enum FeatureTestRunner {
    @MainActor static func main() {
        let suite = MultiviewFeatureTests.defaultTestSuite
        suite.run()
        exit(suite.testRun?.totalFailureCount == 0 ? 0 : 1)
    }
}

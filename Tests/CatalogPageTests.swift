import Foundation
import XCTest
import AVFoundation

@MainActor
final class CatalogPageTests: XCTestCase {
    private func page(_ name: String) throws -> CatalogPayloadDTO {
        let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["F1_CATALOG_FIXTURES"]!)
        return try XCTUnwrap(JSONDecoder().decode(APIEnvelope<CatalogPayloadDTO>.self, from: Data(contentsOf: directory.appendingPathComponent(name + ".json"))).resultObj)
    }

    private func modifiedPage(_ name: String, mutate: (inout [[String: Any]]) -> Void) throws -> CatalogPayloadDTO {
        let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["F1_CATALOG_FIXTURES"]!)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent(name + ".json"))) as! [String: Any]
        var result = json["resultObj"] as! [String: Any], nodes = result["containers"] as! [[String: Any]]
        mutate(&nodes); result["containers"] = nodes
        return try JSONDecoder().decode(CatalogPayloadDTO.self, from: JSONSerialization.data(withJSONObject: result))
    }
    private func schedule() throws -> CatalogSchedule {
        try XCTUnwrap(CatalogMapper.sections(page("azerbaijan")).first { $0.layoutType == .Schedule }?.schedule)
    }
    func testArtworkRequestsCoverDisplayPixelsAndFocusEnlargement() throws {
        let thumbnail = try XCTUnwrap(CatalogArtworkRequest(pictureID: "image/test", size: CGSize(width: 380, height: 213.75), scale: 2, focusScale: 1.025))
        XCTAssertEqual(thumbnail.pixelSize, CGSize(width: 784, height: 440))
        XCTAssertEqual(thumbnail.processingSize, CGSize(width: 392, height: 220))
        let query = try XCTUnwrap(URLComponents(url: thumbnail.url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query, [URLQueryItem(name: "w", value: "784"), URLQueryItem(name: "h", value: "440"), URLQueryItem(name: "q", value: "HI")])
        XCTAssertEqual(thumbnail.url.path, "/image-resizer/image/image/test")
        let hero = try XCTUnwrap(CatalogArtworkRequest(pictureID: "hero", size: CGSize(width: 1636, height: 620), scale: 2))
        XCTAssertGreaterThanOrEqual(hero.pixelSize.width, 3272)
        XCTAssertEqual(CatalogArtworkRequest(pictureID: "backdrop", size: CGSize(width: 1920, height: 1080), scale: 2)?.pixelSize, CGSize(width: 3840, height: 2160))
    }
    func testArtworkRequestsSkipMissingAndInvalidSizes() {
        XCTAssertNil(CatalogArtworkRequest(pictureID: nil, size: CGSize(width: 380, height: 214), scale: 1))
        XCTAssertNil(CatalogArtworkRequest(pictureID: "", size: CGSize(width: 380, height: 214), scale: 1))
        XCTAssertNil(CatalogArtworkRequest(pictureID: "test", size: .zero, scale: 1))
        XCTAssertNil(CatalogArtworkRequest(pictureID: "test", size: CGSize(width: CGFloat.infinity, height: 214), scale: 1))
        XCTAssertNil(CatalogArtworkRequest(pictureID: "test", size: CGSize(width: 380, height: 214), scale: 0))
    }
    func testMenuKeepsBackendYearOrderAndDestinationsAndExcludesAccountFeatures() throws {
        let response = try page("menu")
        let entries = CatalogMapper.menu(response)
        XCTAssertEqual(entries.map(\.title), ["Home", "2026 Season", "Archive", "Shows", "Documentaries"])
        XCTAssertEqual(entries.map(\.uri), response.containers?.values.prefix(5).compactMap { $0.actions?.values.first?.uri })
        let modified = try modifiedPage("menu") { nodes in
            var actions = nodes[0]["actions"] as! [[String: Any]]
            actions[0]["uri"] = (actions[0]["uri"] as! String) + "?from=20&filter_Series=Formula+2"
            nodes[0]["actions"] = actions
        }
        XCTAssertTrue(CatalogMapper.menu(modified)[0].uri.hasSuffix("?from=20&filter_Series=Formula+2"))
        let invalid = try modifiedPage("menu") { nodes in
            var actions = nodes[0]["actions"] as! [[String: Any]]
            actions[0]["uri"] = "https://example.com/2.0/R/ENG/WEB_HLS/ALL/PAGE/395"
            nodes[0]["actions"] = actions
        }
        XCTAssertEqual(CatalogMapper.menu(invalid).count, 4)
    }
    func testMenuCacheIsLanguageSpecificAndRetainsSuccessfulDataWhenRefreshFails() throws {
        let name = "CatalogMenuTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let cache = CatalogMenuCache(defaults: defaults)
        XCTAssertTrue(cache.load(language: "ENG").isEmpty)
        let entries = CatalogMapper.menu( try page("menu"))
        cache.store(entries, language: "ENG")
        cache.store([], language: "ENG")
        XCTAssertEqual(cache.load(language: "ENG"), entries)
        XCTAssertTrue(cache.load(language: "DEU").isEmpty)
        defaults.set(Data("broken".utf8), forKey: "CatalogMenu.DEU")
        XCTAssertTrue(cache.load(language: "DEU").isEmpty)
    }

    func testLegacySettingsMigrateWithoutResettingAudioCaptionsOrVolume() throws {
        let legacy = Data(#"{"id":"saved","preferredChannelLanguage":{"0":"English","2":"Deutsch"},"preferredChannelCaptions":{"0":"English"},"preferredChannelVolume":{"0":0.4},"preferredChannelMute":{"2":true},"driverChannelSorting":1,"showFunNames":true}"#.utf8)
        let settings = try JSONDecoder().decode(PlayerSettings.self, from: legacy)
        XCTAssertEqual(settings.id, "saved")
        XCTAssertEqual(settings.preferredChannelLanguage[0] ?? nil, "English")
        XCTAssertEqual(settings.preferredChannelCaptions[0] ?? nil, "English")
        XCTAssertEqual(settings.getPreferredVolume(for: .MainFeed), 0.4)
        XCTAssertTrue(settings.getPreferredMute(for: .OnBoardCamera))
        XCTAssertEqual(settings.driverChannelSorting, .Alphabetical)
        XCTAssertTrue(settings.showFunNames)
        XCTAssertTrue(settings.followsHeroBackground && settings.livePreviews)
        XCTAssertEqual(settings.previewHeight, 360)
        XCTAssertNil(settings.startupMaximumHeight)
        XCTAssertEqual(settings.liveStart, .ask)
        XCTAssertTrue(settings.audioDefaults.isEmpty && settings.captionDefaults.isEmpty)
    }

    func testSettingsRoundTripRetainsStablePreferencesAndStartupDefaults() throws {
        var settings = PlayerSettings()
        settings.followsHeroBackground = false; settings.livePreviews = false
        settings.previewHeight = 540; settings.startupMaximumHeight = 720; settings.liveStart = .beginning
        settings.audioDefaults = [0: "de", 1: "default"]; settings.captionDefaults = [0: "off", 2: "en"]
        let decoded = try JSONDecoder().decode(PlayerSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertFalse(decoded.followsHeroBackground || decoded.livePreviews)
        XCTAssertEqual(decoded.previewHeight, 540)
        XCTAssertEqual(decoded.startupMaximumHeight, 720)
        XCTAssertEqual(decoded.liveStart, .beginning)
        XCTAssertEqual(decoded.audioDefaults, settings.audioDefaults)
        XCTAssertEqual(decoded.captionDefaults, settings.captionDefaults)
        let partial = try JSONDecoder().decode(PlayerSettings.self, from: Data(#"{"previewHeight":123}"#.utf8))
        XCTAssertEqual(partial.previewHeight, 360)
        XCTAssertEqual(partial.getPreferredVolume(for: .AdditionalFeed), 1)
    }

    func testPreviewWindowPrefetchesOnlyImmediateNeighboursAndClampsInvalidIndices() {
        XCTAssertEqual(PreviewWindow.indices(visible: [3, 4], count: 20), [2, 3, 4, 5])
        XCTAssertEqual(PreviewWindow.indices(visible: [0, 1], count: 20), [0, 1, 2])
        XCTAssertEqual(PreviewWindow.indices(visible: [19], count: 20), [18, 19])
        XCTAssertEqual(PreviewWindow.indices(visible: [], count: 20), [])
        XCTAssertEqual(PreviewWindow.indices(visible: [-1, 99], count: 20), [])
        XCTAssertEqual(PreviewWindow.indices(visible: [0], count: 0), [])
    }

    func testPreviewPoolPrefetchReleaseAndStalePreparationCompletion() {
        let items = (0..<12).map { index -> ContentItem in
            var item = ContentItem(); item.id = "video:\(index + 1)"; item.contentId = String(index + 1); return item
        }
        var sessions = [StreamPreviewSession]()
        let pool = StreamPreviewCoordinator(makeSession: { let session = StreamPreviewSession(); sessions.append(session); return session })
        let reference = AVPlayer()
        pool.configure(items: items, reference: reference, maximumHeight: 540)
        var ready = [String]()
        pool.onReady = { key, player in if player != nil { ready.append(key) } }
        pool.update(visibleIndices: [3, 4])
        XCTAssertEqual(sessions.count, 4)
        XCTAssertTrue(sessions.allSatisfy { $0.height == 540 })
        sessions.forEach { $0.finish() }
        XCTAssertEqual(sessions.map(\.lastVisible), [false, true, true, false])
        XCTAssertTrue(sessions.allSatisfy { $0.lastReference === reference })
        XCTAssertNotNil(pool.player(for: items[3].previewIdentity))
        pool.update(visibleIndices: [4, 5])
        XCTAssertEqual(sessions.count, 5)
        XCTAssertEqual(sessions[0].stops, 1)
        XCTAssertNil(pool.player(for: items[2].previewIdentity))
        let readyCount = ready.count
        sessions[0].finish() // A released entitlement must not reattach its player.
        XCTAssertEqual(ready.count, readyCount)
        XCTAssertNil(pool.player(for: items[2].previewIdentity))
        pool.stop()
        sessions[4].finish() // Dismissal also invalidates unfinished preparation.
        XCTAssertEqual(ready.count, readyCount)
        XCTAssertTrue(sessions.allSatisfy { $0.stops == 1 })
    }

    func testPreviewPoolUsesUpdatedReferenceAndDeduplicatesChannelIdentity() {
        var item = ContentItem(); item.id = "video:42"; item.contentId = "42"
        var sessions = [StreamPreviewSession]()
        let pool = StreamPreviewCoordinator(makeSession: { let session = StreamPreviewSession(); sessions.append(session); return session })
        let first = AVPlayer(), second = AVPlayer()
        var current = first
        pool.configure(items: [item, item], reference: first, maximumHeight: 360, referenceProvider: { current })
        pool.update(visibleIndices: [0, 1])
        XCTAssertEqual(sessions.count, 1)
        sessions[0].finish()
        XCTAssertTrue(sessions[0].lastReference === first)
        current = second
        pool.update(visibleIndices: [1])
        XCTAssertTrue(sessions[0].lastReference === second)
        pool.update(visibleIndices: [])
        XCTAssertEqual(sessions[0].stops, 1)
        XCTAssertNil(pool.player(for: item.previewIdentity))
    }

    func testAllCapturedCatalogPagesDecodeAndKeepTheirSectionOrder() throws {
        for name in ["home", "shows", "documentaries", "formula2", "formula3", "academy", "supercup", "azerbaijan", "season", "archive"] {
            let response = try page(name), sections = CatalogMapper.sections(response)
            XCTAssertFalse(sections.isEmpty, name)
            XCTAssertEqual(sections.map { $0.layoutType.getIdentifier() }, response.containers?.values.map { $0.layout }, name)
            for (section, node) in zip(sections, response.containers?.values ?? []) where ![ContainerLayoutType.Schedule, .Title, .Subtitle].contains(section.layoutType) {
                XCTAssertEqual(section.items.map { $0.contentId }, node.retrieveItems?.resultObj.containers?.values.map { $0.metadata?.contentId?.value }, name)
            }
        }
    }
    func testHomeContainsPostersAndAllFourAPISuppliedSeriesDestinations() throws {
        let sections = CatalogMapper.sections( try page("home"))
        XCTAssertEqual(sections.filter { $0.layoutType == .HorizontalSimplePoster }.map(\.title), ["Shows", "Documentaries"])
        let launchers = sections.flatMap(\.items).filter { $0.objectType == .Launcher }
        XCTAssertEqual(launchers.map { $0.title }, ["Formula 2", "Formula 3", "F1 Academy", "Supercup"])
        XCTAssertEqual(launchers.compactMap { if case .destination(let d) = $0.action { return d.href }; return nil }, ["/page/12406/formula-2", "/page/12639/formula-3", "/page/12641/f1-academy", "/page/12643/supercup"])
        XCTAssertTrue(sections.filter { $0.layoutType == .Hero }.allSatisfy { $0.title.isEmpty && $0.viewAllAction == nil })
    }

    func testPosterAndThumbnailVariantsRetainTheirOrientationAndDestinations() throws {
        let payload = try modifiedPage("home") { nodes in
            let original = nodes.first { $0["layout"] as? String == "horizontal_simple_poster" }!
            nodes = ["horizontal_simple_poster", "vertical_simple_poster", "horizontal_simple_thumbnail", "vertical_simple_thumbnail"].map { layout in
                var node = original; node["layout"] = layout; return node
            }
        }
        let sections = CatalogMapper.sections(payload)
        XCTAssertEqual(sections.map { $0.layoutType.isPoster }, [true, true, false, false])
        XCTAssertEqual(sections.map { $0.layoutType.isHorizontal }, [true, false, true, false])
        XCTAssertTrue(sections.allSatisfy { $0.items.first?.id == sections.first?.items.first?.id })
    }
    func testCatalogRoutingChangesOnlyProviderAndPreservesEncodedQuery() throws {
        let base = URL(string: "https://f1tv.formula1.com")!
        let query = "filter_objectSubtype=LIVE_EVENT%2CReplay&filter_Series=Formula+2&from=21&maxResults=20"
        for provider in ["BIG_SCREEN_HLS", "WEB_HLS", "WEB_DASH", "MOBILE_HLS"] {
            let uri = "/2.0/R/DEU/\(provider)/ALL/PAGE/SEARCH/VOD/PREMIUM/14?\(query)"
            let url = try XCTUnwrap(CatalogRequest.url(for: uri, baseURL: base))
            XCTAssertEqual(url.absoluteString, "https://f1tv.formula1.com/2.0/R/DEU/WEB_HLS/ALL/PAGE/SEARCH/VOD/PREMIUM/14?\(query)")
        }
        XCTAssertNil(CatalogRequest.url(for: "https://example.com/2.0/R/ENG/WEB_HLS/ALL/PAGE/395", baseURL: base))
        XCTAssertNil(CatalogRequest.url(for: "//example.com/2.0/R/ENG/WEB_HLS/ALL/PAGE/395", baseURL: base))
        XCTAssertNil(CatalogRequest.url(for: "/search", baseURL: base))
    }

    func testCatalogSourceDoesNotChangePlaybackProvider() {
        let playbackProvider = APIStreamType.BigScreenHLS
        XCTAssertTrue(CatalogRequest.pageURI(pageID: "395", language: "FRA").contains("/FRA/WEB_HLS/"))
        XCTAssertEqual(playbackProvider.getAPIKey(), "BIG_SCREEN_HLS")
    }

    func testBannerCannotOfferSelfNavigatingViewAll() throws {
        let banner = try XCTUnwrap(CatalogMapper.sections( try page("azerbaijan")).first)
        XCTAssertEqual(banner.layoutType, .GpBanner)
        XCTAssertNil(banner.viewAllAction)
        XCTAssertEqual(banner.items.first?.race?.meetingCountryName, "Azerbaijan")
    }

    func testScheduleFiltersAreServerSuppliedAndAllDoesNotDuplicateSessions() throws {
        let schedule = try schedule()
        XCTAssertEqual(schedule.groups.map(\.label), ["ALL", "F1", "F2"])
        let all = try XCTUnwrap(schedule.groups.first)
        XCTAssertEqual(Set(all.events.compactMap { $0.contentId }).count, all.events.count)
        XCTAssertEqual(all.events.count, try self.schedule().groups.first?.events.count)
        XCTAssertTrue(schedule.groups[1].events.allSatisfy { $0.race?.series == "FORMULA 1" })
        XCTAssertTrue(schedule.groups[2].events.allSatisfy { $0.race?.series == "FORMULA 2" })
        XCTAssertEqual(schedule.groups[1].name, "FORMULA 1")
    }

    func testScheduleSortsByStartTimeAndGroupsInSpecifiedTimezone() throws {
        let schedule = try schedule()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let days = schedule.days(groupName: "ALL", calendar: calendar)
        let events = days.flatMap(\.events)
        let dates = events.compactMap(CatalogSchedule.startDate)
        XCTAssertEqual(dates, dates.sorted())
        for day in days {
            XCTAssertTrue(day.events.allSatisfy { calendar.startOfDay(for: CatalogSchedule.startDate($0)!) == day.date })
        }
    }

    func testMissingAllGroupIsSynthesizedWithoutDuplicates() throws {
        var groups = try schedule().groups; groups.removeFirst(); groups.append(groups[0])
        let all = try XCTUnwrap(CatalogSchedule(groups: groups).groups.first)
        XCTAssertEqual(all.name, "ALL")
        XCTAssertEqual(all.events.count, Set(all.events.compactMap { $0.contentId }).count)
    }
    func testUnavailableAndInformationalScheduleEventsCannotPlay() throws {
        var event = try XCTUnwrap(schedule().groups.first?.events.first)
        XCTAssertTrue(CatalogSchedule.canPlay(event))
        event.interactive = false
        XCTAssertFalse(CatalogSchedule.canPlay(event))
        event.interactive = true
        event.locked = true
        XCTAssertFalse(CatalogSchedule.canPlay(event))
        event.locked = false
        event.objectType = .Bundle
        XCTAssertFalse(CatalogSchedule.canPlay(event))
        event.objectType = .Video
        event.contentId = "0"
        XCTAssertFalse(CatalogSchedule.canPlay(event))
        event.contentId = nil
        XCTAssertFalse(CatalogSchedule.canPlay(event))
    }

    func testInformationalSessionsWithPlaceholderIDsRemainVisible() throws {
        let payload = try modifiedPage("azerbaijan") { nodes in
            let i = nodes.firstIndex { $0["layout"] as? String == "interactive_schedule" }!
            var retrieve = nodes[i]["retrieveItems"] as! [String: Any], result = retrieve["resultObj"] as! [String: Any]
            var groups = result["containers"] as! [[String: Any]], events = Array((groups[0]["events"] as! [[String: Any]]).prefix(2))
            for i in events.indices { var m = events[i]["metadata"] as! [String: Any]; m["contentId"] = 0; events[i]["metadata"] = m }
            events.append(events[0]); groups[0]["events"] = events; result["containers"] = groups; retrieve["resultObj"] = result; nodes[i]["retrieveItems"] = retrieve
        }
        let all = try XCTUnwrap(CatalogMapper.sections(payload).first { $0.layoutType == .Schedule }?.schedule?.groups.first)
        XCTAssertEqual(all.events.count, 2)
        XCTAssertTrue(all.events.allSatisfy { !CatalogSchedule.canPlay($0) })
    }
    func testMixedFlatItemsAndUnknownLayoutsDoNotReorderOtherSections() throws {
        let video: [String: Any] = ["layout": "CONTENT_ITEM", "metadata": ["contentType": "VIDEO", "contentId": 42]]
        let payload = try JSONDecoder().decode(CatalogPayloadDTO.self, from: JSONSerialization.data(withJSONObject: ["containers": [video, ["layout": "title", "metadata": ["label": "Title"]], ["layout": "future_widget"], video, video]]))
        let sections = CatalogMapper.sections(payload)
        XCTAssertEqual(sections.map(\.layoutType), [.ContentItem, .Title, .ContentItem])
        XCTAssertEqual(sections.map { $0.items.count }, [1, 0, 2])
    }
    func testPresentationGroupsHeadingsWithoutReorderingContent() throws {
        let source = CatalogMapper.sections( try page("season"))
        let grouped = CatalogPresentation.sections(source)
        XCTAssertEqual(grouped.first?.title, "2026 Season")
        XCTAssertEqual(grouped.first?.subtitle, "2026 FIA FORMULA ONE WORLD CHAMPIONSHIP™ RACE CALENDAR")
        XCTAssertEqual(grouped.dropFirst().map(\.layoutType), source.dropFirst(2).map(\.layoutType))
    }
    func testDestinationHeaderUsesReturnedTitleAndSelectedArtwork() throws {
        var selected = ContentItem(); selected.title = "Old title"; selected.pictureUrl = "public-artwork"; selected.longDescription = "Description"
        let source = CatalogMapper.sections( try page("shows"))
        let result = CatalogPresentation.sections(source, destination: selected)
        XCTAssertEqual(result.first?.layoutType, .PageHeader)
        XCTAssertEqual(result.first?.items.first?.title, "SHOWS")
        XCTAssertEqual(result.first?.items.first?.pictureUrl, "public-artwork")
        XCTAssertEqual(result.dropFirst().map(\.layoutType), source.dropFirst().map(\.layoutType))
    }
    func testExistingRaceBannerIsNotDuplicatedByDestinationHeader() throws {
        let source = CatalogMapper.sections( try page("azerbaijan"))
        XCTAssertTrue(source.contains { $0.layoutType == .GpBanner })
        XCTAssertFalse(CatalogPresentation.sections(source, destination: ContentItem()).contains { $0.layoutType == .PageHeader })
    }
    func testHeadingDuplicatesAndArtworklessDestinations() {
        var title = ContentSection(); title.title = "Title"; title.layoutType = .Title
        var subtitle = title; subtitle.title = " TITLE "; subtitle.layoutType = .Subtitle
        let result = CatalogPresentation.sections([title, subtitle], destination: ContentItem())
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.items.first?.title, "Title")
        XCTAssertNil(result.first?.items.first?.pictureUrl)
        XCTAssertEqual(CatalogPresentation.sections([title, subtitle]).first?.subtitle, "")
        subtitle.title = "A distinct subtitle"
        var hero = ContentSection(); hero.layoutType = .Hero
        var selected = ContentItem(); selected.title = "Title"
        hero.items = [selected]
        let preserved = CatalogPresentation.sections([title, subtitle, hero], destination: ContentItem())
        XCTAssertEqual(preserved.map(\.layoutType), [.Subtitle, .Hero])
        XCTAssertEqual(preserved.first?.title, "A distinct subtitle")
    }
    func testHeaderVerticalAlignmentUsesCardBounds() {
        let action = CGRect(x: 800, y: 20, width: 190, height: 60)
        XCTAssertFalse(CatalogPresentation.verticallyAligned(source: CGRect(x: 0, y: 100, width: 300, height: 250), action: action))
        XCTAssertFalse(CatalogPresentation.verticallyAligned(source: CGRect(x: 350, y: 100, width: 300, height: 250), action: action))
        XCTAssertTrue(CatalogPresentation.verticallyAligned(source: CGRect(x: 700, y: 100, width: 300, height: 250), action: action))
    }
    func testViewAllOnlyAppearsForOverflowOrAdditionalBackendItems() throws {
        var section = try XCTUnwrap(CatalogMapper.sections( page("shows")).first { $0.title == "Weekend Wrapped" })
        XCTAssertEqual(section.items.count, 4)
        XCTAssertFalse(CatalogPresentation.showsViewAll(section, availableWidth: 1760, availableHeight: 920))
        XCTAssertTrue(CatalogPresentation.showsViewAll(section, availableWidth: 1500, availableHeight: 920))
        XCTAssertFalse(CatalogPresentation.showsViewAll(section, availableWidth: 1592, availableHeight: 920))
        section.total = 5
        XCTAssertTrue(CatalogPresentation.showsViewAll(section, availableWidth: 1760, availableHeight: 920))
        section.total = 4
        section.layoutType = .VerticalThumbnail
        XCTAssertFalse(CatalogPresentation.showsViewAll(section, availableWidth: 1760, availableHeight: 1100))
        XCTAssertTrue(CatalogPresentation.showsViewAll(section, availableWidth: 1760, availableHeight: 800))
        section.layoutType = .HorizontalSimplePoster
        XCTAssertFalse(CatalogPresentation.showsViewAll(section, availableWidth: 1760, availableHeight: 920))
        section.title = ""
        XCTAssertTrue(CatalogPresentation.showsViewAll(section, availableWidth: 900, availableHeight: 920))
    }
    func testEventBackgroundPrefersSelectedArtworkAndFallsBackToReturnedBanner() throws {
        let sections = CatalogMapper.sections( try page("azerbaijan"))
        var selected = try XCTUnwrap(sections.first { $0.layoutType == .GpBanner }?.items.first)
        let returnedArtwork = selected.pictureUrl
        selected.pictureUrl = "selected-event-artwork"
        XCTAssertTrue(CatalogPresentation.isEventDestination(selected, sections: []))
        XCTAssertEqual(CatalogPresentation.eventArtwork(selected, sections: sections), "selected-event-artwork")
        selected.pictureUrl = ""
        XCTAssertEqual(CatalogPresentation.eventArtwork(selected, sections: sections), returnedArtwork)
        XCTAssertNil(CatalogPresentation.eventArtwork(nil, sections: sections))
        XCTAssertFalse(CatalogPresentation.isEventDestination(ContentItem(), sections: []))
    }
    func testErrorHistoryPersistsDeduplicatesAndExcludesSensitiveDetails() throws {
        let suite = "errors-" + UUID().uuidString; let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSince1970: 1_000_000)
        let store = AppErrorStore(defaults: defaults, clock: { now })
        let error = NSError(domain: NSURLErrorDomain, code: -1001, userInfo: [NSLocalizedDescriptionKey: "password=secret https://stream.test/?token=private", NSURLErrorFailingURLStringErrorKey: "https://private.test/secret"])
        store.record(error, operation: .page); now.addTimeInterval(30); store.record(error, operation: .page)
        XCTAssertEqual(store.records().first?.repeatCount, 2)
        XCTAssertEqual(AppErrorStore(defaults: defaults, clock: { now }).records().count, 1)
        let data = try XCTUnwrap(defaults.data(forKey: "AppErrorHistory.v1"))
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(text.contains("secret")); XCTAssertFalse(text.contains("private")); XCTAssertFalse(text.contains("password"))
        now.addTimeInterval(61); store.record(error, operation: .page)
        XCTAssertEqual(store.records().count, 2)
        store.clear(); XCTAssertTrue(store.records().isEmpty)
        XCTAssertTrue(AppErrorStore(defaults: defaults, clock: { now }).records().isEmpty)
    }
    func testErrorHistoryRetentionLimitCancellationAndMalformedData() throws {
        let suite = "errors-" + UUID().uuidString; let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("invalid".utf8), forKey: "AppErrorHistory.v1")
        var now = Date(timeIntervalSince1970: 1_000_000)
        let store = AppErrorStore(defaults: defaults, clock: { now })
        XCTAssertTrue(store.records().isEmpty)
        store.record(URLError(.cancelled), operation: .preview)
        store.record(NSError(domain: "Application", code: 9, userInfo: [NSUnderlyingErrorKey: URLError(.cancelled)]), operation: .preview)
        XCTAssertTrue(store.records().isEmpty)
        for code in 0..<110 { now.addTimeInterval(1); store.record(NSError(domain: "untrusted-token-secret", code: code), operation: .menu, httpStatus: 403) }
        XCTAssertEqual(store.records().count, 100)
        XCTAssertEqual(store.records().first?.code, 109)
        XCTAssertEqual(store.records().first?.domain, "Application")
        XCTAssertEqual(store.records().first?.httpStatus, 403)
        now.addTimeInterval(7 * 24 * 3600 + 1); XCTAssertTrue(store.records().isEmpty)
    }
    func testCustomFailureHandlersReceiveAlreadyRecordedErrors() throws {
        let suite = "errors-" + UUID().uuidString; let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppErrorStore(defaults: defaults)
        var delivered = false
        AppErrorReporting.deliver(URLError(.badServerResponse), operation: .entitlement, httpStatus: 403, store: store) { _ in
            delivered = true
            XCTAssertEqual(store.records().first?.httpStatus, 403)
            XCTAssertEqual(store.records().first?.operation, .entitlement)
        }
        XCTAssertTrue(delivered)
    }
    func testStaleAndCancelledFailureCallbacksAreIgnored() throws {
        let suite = "errors-" + UUID().uuidString; let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppErrorStore(defaults: defaults)
        AppErrorReporting.deliver(URLError(.timedOut), operation: .preview, store: store, isCurrent: { false }) { _ in XCTFail("A released preview must not receive stale errors") }
        AppErrorReporting.deliver(URLError(.cancelled), operation: .preview, store: store) { _ in XCTFail("Expected cancellation must not show an error") }
        XCTAssertTrue(store.records().isEmpty)
    }
    func testLoadedErrorRecordsAreSanitized() throws {
        let suite = "errors-" + UUID().uuidString; let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date()
        let entry = AppErrorRecord(id: UUID(), category: .account, operation: .preview, firstTimestamp: now, lastTimestamp: now, summaryKey: "https://stream.test/?token=secret", domain: "password=secret", code: 7, httpStatus: 999, repeatCount: 1)
        defaults.set(try JSONEncoder().encode([entry]), forKey: "AppErrorHistory.v1")
        let record = try XCTUnwrap(AppErrorStore(defaults: defaults).records().first)
        XCTAssertEqual(record.category, .preview); XCTAssertEqual(record.domain, "Application")
        XCTAssertEqual(record.summaryKey, "diagnostics_summary_operation"); XCTAssertNil(record.httpStatus)
        XCTAssertFalse(String(data: try XCTUnwrap(defaults.data(forKey: "AppErrorHistory.v1")), encoding: .utf8)!.contains("secret"))
    }
    func testConcurrentErrorInsertionIsSafe() throws {
        let suite = "errors-" + UUID().uuidString; let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppErrorStore(defaults: defaults)
        DispatchQueue.concurrentPerform(iterations: 30) { _ in store.record(URLError(.timedOut), operation: .preview) }
        XCTAssertEqual(store.records().count, 1)
        XCTAssertEqual(store.records().first?.repeatCount, 30)
    }

}

@main
enum CatalogTestRunner {
    @MainActor static func main() {
        let suite = CatalogPageTests.defaultTestSuite
        suite.run()
        exit(suite.testRun?.totalFailureCount == 0 ? 0 : 1)
    }
}

import XCTest
@testable import F1Core

private actor PersonalizedCatalogFixture: AuthService, AuthorizedRequestSending, HTTPTransport {
    var requests: [URLRequest] = []
    let signedIn: Bool

    init(signedIn: Bool) { self.signedIn = signedIn }

    func account() async throws -> AccountProfile? {
        signedIn ? AccountProfile(firstName: "", lastName: "", email: "", country: "CH", subscriberID: 1, subscriptionStatus: "active") : nil
    }
    func prepareLogin(using provider: any LoginChallengeProviding) async throws -> LoginChallenge { throw APIError.authentication }
    func signIn(email: String, password: String, challenge: LoginChallenge) async throws -> AccountProfile { throw APIError.authentication }
    func signOut() async throws {}
    func subscriptionToken() async throws -> String { "subscription" }

    func authorizedData(_ request: URLRequest, mode: AuthorizationMode) async throws -> Data {
        if request.url?.path.contains("/WATCHING/") == true {
            XCTAssertEqual(mode, .dedicatedEntitlement(token: "rights", subscription: "subscription"))
        }
        return try await send(request)
    }

    func send(_ request: URLRequest) async throws -> Data {
        requests.append(request)
        let path = try XCTUnwrap(request.url?.path)
        if path.hasSuffix("/USER/ENTITLEMENT") {
            return Data(#"{"resultCode":"OK","resultObj":{"entitlementToken":"rights"}}"#.utf8)
        }
        if path.hasSuffix("/USER/LOCATION") {
            return Data(#"{"resultCode":"OK","resultObj":{"userLocation":[{"entitlement":"PRO","groupId":"42"}]}}"#.utf8)
        }
        if path.contains("/WATCHING/") {
            return Data(#"""
            {"resultCode":"OK","resultObj":{"containers":[
              {"metadata":{"contentId":123,"contentType":"VIDEO","contentSubtype":"REPLAY","duration":80},"user":{"resume":{"playHeadPosition":20}}},
              {"metadata":{"contentId":124,"contentType":"VIDEO","contentSubtype":"REPLAY","duration":"60"},"user":{"resume":{"playHeadPosition":60}}}
            ]}}
            """#.utf8)
        }
        if path.contains("/UPNEXT/") {
            return Data(#"""
            {"resultCode":"OK","resultObj":{"containers":[
              {"metadata":{"contentId":125,"contentType":"VIDEO","contentSubtype":"REPLAY","duration":80}},
              {"metadata":{"contentId":123,"contentType":"VIDEO","contentSubtype":"REPLAY"}},
              {"coverageStartTimestamp":1000000,"metadata":{"contentId":126,"contentType":"VIDEO","contentSubtype":"LIVE","interactive":false}},
              {"coverageStartTimestamp":1000000,"metadata":{"contentId":127,"contentType":"VIDEO","contentSubtype":"LIVE","locked":true}}
            ]}}
            """#.utf8)
        }
        throw APIError.invalidResponse
    }
}

final class PersonalizedCatalogTests: XCTestCase {
    private func load(signedIn: Bool) async -> ([ContentSection], [URLRequest]) {
        let fixture = PersonalizedCatalogFixture(signedIn: signedIn)
        let service = F1PersonalizedCatalog(client: APIClient(transport: fixture), endpoints: APIEndpoints(), auth: fixture)
        var featured = ContentItem()
        featured.contentId = signedIn ? "456" : "123"
        let rows = await service.homeSections(featured: featured)
        return (rows, await fixture.requests)
    }

    func testHomeReadsAccountWatchHistoryAndUsesMostRecentTitleForUpNext() async {
        let (rows, requests) = await load(signedIn: true)
        XCTAssertEqual(rows.map(\.id), [HomeCatalogRows.continueWatching, HomeCatalogRows.upNext])
        XCTAssertEqual(rows.first?.items.map(\.contentId), ["123"])
        XCTAssertEqual(rows.first?.items.first?.continuationPosition, 20)
        XCTAssertEqual(rows.first?.items.first?.watchProgress, 0.25)
        XCTAssertEqual(rows.last?.items.map(\.contentId), ["125"])
        XCTAssertEqual(requests.suffix(2).map { $0.url?.path }, [
            "/2.0/R/ENG/WEB_HLS/ALL/CONTENT/WATCHING/PRO/42",
            "/2.0/R/ENG/WEB_HLS/ALL/UPNEXT/PRO/42"
        ])
        XCTAssertEqual(requests.last?.url?.query, "contentId=123")
    }

    func testSignedOutHomeOnlyLoadsPublicSuggestions() async {
        let (rows, requests) = await load(signedIn: false)
        XCTAssertEqual(rows.map(\.id), [HomeCatalogRows.upNext])
        XCTAssertEqual(requests.map { $0.url?.path }, ["/2.0/R/ENG/WEB_HLS/ALL/UPNEXT/F1_TV_Pro_Annual/14"])
    }

    func testUpcomingCoverageUsesTheBroadcastTimestampAndWaitsForPlaybackAvailability() async throws {
        let fixture = PersonalizedCatalogFixture(signedIn: true)
        let service = F1PersonalizedCatalog(client: APIClient(transport: fixture), endpoints: APIEndpoints(), auth: fixture)
        let items = await service.upcomingStreams(for: "123")
        XCTAssertEqual(items.map(\.contentId), ["126"])
        var item = try XCTUnwrap(items.first)
        let broadcast = try XCTUnwrap(item.coverageStartsAt)
        XCTAssertEqual(broadcast, Date(timeIntervalSince1970: 1_000))
        XCTAssertNil(LiveUpNextNotice.next(in: items, excluding: [], now: broadcast.addingTimeInterval(-121)))
        XCTAssertEqual(LiveUpNextNotice.next(in: items, excluding: [], now: broadcast.addingTimeInterval(-59.2))?.state, .starting(seconds: 60))
        XCTAssertEqual(LiveUpNextNotice.next(in: items, excluding: [], now: broadcast)?.state, .waiting)
        item.interactive = true
        XCTAssertEqual(LiveUpNextNotice.next(in: [item], excluding: [], now: broadcast)?.state, .live)
        XCTAssertNil(LiveUpNextNotice.next(in: [item], excluding: ["126"], now: broadcast))
        XCTAssertNil(LiveUpNextNotice.next(in: [item], excluding: [], now: broadcast.addingTimeInterval(121)))
    }
}

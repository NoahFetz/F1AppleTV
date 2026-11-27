import XCTest
@testable import F1Core

private final class DesktopURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let status = request.url?.path == "/reject" ? 403 : 200
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("fixture".utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
private actor CapturedRegistration: HTTPTransport {
    var body: Data?
    let response: Data
    init(response: Data) { self.response = response }
    func send(_ request: URLRequest) async throws -> Data { body = request.httpBody; return response }
}
private actor RegistrationStore: SessionCredentialStore {
    var registration: DeviceRegistrationResultDto?
    func load() async throws -> DeviceRegistrationResultDto? { registration }
    func save(_ registration: DeviceRegistrationResultDto) async throws { self.registration = registration }
    func clear() async throws { registration = nil }
}
private actor PreviewBundleAuthorization: AuthorizedRequestSending {
    let response: Data
    private(set) var request: URLRequest?
    init(response: Data) { self.response = response }
    func subscriptionToken() async throws -> String { "subscription-fixture" }
    func authorizedData(_ request: URLRequest, mode: AuthorizationMode) async throws -> Data {
        self.request = request
        return response
    }
}

private actor PlaybackVersionAuthorization: AuthorizedRequestSending {
    let response: @Sendable (URLRequest) throws -> Data
    private(set) var requests: [URLRequest] = []

    init(response: @escaping @Sendable (URLRequest) throws -> Data) { self.response = response }
    func subscriptionToken() async throws -> String { "subscription-fixture" }

    func authorizedData(_ request: URLRequest, mode: AuthorizationMode) async throws -> Data {
        let authorized = try PlaybackAuthorizationHeaders.apply(to: request, subscriptionToken: "subscription-fixture",
                                                                 accountSessionID: "session-fixture", playbackSessionID: "client-fixture", mode: mode)
        requests.append(authorized)
        return try response(authorized)
    }
}

final class DesktopNetworkingTests: XCTestCase {
    private static let userRights = Data(#"{"resultCode":"OK","resultObj":{"entitlementToken":"rights-fixture"}}"#.utf8)
    private static let userLocation = Data(#"{"resultCode":"OK","resultObj":{"userLocation":[{"entitlement":"PRO","groupId":"42","registeredCountryIsoCode":"CH"}]}}"#.utf8)
    private static let stream = Data(#"{"resultCode":"OK","resultObj":{"url":"https://media.example/main.m3u8","entitlementToken":"media-fixture","channelId":12}}"#.utf8)

    func testPlayback3KeepsTheTestedAccountSessionAndPreservesFeedQuery() async throws {
        let auth = PlaybackVersionAuthorization { _ in Self.stream }
        let service = F1PlaybackService(endpoints: APIEndpoints(), auth: auth)
        let target = PlaybackTarget(uri: "CONTENT/PLAY?contentId=123&channelId=12&token=x%2By&player=stale", requiresVideoDetails: false)
        _ = try await service.entitlement(target)
        let requests = await auth.requests
        XCTAssertEqual(requests.count, 1)
        let play = try XCTUnwrap(requests.first)
        XCTAssertEqual(play.url?.absoluteString, "https://f1tv.formula1.com/3.0/R/ENG/BIG_SCREEN_HLS/ALL/CONTENT/PLAY?contentId=123&channelId=12&token=x%2By&player=player_bm")
        XCTAssertEqual(play.value(forHTTPHeaderField: "entitlementtoken"), "session-fixture")
    }

    func testPlayback3RetriesRightsRejectionWithTheDedicatedToken() async throws {
        let auth = PlaybackVersionAuthorization { request in
            if request.url?.path.hasSuffix("/USER/ENTITLEMENT") == true { return Self.userRights }
            if request.value(forHTTPHeaderField: "entitlementtoken") == "session-fixture" { throw APIError.http(404) }
            return Self.stream
        }
        let service = F1PlaybackService(endpoints: APIEndpoints(), auth: auth)
        let stream = try await service.entitlement(.init(uri: "123", requiresVideoDetails: false))
        XCTAssertEqual(stream.entitlementToken, "media-fixture")
        let requests = await auth.requests
        XCTAssertEqual(requests.count, 3)
        let lookup = try XCTUnwrap(requests.dropFirst().first)
        XCTAssertEqual(lookup.url?.path, "/2.0/R/ENG/BIG_SCREEN_HLS/ALL/USER/ENTITLEMENT")
        XCTAssertEqual(lookup.value(forHTTPHeaderField: "ascendontoken"), "subscription-fixture")
        XCTAssertNil(lookup.value(forHTTPHeaderField: "entitlementtoken"))
        XCTAssertEqual(requests.first?.url, requests.last?.url)
        XCTAssertEqual(requests.last?.value(forHTTPHeaderField: "entitlementtoken"), "rights-fixture")
    }

    func testVideo4UsesAccountRightsAndFallsBackToVideo3OnUnavailableDetails() async throws {
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture = try Data(contentsOf: repository.appendingPathComponent("Tests/Fixtures/Backend/video.json"))
        for unavailable in [false, true] {
            let auth = PlaybackVersionAuthorization { request in
                let path = request.url?.path ?? ""
                if path.hasSuffix("/USER/ENTITLEMENT") { return Self.userRights }
                if path.hasSuffix("/USER/LOCATION") { return Self.userLocation }
                if unavailable && path.hasPrefix("/4.0/") { throw APIError.http(404) }
                return fixture
            }
            let service = F1PlaybackService(endpoints: APIEndpoints(), auth: auth)
            let video = try await service.video("123")
            XCTAssertEqual(video.channels.count, 3)
            let requests = await auth.requests
            XCTAssertEqual(requests.count, unavailable ? 4 : 3)
            XCTAssertEqual(requests.dropFirst().first?.url?.path, "/1.0/R/ENG/BIG_SCREEN_HLS/ALL/USER/LOCATION")
            XCTAssertEqual(requests.dropFirst().first?.value(forHTTPHeaderField: "entitlementtoken"), "rights-fixture")
            let video4 = requests.dropFirst(2).first
            XCTAssertEqual(video4?.url?.absoluteString, "https://f1tv.formula1.com/4.0/R/ENG/BIG_SCREEN_HLS/ALL/CONTENT/VIDEO/123/PRO/42?homeCountry=CH")
            XCTAssertEqual(video4?.value(forHTTPHeaderField: "entitlementtoken"), "rights-fixture")
            if unavailable {
                XCTAssertEqual(requests.last?.url?.path, "/3.0/R/ENG/BIG_SCREEN_HLS/ALL/CONTENT/VIDEO/123/F1_TV_Pro_Annual/14")
                XCTAssertEqual(requests.last?.value(forHTTPHeaderField: "entitlementtoken"), "subscription-fixture")
            }
        }
    }

    func testDedicatedTokenCannotBeSentAfterSubscriptionChanges() throws {
        let request = APIEndpoints().userLocation()
        XCTAssertThrowsError(try PlaybackAuthorizationHeaders.apply(to: request, subscriptionToken: "new-subscription",
                                                                      accountSessionID: "new-session", playbackSessionID: "client-fixture",
                                                                      mode: .dedicatedEntitlement(token: "old-rights", subscription: "old-subscription"))) {
            XCTAssertTrue($0 is CancellationError)
        }
    }

    func testPreviewBundleUsesPlayerTMAndMatchesIndividualChannels() async throws {
        let response = Data(#"""
        {"resultCode":"OK","resultObj":{
          "channelId":1025,"entitlementToken":"bundle-fixture","tme":{
            "metadata":{"content_id":123},"feeds":[
              {"uuid":"main","metadata":{"channel_id":1025},"url":"https://media.example/main.m3u8"},
              {"uuid":"alternate","metadata":{"channel_id":"1033"},"url":"https://media.example/alternate.m3u8?signed=fixture"},
              {"metadata":{"channel_id":1034},"url":"https://media.example/unsupported.mpd"},
              {"metadata":{"channel_id":1035},"url":42},
              {"metadata":{"channel_id":1036},"url":"http://media.example/insecure.m3u8"}
            ],"composite_feeds":[{"url":"https://media.example/composite.m3u8","sub_feeds":[
              {"uuid":"main","norm_rect":{"offset_x":0,"offset_y":0.25,"width":0.5,"height":0.25}},
              {"uuid":"alternate","norm_rect":{"offset_x":0.75,"offset_y":0,"width":0.5,"height":0.5}},
              {"uuid":"unlisted","norm_rect":{"offset_x":0,"offset_y":0,"width":0.5,"height":0.5}}
            ]}]
          }
        }}
        """#.utf8)
        let auth = PreviewBundleAuthorization(response: response)
        let service = F1PlaybackService(endpoints: APIEndpoints(), auth: auth)
        let bundle = try await service.previewFeedBundle(contentID: "123")
        let recordedRequest = await auth.request
        let request = try XCTUnwrap(recordedRequest)
        XCTAssertEqual(request.url?.absoluteString, "https://f1tv.formula1.com/3.0/R/ENG/BIG_SCREEN_HLS/ALL/CONTENT/PLAY?contentId=123&player=player_tm")
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-f1-device-info"), APIEndpoints.deviceInfo)
        let main = PlaybackChannel(id: "main:123", target: .init(uri: "123", requiresVideoDetails: false),
                                   kind: .MainFeed, contentID: "123", title: "International")
        XCTAssertEqual(bundle.entitlement(for: main)?.channelID, "1025")
        let composite = try XCTUnwrap(bundle.composite)
        XCTAssertEqual(composite.url.absoluteString, "https://media.example/composite.m3u8")
        XCTAssertEqual(composite.videoRects, ["1025": CGRect(x: 0, y: 0.5, width: 0.5, height: 0.25)])
        func alternate(_ id: String, contentID: String = "123") -> PlaybackChannel {
            PlaybackChannel(id: id, target: .init(uri: "CONTENT/PLAY?contentId=\(contentID)&channelId=\(id)", requiresVideoDetails: false),
                            kind: .AdditionalFeed, contentID: contentID, title: "Alternate")
        }
        XCTAssertEqual(bundle.entitlement(for: alternate("1033"))?.url, "https://media.example/alternate.m3u8?signed=fixture")
        for channelID in ["1034", "1035", "1036", "9999"] {
            XCTAssertNil(bundle.entitlement(for: alternate(channelID)))
        }
        XCTAssertNil(bundle.entitlement(for: alternate("1033", contentID: "456")))
        XCTAssertThrowsError(try APIEndpoints().previewFeedBundle("123&channelId=1025"))
    }

    @MainActor
    func testPreviewFallbackReusesTheCompositeBundleAndRequestsIndividualPlaybackOnFailure() async throws {
        let bundled = PlaybackEntitlement(url: "https://media.example/bundled.m3u8", channelID: "12",
                                          drmType: nil, licenseURL: nil, entitlementToken: "bundle")
        let individual = PlaybackEntitlement(url: "https://media.example/individual.m3u8", channelID: "12",
                                             drmType: nil, licenseURL: nil, entitlementToken: "individual")
        let channel = PlaybackChannel(id: "main:123", target: .init(uri: "123", requiresVideoDetails: false),
                                      kind: .MainFeed, contentID: "123", title: "International")
        var bundleRequests = 0
        var individualRequests = 0
        let loader = PreviewFeedLoader { id in
            bundleRequests += 1
            return PreviewFeedBundle(contentID: id, defaultChannelID: "12", feeds: ["12": bundled], composite: nil)
        }
        let loadIndividual = { individualRequests += 1; return individual }
        _ = await loader.bundle(for: "123")
        let usesBundle = try await loader.prepare(channel: channel, individual: loadIndividual) { entitlement, _ in
            XCTAssertEqual(entitlement.url, bundled.url)
        }
        XCTAssertTrue(usesBundle)
        XCTAssertEqual(individualRequests, 0)
        var attempted: [String] = []
        let usesFallback = try await loader.prepare(channel: channel, individual: loadIndividual) { entitlement, _ in
            attempted.append(entitlement.url)
            if entitlement.url == bundled.url { throw APIError.invalidPlayback }
        }
        XCTAssertFalse(usesFallback)
        XCTAssertEqual(attempted, [bundled.url, individual.url])
        XCTAssertEqual(bundleRequests, 1)
        XCTAssertEqual(individualRequests, 1)
    }

    func testDirectPlaybackPreservesCatalogTargetAndSkipsVideoDetails() async throws {
        let auth = PlaybackVersionAuthorization { _ in throw APIError.invalidResponse }
        let service = F1PlaybackService(endpoints: APIEndpoints(), auth: auth)
        let target = PlaybackTarget(uri: "CONTENT/PLAY?contentId=123&channelId=12", requiresVideoDetails: false)
        var item = ContentItem()
        item.objectType = .Video
        item.contentId = "123"
        item.action = .playback(target)
        item.title = "Replay highlights"
        item.resumePosition = 25
        let start = try await service.resolveStart(for: item)
        guard case .direct(_, let channel) = start else { return XCTFail("Expected direct playback") }
        XCTAssertEqual(channel.target, target)
        XCTAssertEqual(start.details.channels.first?.resumePosition, 25)
        let requests = await auth.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testPreviewBundleRejectsProtectedAndWrongContentResponses() async {
        for field in [#""drmType":"fairplay","#, #""laURL":"https://media.example/license","#, ""] {
            let item = field.isEmpty ? 456 : 123
            let response = Data(#"""
            {"resultCode":"OK","resultObj":{
              \#(field) "channelId":1025,"entitlementToken":"bundle-fixture","tme":{
                "metadata":{"content_id":\#(item)},"feeds":[
                  {"metadata":{"channel_id":1025},"url":"https://media.example/main.m3u8"}
                ]
              }
            }}
            """#.utf8)
            let auth = PreviewBundleAuthorization(response: response)
            let service = F1PlaybackService(endpoints: APIEndpoints(), auth: auth)
            do {
                _ = try await service.previewFeedBundle(contentID: "123")
                XCTFail("Expected this bundle to fall back to per-feed playback")
            } catch {
                XCTAssertEqual(error as? APIError, .invalidPlayback)
            }
        }
    }


    func testNativeTransportValidatesHTTPStatus() async throws {
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [DesktopURLProtocol.self]
        let session = URLSession(configuration: configuration); defer { session.invalidateAndCancel() }
        let transport = URLSessionHTTPTransport(session: session)
        let value = try await transport.send(URLRequest(url: URL(string: "https://fixture.example/success")!))
        XCTAssertEqual(value, Data("fixture".utf8))
        do { _ = try await transport.send(URLRequest(url: URL(string: "https://fixture.example/reject")!)); XCTFail("HTTP rejection must propagate") }
        catch { XCTAssertEqual(error as? APIError, .http(403)) }
    }
    func testMacRegistrationUsesInjectedIdentityAndExistingBackendCodes() async throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let response = try Data(contentsOf: repo.appendingPathComponent("Tests/Fixtures/Backend/registration.json"))
        let transport = CapturedRegistration(response: response), store = RegistrationStore()
        let auth = F1AuthService(client: APIClient(transport: transport), endpoints: APIEndpoints(), storage: store, nickname: "Vroom TV macOS", deviceFactory: {
            DeviceRegistrationRequestDeviceDto(deviceTypeCode: 12, deviceId: "fixture-macOS", physicalDeviceTypeCode: 1002)
        })
        _ = try await auth.signIn(email: "fixture@example.invalid", password: "fixture", challenge: LoginChallenge("fixture"))
        let bodyData = await transport.body
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(bodyData)) as? [String: Any])
        let device = try XCTUnwrap(body["PhysicalDevice"] as? [String: Any])
        XCTAssertEqual(body["Nickname"] as? String, "Vroom TV macOS")
        XCTAssertEqual(device["DeviceId"] as? String, "fixture-macOS")
        XCTAssertEqual(device["DeviceTypeCode"] as? Int, 12)
        XCTAssertEqual(device["PhysicalDeviceTypeCode"] as? Int, 1002)
        let stored = try await store.load(); XCTAssertNotNil(stored)
    }
    func testSharedLocalizationLoadsPackageResources() {
        XCTAssertNotEqual("settings_title".localizedString, "settings_title")
    }
}

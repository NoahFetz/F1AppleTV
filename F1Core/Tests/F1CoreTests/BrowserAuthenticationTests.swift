import XCTest
@testable import F1Core

private let completedWebSession = Data(#"{"SessionId":"web-session","Subscriber":{"FirstName":"Fixture","LastName":"Account","Email":"fixture@example.invalid","Id":42,"HomeCountry":"CH"},"data":{"subscriptionToken":"web-token","subscriptionStatus":"active"}}"#.utf8)
private actor BrowserMemoryStore: BrowserSessionCredentialStore {
    var value: BrowserAccountSession?
    var saveError = false
    var holdSave = false
    var waiting: CheckedContinuation<Void, Never>?
    func load() async throws -> BrowserAccountSession? { value }
    func save(_ session: BrowserAccountSession) async throws {
        if saveError { throw APIError.transport(-1) }
        if holdSave { await withCheckedContinuation { waiting = $0 } }
        value = session
    }
    func hold() { holdSave = true }
    func release() { holdSave = false; waiting?.resume(); waiting = nil }
    var saving: Bool { waiting != nil }
    func clear() async throws { value = nil }
    func failSaves() { saveError = true }
}
private actor FallbackMemoryStore: SessionCredentialStore {
    var value: DeviceRegistrationResultDto?
    func load() async throws -> DeviceRegistrationResultDto? { value }
    func save(_ registration: DeviceRegistrationResultDto) async throws { value = registration }
    func clear() async throws { value = nil }
}
private actor BrowserTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var holdRefresh = false
    var waiting: CheckedContinuation<Void, Never>?
    func send(_ request: URLRequest) async throws -> Data {
        requests.append(request)
        if request.url?.path.contains("RegisterDevice") == true {
            let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            return try Data(contentsOf: repo.appendingPathComponent("Tests/Fixtures/Backend/registration.json"))
        }
        if request.url?.path.contains("UnregisterDevice") == true { throw APIError.http(503) }
        if request.url?.path.contains("RetrieveSubscriber") == true {
            if holdRefresh { await withCheckedContinuation { waiting = $0 } }
            return Data(#"{"data":{"subscriptionToken":"renewed-token","subscriptionStatus":"active"}}"#.utf8)
        }
        if request.value(forHTTPHeaderField: "ascendontoken") == "web-token" && request.url?.path == "/refresh" { throw APIError.http(401) }
        return Data("success".utf8)
    }
    func hold() { holdRefresh = true }
    func release() { waiting?.resume(); waiting = nil }
    var refreshing: Bool { waiting != nil }
}
final class BrowserAuthenticationTests: XCTestCase {
    private func services(_ transport: BrowserTransport = BrowserTransport(), store: BrowserMemoryStore = BrowserMemoryStore(), fallbackStore: FallbackMemoryStore = FallbackMemoryStore()) -> (F1BrowserAuthService, F1AuthService) {
        let client = APIClient(transport: transport), endpoints = APIEndpoints()
        let fallback = F1AuthService(client: client, endpoints: endpoints, storage: fallbackStore)
        return (F1BrowserAuthService(fallback: fallback, client: client, endpoints: endpoints, store: store), fallback)
    }
    func testCompletedBrowserSessionPreservesProfileAndOpaqueToken() throws {
        let session = try BrowserAccountSession.decode(completedWebSession)
        XCTAssertEqual(session.sessionID, "web-session"); XCTAssertEqual(session.profile.subscriberID, 42)
        XCTAssertTrue(session.profile.hasSubscription)
        XCTAssertEqual(try JSONDecoder().decode(BrowserAccountSession.self, from: JSONEncoder().encode(session)), session)
        let renewal = try BrowserAccountSession.decode(Data(#"{"data":{"subscriptionToken":"new"}}"#.utf8), previous: session)
        XCTAssertEqual(renewal.sessionID, session.sessionID); XCTAssertEqual(renewal.profile, session.profile)
    }
    func testIncompleteBrowserSessionsAreRejected() {
        for value in [#"{"data":{"subscriptionToken":""}}"#, #"{"Subscriber":{"Id":1},"data":{"subscriptionToken":"token"}}"#, #"{"SessionId":"id","data":{"subscriptionToken":"token"}}"#] {
            XCTAssertThrowsError(try BrowserAccountSession.decode(Data(value.utf8)))
        }
    }
    func testBrowserRequestsReuseAuthorizationPolicyAndRefreshOnce() async throws {
        let transport = BrowserTransport(); let (auth, _) = services(transport)
        _ = try await auth.accept(BrowserAccountSession.decode(completedWebSession))
        let request = URLRequest(url: URL(string: "https://fixture.example/refresh")!)
        _ = try await auth.authorizedData(request, mode: .entitlement)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "ascendontoken"), "web-token")
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "entitlementtoken"), "web-session")
        XCTAssertNotNil(requests[0].value(forHTTPHeaderField: "sessionId").flatMap(UUID.init(uuidString:)))
        XCTAssertEqual(requests[1].url?.path, "/v1/account/Subscriber/RetrieveSubscriber")
        XCTAssertNil(requests[1].value(forHTTPHeaderField: "ascendontoken"))
        XCTAssertEqual(requests[1].value(forHTTPHeaderField: "CD-SessionID"), "web-session")
        XCTAssertEqual(requests[2].value(forHTTPHeaderField: "ascendontoken"), "renewed-token")
        let token = try await auth.subscriptionToken(); XCTAssertEqual(token, "renewed-token")
    }
    func testBrowserLogoutClearsSupersededFallbackDespiteRemoteFailure() async throws {
        let transport = BrowserTransport(), store = BrowserMemoryStore(), fallbackStore = FallbackMemoryStore()
        let (auth, fallback) = services(transport, store: store, fallbackStore: fallbackStore)
        _ = try await fallback.signIn(email: "fixture@example.invalid", password: "fixture", challenge: LoginChallenge("fixture"))
        _ = try await auth.accept(BrowserAccountSession.decode(completedWebSession))
        try await auth.signOut()
        let account = try await auth.account(), browser = try await store.load(), fallbackValue = try await fallbackStore.load()
        XCTAssertNil(account); XCTAssertNil(browser); XCTAssertNil(fallbackValue)
    }
    func testRefreshCompletingAfterLogoutCannotResurrectBrowserSession() async throws {
        let transport = BrowserTransport(), store = BrowserMemoryStore(); let (auth, _) = services(transport, store: store)
        _ = try await auth.accept(BrowserAccountSession.decode(completedWebSession)); await transport.hold()
        let work = Task { try await auth.authorizedData(URLRequest(url: URL(string: "https://fixture.example/refresh")!), mode: .entitlement) }
        for _ in 0..<100 { if await transport.refreshing { break }; try await Task.sleep(nanoseconds: 10_000_000) }
        let refreshing = await transport.refreshing; XCTAssertTrue(refreshing)
        try await auth.signOut(); await transport.release()
        do { _ = try await work.value; XCTFail("Stale refresh should be cancelled") } catch { XCTAssertTrue(error is CancellationError) }
        let account = try await auth.account(), stored = try await store.load(); XCTAssertNil(account); XCTAssertNil(stored)
    }
    func testFailedPersistenceDoesNotPublishBrowserSession() async throws {
        let store = BrowserMemoryStore(); await store.failSaves(); let (auth, _) = services(store: store)
        do { _ = try await auth.accept(BrowserAccountSession.decode(completedWebSession)); XCTFail("Keychain failure should propagate") } catch {}
        let account = try await auth.account(); XCTAssertNil(account)
    }
    func testCancelledBrowserAcceptanceClearsAnInFlightCredentialWrite() async throws {
        let store = BrowserMemoryStore(); await store.hold(); let (auth, _) = services(store: store)
        let work = Task { try await auth.accept(BrowserAccountSession.decode(completedWebSession)) }
        for _ in 0..<100 { if await store.saving { break }; try await Task.sleep(nanoseconds: 10_000_000) }
        let saving = await store.saving; XCTAssertTrue(saving)
        work.cancel(); await store.release()
        do { _ = try await work.value; XCTFail("Cancelled acceptance must fail") } catch { XCTAssertTrue(error is CancellationError) }
        let stored = try await store.load(), account = try await auth.account(); XCTAssertNil(stored); XCTAssertNil(account)
    }
    func testDiscardingLegacyBrowserSessionAlsoClearsTheSupersededRegistration() async throws {
        let store = BrowserMemoryStore(), fallbackStore = FallbackMemoryStore()
        let (auth, fallback) = services(store: store, fallbackStore: fallbackStore)
        _ = try await fallback.signIn(email: "fixture@example.invalid", password: "fixture", challenge: LoginChallenge("fixture"))
        _ = try await auth.accept(BrowserAccountSession.decode(completedWebSession))
        try await auth.discardStoredSession()
        let account = try await auth.account(), browser = try await store.load(), registration = try await fallbackStore.load()
        XCTAssertNil(account); XCTAssertNil(browser); XCTAssertNil(registration)
    }
    func testConcurrentUnauthorizedRequestsShareOneRefresh() async throws {
        let transport = BrowserTransport(); let (auth, _) = services(transport)
        _ = try await auth.accept(BrowserAccountSession.decode(completedWebSession)); await transport.hold()
        let request = URLRequest(url: URL(string: "https://fixture.example/refresh")!)
        let first = Task { try await auth.authorizedData(request, mode: .entitlement) }
        for _ in 0..<100 { if await transport.refreshing { break }; try await Task.sleep(nanoseconds: 10_000_000) }
        let second = Task { try await auth.authorizedData(request, mode: .entitlement) }
        for _ in 0..<100 {
            if await transport.requests.filter({ $0.url?.path == "/refresh" }).count >= 2 { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        await transport.release(); _ = try await first.value; _ = try await second.value
        let requests = await transport.requests
        XCTAssertEqual(requests.filter { $0.url?.path.contains("RetrieveSubscriber") == true }.count, 1)
        XCTAssertEqual(requests.filter { $0.value(forHTTPHeaderField: "ascendontoken") == "renewed-token" }.count, 2)
    }

}

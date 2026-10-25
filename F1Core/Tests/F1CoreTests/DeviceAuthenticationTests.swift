import XCTest
@testable import F1Core

private final class DeviceClock: @unchecked Sendable {
    private let lock = NSLock()
    private var time = Date(timeIntervalSince1970: 2_000_000_000)
    private(set) var delays: [Double] = []
    func now() -> Date { lock.lock(); defer { lock.unlock() }; return time }
    func advance(_ seconds: Double) { lock.lock(); defer { lock.unlock() }; delays.append(seconds); time.addTimeInterval(seconds) }
}
private actor DeviceMemoryStore: DeviceSessionCredentialStore {
    var value: DeviceAccountSession?
    var holdSave = false
    var waiting: CheckedContinuation<Void, Never>?
    var failSave = false
    func load() async throws -> DeviceAccountSession? { value }
    func save(_ value: DeviceAccountSession) async throws {
        if failSave { throw APIError.transport(-1) }
        if holdSave { await withCheckedContinuation { waiting = $0 } }
        self.value = value
    }
    func clear() async throws { value = nil }
    func hold() { holdSave = true }
    func release() { holdSave = false; waiting?.resume(); waiting = nil }
    var saving: Bool { waiting != nil }
    func fail() { failSave = true }
}
private actor DeviceLegacyStore: SessionCredentialStore {
    func load() async throws -> DeviceRegistrationResultDto? { nil }
    func save(_ registration: DeviceRegistrationResultDto) async throws {}
    func clear() async throws {}
}
private actor DeviceAPITransport: HTTPTransport {
    var requests: [URLRequest] = []
    var rejections = 0
    func failOnce() { rejections = 1 }
    func failNext(_ count: Int) { rejections = count }
    func send(_ request: URLRequest) async throws -> Data {
        requests.append(request)
        if rejections > 0 { rejections -= 1; throw APIError.http(401) }
        return Data("ok".utf8)
    }
}
private actor DeviceOAuthTransport: DeviceAuthTransport {
    var responses: [DeviceAuthResponse]
    var requests: [URLRequest] = []
    var held = false
    var waiting: CheckedContinuation<Void, Never>?
    init(_ responses: [DeviceAuthResponse]) { self.responses = responses }
    func send(_ request: URLRequest) async throws -> DeviceAuthResponse {
        requests.append(request)
        if held { await withCheckedContinuation { waiting = $0 } }
        guard !responses.isEmpty else { throw APIError.invalidResponse }
        return responses.removeFirst()
    }
    func hold() { held = true }
    var working: Bool { waiting != nil }
    func release() { held = false; waiting?.resume(); waiting = nil }
}

final class DeviceAuthenticationTests: XCTestCase {
    private func response(_ value: [String: Any], status: Int = 200) -> DeviceAuthResponse {
        DeviceAuthResponse(status: status, data: try! JSONSerialization.data(withJSONObject: value))
    }
    private func challenge(expires: Int = 600, url: String = "https://f1.com/pair") -> DeviceAuthResponse {
        response(["device_code":"private-device-code", "user_code":"ABCD-EFGH", "verification_uri":url,
                  "verification_uri_complete":url + "?user_code=ABCD-EFGH", "expires_in":expires, "interval":5])
    }
    private func jwt(_ claims: [String: Any]) -> String {
        let body = try! JSONSerialization.data(withJSONObject: claims).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return "eyJhbGciOiJmaXh0dXJlIn0.\(body).fixture"
    }
    private func tokens(_ clock: DeviceClock, session: String = "playback-session", refresh: String? = "refresh+one/token=") -> DeviceAuthResponse {
        let subscription = jwt(["SessionId":session,"SubscriberId":"42","FirstName":"Fixture","LastName":"Account", "SubscriptionStatus":"active", "exp":clock.now().timeIntervalSince1970 + 3600])
        var value: [String: Any] = ["access_token":jwt(["subscriptionToken":subscription]),"token_type":"Bearer","expires_in":3600]
        if let refresh { value["refresh_token"] = refresh }
        return response(value)
    }
    private func service(_ oauth: DeviceOAuthTransport, _ clock: DeviceClock, store: DeviceMemoryStore = DeviceMemoryStore(), api: DeviceAPITransport = DeviceAPITransport(), wait: (@Sendable (Double) async throws -> Void)? = nil) -> F1DeviceAuthService {
        let client = APIClient(transport: api)
        return F1DeviceAuthService(client: client, fallback: F1AuthService(client: client, endpoints: APIEndpoints(), storage: DeviceLegacyStore()), store: store,
                                   transport: oauth, now: { clock.now() }, wait: wait ?? { clock.advance($0) })
    }
    private func body(_ request: URLRequest) -> [String: String] {
        URLComponents(string: "https://fixture.invalid/?" + String(data: request.httpBody!, encoding: .utf8)!)!.queryItems!.reduce(into: [:]) { $0[$1.name] = $1.value }
    }
    func testDeviceAuthorizationUsesPublicTVClientAndProviderQRURL() async throws {
        let clock = DeviceClock(), oauth = DeviceOAuthTransport([challenge()])
        let value = try await service(oauth, clock).beginSignIn()
        XCTAssertEqual(value.userCode, "ABCD-EFGH")
        XCTAssertEqual(value.qrCodeURL.absoluteString, "https://f1.com/pair?user_code=ABCD-EFGH")
        XCTAssertEqual(value.expiresAt.timeIntervalSince(clock.now()), 600)
        let requests = await oauth.requests
        XCTAssertEqual(requests[0].url?.absoluteString, "https://id.formula1.com/as/device_authorization")
        XCTAssertEqual(body(requests[0]), ["client_id":F1DeviceAuthService.clientID,"scope":"openid f1tv_groups"])
        XCTAssertNil(requests[0].value(forHTTPHeaderField: "Authorization"))
    }
    func testUntrustedAndInsecureVerificationURLsAreRejected() async throws {
        for url in ["https://formula1.com.attacker.invalid/pair", "http://f1.com/pair", "https://user@f1.com/pair"] {
            let oauth = DeviceOAuthTransport([challenge(url: url)])
            do { _ = try await service(oauth, DeviceClock()).beginSignIn(); XCTFail("Untrusted QR URL") }
            catch { XCTAssertEqual(error as? DeviceSignInError, .invalidResponse) }
        }
    }
    func testPendingAndSlowDownHonorProviderIntervalsThenPersistPlaybackSession() async throws {
        let clock = DeviceClock(), store = DeviceMemoryStore()
        let oauth = DeviceOAuthTransport([challenge(),response(["error":"authorization_pending"],status:400),response(["error":"slow_down"],status:400),tokens(clock)])
        let auth = service(oauth, clock, store: store)
        let profile = try await auth.completeSignIn(auth.beginSignIn())
        XCTAssertEqual(clock.delays, [5,5,10]); XCTAssertTrue(profile.hasSubscription)
        XCTAssertEqual(profile.subscriberID, 42); XCTAssertEqual(profile.email, "")
        let saved = try await store.load(); XCTAssertNotNil(saved)
        let requests = await oauth.requests
        XCTAssertEqual(body(requests.last!)["device_code"], "private-device-code")
        XCTAssertEqual(body(requests.last!)["grant_type"], "urn:ietf:params:oauth:grant-type:device_code")
    }
    func testBrowserCompletionRequestsTokensWithoutAnInitialPollingWait() async throws {
        let clock = DeviceClock(), store = DeviceMemoryStore(), oauth = DeviceOAuthTransport([challenge(), tokens(DeviceClock())])
        let auth = service(oauth, clock, store: store)
        let authorization = try await auth.beginSignIn()
        let profile = try await auth.completeBrowserSignIn(authorization)
        XCTAssertTrue(profile.hasSubscription); XCTAssertEqual(clock.delays, [])
        let saved = try await store.load(); XCTAssertNotNil(saved)
    }
    func testBrowserCompletionStillHonorsPendingAndSlowDownIntervals() async throws {
        let clock = DeviceClock(), oauth = DeviceOAuthTransport([challenge(), response(["error":"authorization_pending"], status:400),
                                                              response(["error":"slow_down"], status:400), tokens(DeviceClock())])
        let auth = service(oauth, clock)
        _ = try await auth.completeBrowserSignIn(auth.beginSignIn())
        XCTAssertEqual(clock.delays, [5, 10])
    }
    func testExpiredOrSupersededBrowserApprovalCannotRequestTokens() async throws {
        let clock = DeviceClock(), oauth = DeviceOAuthTransport([challenge(), challenge()]), auth = service(oauth, clock)
        let old = try await auth.beginSignIn(), current = try await auth.beginSignIn()
        do { _ = try await auth.completeBrowserSignIn(old); XCTFail("Superseded approval") }
        catch { XCTAssertTrue(error is CancellationError) }
        clock.advance(600)
        do { _ = try await auth.completeBrowserSignIn(current); XCTFail("Expired approval") }
        catch { XCTAssertEqual(error as? DeviceSignInError, .expired) }
        let requests = await oauth.requests; XCTAssertEqual(requests.count, 2)
    }
    func testExpiredCodeStopsPollingAtTheDeadline() async throws {
        let clock = DeviceClock(), oauth = DeviceOAuthTransport([challenge(expires: 10),response(["error":"authorization_pending"],status:400)])
        let auth = service(oauth, clock)
        do { _ = try await auth.completeSignIn(auth.beginSignIn()); XCTFail("Code must expire") }
        catch { XCTAssertEqual(error as? DeviceSignInError, .expired) }
        let requests = await oauth.requests; XCTAssertEqual(requests.count, 2)
    }
    func testProviderDenialAndExpiryAreActionable() async throws {
        for (code, expected) in [("access_denied",DeviceSignInError.denied),("expired_token",.expired),("invalid_client",.rejected)] {
            let clock = DeviceClock(), oauth = DeviceOAuthTransport([challenge(),response(["error":code],status:400)]), store = DeviceMemoryStore()
            let auth = service(oauth, clock, store: store)
            do { _ = try await auth.completeSignIn(auth.beginSignIn()); XCTFail("Provider rejection") }
            catch { XCTAssertEqual(error as? DeviceSignInError, expected) }
            let saved = try await store.load(); XCTAssertNil(saved)
        }
    }
    func testGettingANewCodeInvalidatesPreviousPoll() async throws {
        let clock = DeviceClock(), oauth = DeviceOAuthTransport([challenge(),challenge()])
        let auth = service(oauth, clock), old = try await auth.beginSignIn()
        _ = try await auth.beginSignIn()
        do { _ = try await auth.completeSignIn(old); XCTFail("Old code must be ignored") }
        catch { XCTAssertTrue(error is CancellationError) }
        let requests = await oauth.requests; XCTAssertEqual(requests.count, 2)
    }
    func testCancellationDuringPollDoesNotRequestOrPersistTokens() async throws {
        let clock = DeviceClock(), oauth = DeviceOAuthTransport([challenge()]), store = DeviceMemoryStore()
        let auth = service(oauth, clock, store: store, wait: { _ in try await Task.sleep(nanoseconds: 5_000_000_000) })
        let challenge = try await auth.beginSignIn()
        let task = Task { try await auth.completeSignIn(challenge) }; task.cancel()
        do { _ = try await task.value; XCTFail("Canceled poll") } catch { XCTAssertTrue(error is CancellationError) }
        let saved = try await store.load(), requests = await oauth.requests
        XCTAssertNil(saved); XCTAssertEqual(requests.count, 1)
    }
    func testPlaybackUsesEmbeddedSubscriptionAndAccountSession() async throws {
        let clock = DeviceClock(), oauth = DeviceOAuthTransport([challenge(),tokens(clock)]), api = DeviceAPITransport()
        let auth = service(oauth, clock, api: api)
        _ = try await auth.completeSignIn(auth.beginSignIn())
        _ = try await auth.authorizedData(URLRequest(url: URL(string: "https://fixture.invalid/video")!), mode: .video)
        _ = try await auth.authorizedData(URLRequest(url: URL(string: "https://fixture.invalid/play")!), mode: .entitlement)
        let requests = await api.requests
        let subscription = try await auth.subscriptionToken()
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "entitlementtoken"), subscription)
        XCTAssertEqual(requests[1].value(forHTTPHeaderField: "entitlementtoken"), "playback-session")
        XCTAssertEqual(requests[1].value(forHTTPHeaderField: "ascendontoken"), subscription)
        XCTAssertNil(requests[1].value(forHTTPHeaderField: "Authorization"))
    }
    func testRefreshRotatesAndFormEncodesRefreshTokens() async throws {
        let clock = DeviceClock(), oauth = DeviceOAuthTransport([challenge(),tokens(clock)]), store = DeviceMemoryStore()
        let auth = service(oauth, clock, store: store)
        _ = try await auth.completeSignIn(auth.beginSignIn())
        clock.advance(3590)
        // A new service simulates an app relaunch with expired persisted credentials.
        let renewing = DeviceOAuthTransport([tokens(clock, session: "renewed", refresh: "rotated+token")])
        let relaunched = service(renewing, clock, store: store)
        _ = try await relaunched.subscriptionToken()
        let requests = await renewing.requests
        XCTAssertEqual(body(requests[0])["refresh_token"], "refresh+one/token=")
        let saved = try await store.load()
        XCTAssertEqual(saved?.refreshToken, "rotated+token"); XCTAssertEqual(saved?.playback.sessionID, "renewed")
    }
    func testUnauthorizedPlaybackRefreshesOnceAndReportingDoesNotReplay() async throws {
        let clock = DeviceClock(), oauth = DeviceOAuthTransport([challenge(),tokens(clock),tokens(clock,session:"renewed")]), api = DeviceAPITransport()
        let auth = service(oauth, clock, api: api)
        _ = try await auth.completeSignIn(auth.beginSignIn()); await api.failOnce()
        let request = URLRequest(url: URL(string: "https://fixture.invalid/play")!)
        _ = try await auth.authorizedData(request, mode: .entitlement)
        let requests = await api.requests; XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.last?.value(forHTTPHeaderField: "entitlementtoken"), "renewed")
        await api.failOnce()
        do { _ = try await auth.authorizedData(request, mode: .reporting); XCTFail("Reporting should not replay") }
        catch { XCTAssertEqual(error as? APIError, .http(401)) }
        let polls = await oauth.requests; XCTAssertEqual(polls.count, 3)
    }
    func testMalformedTokensAndPersistenceFailuresDoNotPublishAnAccount() async throws {
        let clock = DeviceClock()
        XCTAssertThrowsError(try DeviceAccountSession.decode(response(["access_token":"opaque","token_type":"Bearer","expires_in":3600,"refresh_token":"fixture"]).data, now:clock.now()))
        let store = DeviceMemoryStore(); await store.fail()
        let auth = service(DeviceOAuthTransport([challenge(),tokens(clock)]),clock,store:store)
        do { _ = try await auth.completeSignIn(auth.beginSignIn()); XCTFail("Storage failure") } catch {}
        let account = try await auth.account(); XCTAssertNil(account)
    }
    func testCancellationDuringCredentialWriteClearsTheCompletedWrite() async throws {
        let clock = DeviceClock(), store = DeviceMemoryStore(); await store.hold()
        let auth = service(DeviceOAuthTransport([challenge(),tokens(clock)]),clock,store:store)
        let code = try await auth.beginSignIn()
        let task = Task { try await auth.completeSignIn(code) }
        for _ in 0..<100 { if await store.saving { break }; try await Task.sleep(nanoseconds: 10_000_000) }
        let saving = await store.saving; XCTAssertTrue(saving)
        task.cancel(); await store.release()
        do { _ = try await task.value; XCTFail("Canceled acceptance") } catch { XCTAssertTrue(error is CancellationError) }
        let account = try await auth.account(), saved = try await store.load(); XCTAssertNil(account); XCTAssertNil(saved)
    }
    func testRefreshCompletingAfterLogoutCannotResurrectCredentials() async throws {
        let clock = DeviceClock(), store = DeviceMemoryStore(), oauth = DeviceOAuthTransport([challenge(),tokens(clock),tokens(clock,session:"renewed")])
        let auth = service(oauth,clock,store:store)
        _ = try await auth.completeSignIn(auth.beginSignIn()); clock.advance(3590); await oauth.hold()
        let task = Task { try await auth.subscriptionToken() }
        for _ in 0..<100 { if await oauth.working { break }; try await Task.sleep(nanoseconds: 10_000_000) }
        let working = await oauth.working; XCTAssertTrue(working)
        try await auth.signOut(); await oauth.release()
        do { _ = try await task.value; XCTFail("Stale refresh") } catch { XCTAssertTrue(error is CancellationError) }
        let account = try await auth.account(), saved = try await store.load(); XCTAssertNil(account); XCTAssertNil(saved)
    }
    func testConcurrentUnauthorizedRequestsShareOneRefresh() async throws {
        let clock = DeviceClock(), oauth = DeviceOAuthTransport([challenge(),tokens(clock),tokens(clock,session:"renewed")]), api = DeviceAPITransport()
        let auth = service(oauth,clock,api:api)
        _ = try await auth.completeSignIn(auth.beginSignIn()); await api.failNext(2); await oauth.hold()
        let request = URLRequest(url: URL(string:"https://fixture.invalid/play")!)
        let first = Task { try await auth.authorizedData(request,mode:.entitlement) }
        for _ in 0..<100 { if await oauth.working { break }; try await Task.sleep(nanoseconds:10_000_000) }
        let second = Task { try await auth.authorizedData(request,mode:.entitlement) }
        for _ in 0..<100 { if await api.requests.count >= 2 { break }; try await Task.sleep(nanoseconds:10_000_000) }
        await oauth.release(); _ = try await first.value; _ = try await second.value
        let requests = await oauth.requests
        XCTAssertEqual(requests.filter { body($0)["grant_type"] == "refresh_token" }.count,1)
        let authorized = await api.requests
        XCTAssertEqual(authorized.suffix(2).map { $0.value(forHTTPHeaderField:"entitlementtoken") },["renewed","renewed"])
    }
    func testRefreshMayKeepTheExistingRefreshTokenAndPollingBacksOffOnServerFailure() async throws {
        let clock = DeviceClock()
        let original = try DeviceAccountSession.decode(tokens(clock).data,now:clock.now())
        let renewed = try DeviceAccountSession.decode(tokens(clock,refresh:nil).data,previous:original,now:clock.now())
        XCTAssertEqual(renewed.refreshToken,original.refreshToken)
        let oauth = DeviceOAuthTransport([challenge(),response(["error":"server_error"],status:503),tokens(clock)])
        let auth = service(oauth,clock)
        _ = try await auth.completeSignIn(auth.beginSignIn())
        XCTAssertEqual(clock.delays,[5,10])
    }
    func testRevokedRefreshTokenClearsTheStaleAccountForFreshSignIn() async throws {
        let clock = DeviceClock(), store = DeviceMemoryStore()
        let oauth = DeviceOAuthTransport([challenge(),tokens(clock),response(["error":"invalid_grant"],status:400)])
        let auth = service(oauth,clock,store:store)
        _ = try await auth.completeSignIn(auth.beginSignIn()); clock.advance(3590)
        do { _ = try await auth.subscriptionToken(); XCTFail("Revoked credential") }
        catch { XCTAssertEqual(error as? DeviceSignInError,.rejected) }
        let account = try await auth.account(), saved = try await store.load()
        XCTAssertNil(account); XCTAssertNil(saved)
    }
    func testRealRefreshShapePreservesTheUnexpiredPlaybackTokenAndRotatesRefreshToken() throws {
        let clock = DeviceClock()
        let initial = try DeviceAccountSession.decode(tokens(clock).data,now:clock.now())
        clock.advance(1800)
        let refresh = response(["access_token":jwt(["sub":"fixture","sid":"oidc-session"]),"token_type":"Bearer","expires_in":3600,"refresh_token":"rotated"])
        let renewed = try DeviceAccountSession.decode(refresh.data,previous:initial,now:clock.now())
        XCTAssertEqual(renewed.playback,initial.playback)
        XCTAssertEqual(renewed.refreshToken,"rotated")
        XCTAssertEqual(renewed.expiresAt,initial.expiresAt)
        XCTAssertThrowsError(try DeviceAccountSession.decode(refresh.data,now:clock.now()))
        clock.advance(1801)
        XCTAssertThrowsError(try DeviceAccountSession.decode(refresh.data,previous:renewed,now:clock.now())) { error in
            XCTAssertEqual(error as? DeviceSignInError,.expired)
        }
    }
    func testExpiredPlaybackTokenRequiresPairingWhenOAuthDoesNotReissueIt() async throws {
        let clock = DeviceClock(), store = DeviceMemoryStore()
        let refresh = response(["access_token":jwt(["sub":"fixture"]),"token_type":"Bearer","expires_in":3600,"refresh_token":"rotated"])
        let oauth = DeviceOAuthTransport([challenge(),tokens(clock),refresh])
        let auth = service(oauth,clock,store:store)
        _ = try await auth.completeSignIn(auth.beginSignIn()); clock.advance(3601)
        do { _ = try await auth.subscriptionToken(); XCTFail("Expired playback credential") }
        catch { XCTAssertEqual(error as? DeviceSignInError,.expired) }
        let account = try await auth.account(), saved = try await store.load()
        XCTAssertNil(account); XCTAssertNil(saved)
    }
}

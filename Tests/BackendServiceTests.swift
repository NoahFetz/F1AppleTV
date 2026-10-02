import Foundation
import AVFoundation
import XCTest

private actor Gate {
    private var opened = false
    private var waiters = [CheckedContinuation<Void, Never>]()
    func wait() async { if !opened { await withCheckedContinuation { waiters.append($0) } } }
    func open() { opened = true; waiters.forEach { $0.resume() }; waiters.removeAll() }
}
private actor RequestLog {
    var requests = [URLRequest]()
    func append(_ r: URLRequest) -> Int { requests.append(r); return requests.count }
    func all() -> [URLRequest] { requests }
}
private struct TestTransport: HTTPTransport {
    let handler: @Sendable (URLRequest) async throws -> Data
    func send(_ request: URLRequest) async throws -> Data { try await handler(request) }
}
private actor TestStore: SessionCredentialStore {
    var value: DeviceRegistrationResultDto?
    var writes = 0
    var saveGate: Gate?
    var fails = false
    var clearFails = false
    init(_ value: DeviceRegistrationResultDto? = nil, saveGate: Gate? = nil, fails: Bool = false) { self.value = value; self.saveGate = saveGate; self.fails = fails }
    func load() throws -> DeviceRegistrationResultDto? { if fails { throw CocoaError(.fileReadNoPermission) }; return value }
    func save(_ value: DeviceRegistrationResultDto) async throws { writes += 1; if let saveGate { await saveGate.wait() }; if fails { throw CocoaError(.fileWriteNoPermission) }; self.value = value }
    func clear() throws { if clearFails { throw CocoaError(.fileWriteNoPermission) }; value = nil }
    func failClear(_ value: Bool) { clearFails = value }
    func snapshot() -> DeviceRegistrationResultDto? { value }
    func count() -> Int { writes }
}
private struct TestAuthorization: AuthorizedRequestSending {
    let handler: @Sendable (URLRequest) async throws -> Data
    func authorizedData(_ r: URLRequest, mode: AuthorizationMode) async throws -> Data { try await handler(r) }
    func subscriptionToken() async throws -> String { "subscription-fixture" }
}

private final class TestKeyRequest: FairPlayLoadingRequest, @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false, responses = [Data](), spcs = 0
    private var errors = [Error]()
    private var spcCallbacks = [@Sendable (Result<Data, Error>) -> Void]()
    private let deferredSPC: Bool
    init(deferredSPC: Bool = false) { self.deferredSPC = deferredSPC }
    var identity: ObjectIdentifier { ObjectIdentifier(self) }
    var keyURL: URL? { URL(string: "skd://0xfixture") }
    var isCancelled: Bool { false }
    var isFinished: Bool { lock.lock(); defer { lock.unlock() }; return finished }
    func spc(certificate: Data, assetID: String, completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        lock.lock(); spcs += 1
        if deferredSPC { spcCallbacks.append(completion) }
        lock.unlock()
        if !deferredSPC { completion(.success(Data([1]))) }
    }
    func completeSPC(_ result: Result<Data, Error>, index: Int = 0) {
        lock.lock(); let callback = spcCallbacks[index]; lock.unlock(); callback(result)
    }
    func respond(_ data: Data) { lock.lock(); defer { lock.unlock() }; responses.append(data) }
    func finish(error: Error?) { lock.lock(); defer { lock.unlock() }; finished = true; if let error { errors.append(error) } }
    func snapshot() -> (Int, Int, Int) { lock.lock(); defer { lock.unlock() }; return (spcs, responses.count, errors.count) }
}
private struct TestFairPlay: FairPlayService {
    let fetch: @Sendable () async throws -> Data
    let exchange: @Sendable () async throws -> Data
    func certificate() async throws -> Data { try await fetch() }
    func license(entitlement: PlaybackEntitlement, spc: Data, assetID: String) async throws -> Data { try await exchange() }
}

final class BackendServiceTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["F1_BACKEND_FIXTURES"]!)
        return try Data(contentsOf: root.appendingPathComponent(name + ".json"))
    }
    private func registration() throws -> DeviceRegistrationResultDto { try APIClient.decode(AccountRegistrationDTO.self, from: fixture("registration")).stored() }
    private func waitUntil(_ condition: () async -> Bool) async throws {
        for _ in 0..<200 { if await condition() { return }; try await Task.sleep(nanoseconds: 5_000_000) }
        XCTFail("Timed out waiting for test synchronization"); throw URLError(.timedOut)
    }
    private func assertFailure(_ expected: APIError, _ action: () async throws -> Void) async {
        do { try await action(); XCTFail("Expected failure") } catch { XCTAssertEqual(error as? APIError, expected) }
    }
    func testEndpointProvidersHeadersBodiesAndEncodedQueries() throws {
        let e = APIEndpoints(language: "DEU")
        let uri = "/2.0/R/DEU/BIG_SCREEN_HLS/ALL/PAGE/395?filter_Series=Formula+2&from=20"
        XCTAssertEqual(try e.page(uri).url?.absoluteString, "https://f1tv.formula1.com/2.0/R/DEU/WEB_HLS/ALL/PAGE/395?filter_Series=Formula+2&from=20")
        XCTAssertTrue(try e.video("123").url!.path.contains("BIG_SCREEN_HLS"))
        XCTAssertTrue(e.menu().url!.path.contains("WEB_HLS"))
        XCTAssertNil(try e.page(uri).value(forHTTPHeaderField: "ascendontoken"))
        let play = try e.entitlement("CONTENT/PLAY?contentId=123&channelId=9&token=x%2By")
        XCTAssertTrue(play.url!.absoluteString.hasSuffix("token=x%2By"))
        XCTAssertEqual(play.value(forHTTPHeaderField: "x-f1-device-info"), APIEndpoints.deviceInfo)
        let body = DeviceUnregistrationRequestDto(deviceId: "fixture-device", authenticationKey: "fixture-key")
        let logout = try e.unregister(body, sessionID: "session")
        XCTAssertEqual(logout.httpMethod, "POST"); XCTAssertEqual(logout.value(forHTTPHeaderField: "CD-SystemID"), e.systemID)
        let json = try JSONSerialization.jsonObject(with: XCTUnwrap(logout.httpBody)) as! [String: Any]
        XCTAssertEqual(json["DeviceId"] as? String, "fixture-device")
        XCTAssertNil(e.certificate().value(forHTTPHeaderField: "ascendontoken"))
    }
    func testLegacyRegistrationSerializationAndAbsentAccountMetadata() throws {
        let original = try registration(), encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeviceRegistrationResultDto.self, from: encoded)
        XCTAssertEqual(decoded.sessionId, original.sessionId); XCTAssertEqual(decoded.physicalDevice.deviceId, original.physicalDevice.deviceId)
        let json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        XCTAssertNotNil(json["PhysicalDevice"]); XCTAssertNotNil(json["SessionSummary"])
        let minimal = try APIClient.decode(AccountRegistrationDTO.self, from: fixture("registration-minimal")).stored()
        XCTAssertEqual(minimal.sessionSummary.firstName, ""); XCTAssertEqual(minimal.physicalDevice.deviceId, "42")
        XCTAssertThrowsError(try APIClient.decode(AccountRegistrationDTO.self, from: fixture("registration-invalid")).stored())
    }
    func testBackendFailureWithHTTP200AndMalformedEnvelopeFail() async throws {
        let failure = try fixture("backend-failure")
        let client = APIClient(transport: TestTransport { _ in failure })
        await assertFailure(.backend) { _ = try await client.envelope(CatalogPayloadDTO.self, request: APIEndpoints().menu()) }
        let malformed = APIClient(transport: TestTransport { _ in Data("{}".utf8) })
        await assertFailure(.decoding) { _ = try await malformed.envelope(CatalogPayloadDTO.self, request: APIEndpoints().menu()) }
    }
    func testCatalogRetriesTransientGETOnceButNot403OrDecoding() async throws {
        let log = RequestLog()
        let client = APIClient(transport: TestTransport { r in if await log.append(r) == 1 { throw APIError.http(503) }; return Data("ok".utf8) }, delay: {})
        let data = try await client.data(APIEndpoints().menu(), retryTransient: true)
        XCTAssertEqual(data, Data("ok".utf8)); let requests = await log.all(); XCTAssertEqual(requests.count, 2)
        for failure in [APIError.http(403), .decoding] {
            let count = RequestLog(), c = APIClient(transport: TestTransport { r in _ = await count.append(r); throw failure }, delay: {})
            await assertFailure(failure) { _ = try await c.data(APIEndpoints().menu(), retryTransient: true) }
            let requests = await count.all(); XCTAssertEqual(requests.count, 1)
        }
    }
    func testSecondTransientFailureStopsAndPOSTIsNotRetried() async throws {
        let log = RequestLog(), client = APIClient(transport: TestTransport { r in _ = await log.append(r); throw APIError.http(502) }, delay: {})
        await assertFailure(.http(502)) { _ = try await client.data(APIEndpoints().menu(), retryTransient: true) }
        let first = await log.all(); XCTAssertEqual(first.count, 2)
        await assertFailure(.http(502)) { _ = try await client.data(APIEndpoints().report(PlayTimeReportingDto(contentId: 123, contentSubType: "LIVE", playHeadPosition: 20, timestamp: 1800000000))) }
        let all = await log.all(); XCTAssertEqual(all.count, 3)
    }
    func testCancellationDuringRetryDelayStopsReplay() async throws {
        let log = RequestLog(), gate = Gate()
        let client = APIClient(transport: TestTransport { r in _ = await log.append(r); throw APIError.http(503) }, delay: { await gate.wait(); try Task.checkCancellation() })
        let task = Task { try await client.data(APIEndpoints().menu(), retryTransient: true) }
        try await waitUntil { await log.all().count == 1 }; task.cancel(); await gate.open()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
        let all = await log.all(); XCTAssertEqual(all.count, 1)
    }
    func testConcurrent401RefreshesOnceAndPreservesRequiredHeaders() async throws {
        let refresh = try fixture("refresh"), log = RequestLog(), gate = Gate()
        let client = APIClient(transport: TestTransport { r in
            _ = await log.append(r)
            if r.url!.path.contains("by-device") { await gate.wait(); return refresh }
            if r.value(forHTTPHeaderField: "ascendontoken") == "subscription-old" { throw APIError.http(401) }
            return Data("success".utf8)
        })
        let store = TestStore(try registration()), auth = F1AuthService(client: client, endpoints: APIEndpoints(), storage: store)
        let request = try APIEndpoints().entitlement("123")
        let first = Task { try await auth.authorizedData(request, mode: .entitlement) }
        let second = Task { try await auth.authorizedData(request, mode: .entitlement) }
        try await waitUntil { await log.all().count >= 3 }; await gate.open()
        _ = try await first.value; _ = try await second.value
        let requests = await log.all()
        XCTAssertEqual(requests.filter { $0.url!.path.contains("by-device") }.count, 1)
        XCTAssertEqual(requests.filter { $0.value(forHTTPHeaderField: "ascendontoken") == "subscription-new" }.count, 2)
        XCTAssertTrue(requests.filter { $0.url!.path.contains("CONTENT/PLAY") }.allSatisfy { $0.value(forHTTPHeaderField: "x-f1-device-info") == APIEndpoints.deviceInfo })
        let count = await store.count(); XCTAssertEqual(count, 1)
    }
    func test403DoesNotRefreshAndReporting401DoesNotReplay() async throws {
        for (failure, mode) in [(APIError.http(403), AuthorizationMode.entitlement), (.http(401), .reporting)] {
            let log = RequestLog(), client = APIClient(transport: TestTransport { r in _ = await log.append(r); throw failure })
            let auth = F1AuthService(client: client, endpoints: APIEndpoints(), storage: TestStore(try registration()))
            await assertFailure(failure) { _ = try await auth.authorizedData(APIEndpoints().entitlement("123"), mode: mode) }
            let requests = await log.all(); XCTAssertEqual(requests.count, 1)
        }
    }
    func testFailedRefreshDoesNotReplayAndCanBeRetriedLater() async throws {
        let log = RequestLog(), client = APIClient(transport: TestTransport { r in _ = await log.append(r); throw APIError.http(r.url!.path.contains("by-device") ? 403 : 401) })
        let auth = F1AuthService(client: client, endpoints: APIEndpoints(), storage: TestStore(try registration()))
        for _ in 0..<2 {
            do { _ = try await auth.authorizedData(APIEndpoints().entitlement("123"), mode: .entitlement); XCTFail("Expected failed refresh") }
            catch { XCTAssertEqual((error as? ServiceFailure)?.operation, .tokenRefresh) }
        }
        let requests = await log.all(); XCTAssertEqual(requests.count, 4)
    }
    func testLogoutDuringRefreshDoesNotRestoreSession() async throws {
        let refresh = try fixture("refresh"), log = RequestLog(), gate = Gate(), store = TestStore(try registration())
        let client = APIClient(transport: TestTransport { r in
            _ = await log.append(r)
            if r.url!.path.contains("by-device") { await gate.wait(); return refresh }
            if r.url!.path.contains("UnregisterDevice") { return Data() }
            throw APIError.http(401)
        })
        let auth = F1AuthService(client: client, endpoints: APIEndpoints(), storage: store)
        let task = Task { try await auth.authorizedData(APIEndpoints().entitlement("123"), mode: .entitlement) }
        try await waitUntil { await log.all().contains { $0.url!.path.contains("by-device") } }
        try await auth.signOut(); await gate.open()
        do { _ = try await task.value; XCTFail("Expected stale refresh cancellation") } catch { XCTAssertTrue(error is CancellationError) }
        let saved = await store.snapshot(), account = try await auth.account(); XCTAssertNil(saved); XCTAssertNil(account)
    }
    func testLogoutQueuesAfterAlreadyRunningLoginSave() async throws {
        let bytes = try fixture("registration"), gate = Gate(), store = TestStore(nil, saveGate: gate), log = RequestLog()
        let client = APIClient(transport: TestTransport { r in _ = await log.append(r); return bytes })
        let auth = F1AuthService(client: client, endpoints: APIEndpoints(), storage: store)
        let login = Task { try await auth.signIn(email: "fixture", password: "fixture", challenge: LoginChallenge("fixture")) }
        try await waitUntil { await store.count() == 1 }
        let logout = Task { try await auth.signOut() }
        // account() becomes nil after logout has loaded the old empty storage.
        try await Task.sleep(nanoseconds: 30_000_000); await gate.open()
        try await logout.value
        do { _ = try await login.value; XCTFail("Expected superseded login") } catch { XCTAssertTrue(error is CancellationError) }
        let value = await store.snapshot(); XCTAssertNil(value)
    }
    func testNewLoginSupersedesOlderAuthenticationAttempt() async throws {
        let firstGate = Gate(), log = RequestLog(), data = try fixture("registration"), store = TestStore()
        let client = APIClient(transport: TestTransport { r in if await log.append(r) == 1 { await firstGate.wait() }; return data })
        let auth = F1AuthService(client: client, endpoints: APIEndpoints(), storage: store)
        let first = Task { try await auth.signIn(email: "first", password: "fixture", challenge: LoginChallenge("fixture")) }
        try await waitUntil { await log.all().count == 1 }
        _ = try await auth.signIn(email: "second", password: "fixture", challenge: LoginChallenge("fixture")); await firstGate.open()
        do { _ = try await first.value; XCTFail("Expected superseded login") } catch { XCTAssertTrue(error is CancellationError) }
        let count = await store.count(); XCTAssertEqual(count, 1)
    }
    func testStorageFailureIsOwnedByCredentialsAndAccountStateRemainsEmpty() async throws {
        let data = try fixture("registration"), auth = F1AuthService(client: APIClient(transport: TestTransport { _ in data }), endpoints: APIEndpoints(), storage: TestStore(fails: true))
        do { _ = try await auth.signIn(email: "fixture", password: "fixture", challenge: LoginChallenge("fixture")); XCTFail("Expected storage failure") }
        catch { XCTAssertEqual((error as? ServiceFailure)?.operation, .credentials) }
        do { _ = try await auth.account(); XCTFail("Expected storage read failure") }
        catch { XCTAssertEqual((error as? ServiceFailure)?.operation, .credentials) }
    }
    func testConcurrentCertificateLoadingUsesOneRequestAndCachesSuccess() async throws {
        let log = RequestLog(), gate = Gate(), bytes = Data([1, 2, 3])
        let client = APIClient(transport: TestTransport { r in _ = await log.append(r); await gate.wait(); return bytes })
        let service = F1FairPlayService(client: client, endpoints: APIEndpoints(), auth: TestAuthorization { _ in Data() })
        async let a = service.certificate(), b = service.certificate()
        try await waitUntil { await log.all().count == 1 }; await gate.open()
        let values = try await [a, b]; XCTAssertEqual(values, [bytes, bytes]); _ = try await service.certificate()
        let requests = await log.all(); XCTAssertEqual(requests.count, 1)
    }
    func testCertificateFailureAllowsLaterAttemptAndCanceledWaiterDoesNotCancelOthers() async throws {
        let log = RequestLog(), gate = Gate(), bytes = Data([4])
        let client = APIClient(transport: TestTransport { r in if await log.append(r) == 1 { throw APIError.http(403) }; await gate.wait(); return bytes })
        let service = F1FairPlayService(client: client, endpoints: APIEndpoints(), auth: TestAuthorization { _ in Data() })
        await assertFailure(.http(403)) { _ = try await service.certificate() }
        let canceled = Task { try await service.certificate() }, other = Task { try await service.certificate() }
        try await waitUntil { await log.all().count == 2 }; canceled.cancel(); await gate.open()
        let successful = try await other.value; XCTAssertEqual(successful, bytes)
        do { _ = try await canceled.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
        let requests = await log.all(); XCTAssertEqual(requests.count, 2)
    }
    func testLicensePreservesBodyHeadersCKCAndIndependentEntitlements() async throws {
        let log = RequestLog(), ckc = Data([9, 8])
        let client = APIClient(transport: TestTransport { r in _ = await log.append(r); return ckc.base64EncodedData() })
        let service = F1FairPlayService(client: client, endpoints: APIEndpoints(), auth: TestAuthorization { _ in Data() })
        let first = PlaybackEntitlement(url: "https://cdn.example/a", channelID: "1", drmType: "fairplay", licenseURL: "https://license.example/a?token=x%2By", entitlementToken: "first")
        let second = PlaybackEntitlement(url: "https://cdn.example/b", channelID: "2", drmType: "fairplay", licenseURL: "https://license.example/b", entitlementToken: "second")
        async let a = service.license(entitlement: first, spc: Data([0xfb, 0xff]), assetID: "asset"), b = service.license(entitlement: second, spc: Data([1]), assetID: "other")
        let values = try await [a, b]; XCTAssertEqual(values, [ckc, ckc])
        let requests = await log.all(); XCTAssertEqual(requests.count, 2)
        let request = try XCTUnwrap(requests.first { $0.value(forHTTPHeaderField: "entitlementtoken") == "first" })
        XCTAssertEqual(String(decoding: request.httpBody!, as: UTF8.self), "spc=+/8=&assetId=asset")
        XCTAssertEqual(request.url?.absoluteString, first.licenseURL); XCTAssertEqual(request.value(forHTTPHeaderField: "ascendontoken"), "subscription-fixture")
    }
    func testInvalidCKCAndLicenseHTTPFailureAreNotRetried() async throws {
        for failure in [false, true] {
            let log = RequestLog(), client = APIClient(transport: TestTransport { r in _ = await log.append(r); if failure { throw APIError.http(503) }; return Data("not-base64!".utf8) })
            let service = F1FairPlayService(client: client, endpoints: APIEndpoints(), auth: TestAuthorization { _ in Data() })
            let entitlement = PlaybackEntitlement(url: "https://cdn.example/a", channelID: "1", drmType: "fairplay", licenseURL: "https://license.example/a", entitlementToken: "first")
            await assertFailure(failure ? .http(503) : .invalidPlayback) { _ = try await service.license(entitlement: entitlement, spc: Data([1]), assetID: "asset") }
            let requests = await log.all(); XCTAssertEqual(requests.count, 1)
        }
    }
    func testEntitlementRequiredFieldsMixedIDsAndOptionalDRM() async throws {
        let plain = try APIClient.decode(APIEnvelope<EntitlementDTO>.self, from: fixture("entitlement-plain")).resultObj!.model()
        XCTAssertEqual(plain.channelID, "9"); XCTAssertNil(plain.licenseURL)
        XCTAssertTrue(plain.url.hasSuffix("token=x%2By"))
        let drm = try APIClient.decode(APIEnvelope<EntitlementDTO>.self, from: fixture("entitlement-drm")).resultObj!.model()
        XCTAssertEqual(drm.channelID, "1033"); XCTAssertEqual(drm.drmType, "fairplay")
        let data = try fixture("entitlement-invalid"), service = F1PlaybackService(endpoints: APIEndpoints(), auth: TestAuthorization { _ in data })
        await assertFailure(.invalidPlayback) { _ = try await service.entitlement(PlaybackTarget(uri: "123", requiresVideoDetails: false)) }
    }
    func testEntitlementDecodesBackendLicenseURLCapitalization() async throws {
        let bytes = try fixture("entitlement-drm-canonical")
        let service = F1PlaybackService(endpoints: APIEndpoints(), auth: TestAuthorization { _ in bytes })
        let entitlement = try await service.entitlement(PlaybackTarget(uri: "123", requiresVideoDetails: false))
        XCTAssertEqual(entitlement.licenseURL, "https://license.example/license?contentId=123&token=x%2By")
        let request = try FairPlayLicenseRequest.make(streamEntitlement: entitlement, spcData: Data([1]), assetID: "asset", subscriptionToken: "fixture")
        XCTAssertEqual(request.url?.absoluteString, entitlement.licenseURL)
        XCTAssertEqual(request.value(forHTTPHeaderField: "entitlementtoken"), "fixture")
    }
    func testCatalogKeepsValidSiblingsDatesAndStableIDs() throws {
        let payload = try APIClient.decode(APIEnvelope<CatalogPayloadDTO>.self, from: fixture("catalog-partial")).resultObj!
        var diagnostics = 0
        let first = CatalogMapper.sections(payload, diagnostics: { _ in diagnostics += 1 }), second = CatalogMapper.sections(payload)
        XCTAssertEqual(first.map(\.id), second.map(\.id)); XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first[0].items.count, 1); XCTAssertEqual(first[0].items[0].contentId, "123")
        XCTAssertEqual(first[0].items[0].race?.sessionStartDate, Date(timeIntervalSince1970: 1_800_000_000)); XCTAssertGreaterThan(diagnostics, 0)
    }
    func testAllMalformedCatalogAndMissingContainersFail() async throws {
        for bytes in [Data(#"{"resultCode":"OK","resultObj":{}}"#.utf8), Data(#"{"resultCode":"OK","resultObj":{"containers":[false]}}"#.utf8)] {
            let service = F1CatalogService(client: APIClient(transport: TestTransport { _ in bytes }), endpoints: APIEndpoints(), diagnostics: { _ in })
            await assertFailure(.invalidResponse) { _ = try await service.page(CatalogDestination(uri: "/2.0/R/ENG/WEB_HLS/ALL/PAGE/395")) }
        }
    }
    func testBackendRejectionIsCheckedBeforeErrorPayloadDecoding() async throws {
        let data = Data(#"{"resultCode":"ERROR","resultObj":"unrelated error payload"}"#.utf8)
        let client = APIClient(transport: TestTransport { _ in data })
        await assertFailure(.backend) { _ = try await client.envelope(CatalogPayloadDTO.self, request: APIEndpoints().menu()) }
    }
    func testRepeated401StopsAfterOneRefreshAndReplay() async throws {
        let refresh = try fixture("refresh"), log = RequestLog()
        let client = APIClient(transport: TestTransport { r in _ = await log.append(r); if r.url!.path.contains("by-device") { return refresh }; throw APIError.http(401) })
        let auth = F1AuthService(client: client, endpoints: APIEndpoints(), storage: TestStore(try registration()))
        await assertFailure(.http(401)) { _ = try await auth.authorizedData(APIEndpoints().entitlement("123"), mode: .entitlement) }
        let requests = await log.all(); XCTAssertEqual(requests.count, 3)
    }
    func testLoginAndLogoutFailuresAreNotReplayedAutomatically() async throws {
        let log = RequestLog(), client = APIClient(transport: TestTransport { r in _ = await log.append(r); throw APIError.http(503) })
        let store = TestStore(try registration()), auth = F1AuthService(client: client, endpoints: APIEndpoints(), storage: store)
        await assertFailure(.http(503)) { _ = try await auth.signIn(email: "fixture", password: "fixture", challenge: LoginChallenge("fixture")) }
        await assertFailure(.http(503)) { try await auth.signOut() }
        let requests = await log.all(); XCTAssertEqual(requests.count, 2)
        let profile = try await auth.account(); XCTAssertNotNil(profile)
    }
    func testPlaybackMappingOwnsChannelsAndAllowsAbsentTeamMetadata() async throws {
        let data = try fixture("video"), log = RequestLog()
        let service = F1PlaybackService(endpoints: APIEndpoints(), auth: TestAuthorization { r in _ = await log.append(r); return data })
        let first = try await service.video("123"), second = try await service.video("123")
        XCTAssertEqual(first.channels.map(\.id), second.channels.map(\.id)); XCTAssertEqual(first.channels.count, 3)
        XCTAssertEqual(first.channels.map(\.kind), [.MainFeed, .AdditionalFeed, .OnBoardCamera])
        XCTAssertEqual(first.channels.last?.racingNumber, 16); XCTAssertEqual(first.channels.last?.teamImg, "")
        XCTAssertNil(first.channels.last?.hex); XCTAssertEqual(first.item.contentId, "123")
        XCTAssertTrue(first.isLive)
        let requests = await log.all(); XCTAssertTrue(requests.allSatisfy { $0.url!.path.contains("BIG_SCREEN_HLS") })
    }
    func testPlayTimeReportUsesExistingBodyAndProvider() async throws {
        let log = RequestLog(), service = F1PlaybackService(endpoints: APIEndpoints(), auth: TestAuthorization { r in _ = await log.append(r); return Data(#"{"resultCode":"OK"}"#.utf8) })
        try await service.report(contentID: "123", subtype: "LIVE", position: 20, timestamp: 1800000000)
        let requests = await log.all(), request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "POST"); XCTAssertTrue(request.url!.path.contains("/1.0/R/ENG/BIG_SCREEN_HLS/ALL/ACTION/PLAY"))
        let json = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as! [String: Any]
        XCTAssertEqual(json["contentId"] as? Int, 123); XCTAssertEqual(json["playHeadPosition"] as? Int, 20); XCTAssertEqual(json["timestamp"] as? Int, 1800000000)
    }
    func testCertificateConnectivityRetryIsBounded() async throws {
        let log = RequestLog(), client = APIClient(transport: TestTransport { r in if await log.append(r) == 1 { throw APIError.transport(NSURLErrorTimedOut) }; return Data([1]) }, delay: {})
        let service = F1FairPlayService(client: client, endpoints: APIEndpoints(), auth: TestAuthorization { _ in Data() })
        _ = try await service.certificate(); let requests = await log.all(); XCTAssertEqual(requests.count, 2)
    }
    func testLoginPreparationCancellationIsPropagated() async throws {
        struct Preparation: LoginChallengeProviding {
            func prepare() async throws -> LoginChallenge { try await Task.sleep(nanoseconds: 5_000_000_000); return LoginChallenge("fixture") }
        }
        let auth = F1AuthService(client: APIClient(transport: TestTransport { _ in XCTFail("Preparation must not call account endpoint"); return Data() }), endpoints: APIEndpoints(), storage: TestStore())
        let task = Task { try await auth.prepareLogin(using: Preparation()) }; task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
    }
    func testFinalOwnedErrorsAreRecordedOnceWithoutPrivateFields() throws {
        let suite = "backend-errors-" + UUID().uuidString, defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppErrorStore(defaults: defaults)
        recordServiceFailure(ServiceFailure(operation: .tokenRefresh, underlying: APIError.http(403)), operation: .entitlement, store: store)
        recordServiceFailure(CancellationError(), operation: .preview, store: store)
        XCTAssertEqual(store.records().count, 1); XCTAssertEqual(store.records().first?.operation, .tokenRefresh)
        XCTAssertEqual(store.records().first?.httpStatus, 403); XCTAssertEqual(store.records().first?.repeatCount, 1)
    }
    func testLogoutStorageFailureRetriesCleanupWithoutUnregisteringTwice() async throws {
        let log = RequestLog(), client = APIClient(transport: TestTransport { r in _ = await log.append(r); return Data() }), store = TestStore(try registration())
        let auth = F1AuthService(client: client, endpoints: APIEndpoints(), storage: store)
        await store.failClear(true)
        do { try await auth.signOut(); XCTFail("Expected clear failure") } catch { XCTAssertEqual((error as? ServiceFailure)?.operation, .credentials) }
        let account = try await auth.account(); XCTAssertNil(account)
        await store.failClear(false); try await auth.signOut()
        let requests = await log.all(); XCTAssertEqual(requests.count, 1)
        let saved = await store.snapshot(); XCTAssertNil(saved)
    }
    func testCatalogDiagnosticsPersistSafeSectionContext() throws {
        let suite = "catalog-context-" + UUID().uuidString, defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppErrorStore(defaults: defaults), context = CatalogDiagnostic(sectionIndex: 3, itemIndex: 2, reason: .unusableVideo)
        store.record(APIError.decoding.diagnostic, operation: .page, catalogContext: context)
        let restored = AppErrorStore(defaults: defaults); XCTAssertEqual(restored.records().first?.catalogContext, context)
        XCTAssertNil(CatalogDiagnostic(sectionIndex: -1, reason: .unsupportedLayout).safe)
        let payload = try APIClient.decode(APIEnvelope<CatalogPayloadDTO>.self, from: fixture("catalog-partial")).resultObj!
        var reported = [CatalogDiagnostic](); _ = CatalogMapper.sections(payload, diagnostics: { reported.append($0) })
        XCTAssertTrue(reported.contains { $0.reason == .unsupportedLayout && $0.sectionIndex == 0 })
    }
    func testResourceLoaderCancellationPreventsStaleSPCAndCKC() async throws {
        let gate = Gate(), log = RequestLog(), request = TestKeyRequest()
        let service = TestFairPlay(fetch: { _ = await log.append(APIEndpoints().certificate()); await gate.wait(); return Data([1]) }, exchange: { XCTFail("Canceled request must not exchange SPC"); return Data([2]) })
        let loader = FairPlayKeyLoader(queue: DispatchQueue(label: "fixture.resource"))
        let entitlement = PlaybackEntitlement(url: "https://cdn.example/a", channelID: "1", drmType: "fairplay", licenseURL: "https://license.example/a", entitlementToken: "fixture")
        loader.load(request, entitlement: entitlement, service: service, reportsErrors: false)
        try await waitUntil { await log.all().count == 1 }; loader.cancelAll()
        try await waitUntil { request.isFinished }; await gate.open()
        try await Task.sleep(nanoseconds: 20_000_000)
        let state = request.snapshot(); XCTAssertEqual(state.0, 0); XCTAssertEqual(state.1, 0); XCTAssertEqual(state.2, 1)
    }
    func testResourceLoaderCancellationDuringLicenseCannotDeliverCKC() async throws {
        let gate = Gate(), log = RequestLog(), request = TestKeyRequest()
        let service = TestFairPlay(fetch: { Data([1]) }, exchange: { _ = await log.append(APIEndpoints().certificate()); await gate.wait(); return Data([2]) })
        let loader = FairPlayKeyLoader(queue: DispatchQueue(label: "fixture.resource"))
        let entitlement = PlaybackEntitlement(url: "https://cdn.example/a", channelID: "1", drmType: "fairplay", licenseURL: "https://license.example/a", entitlementToken: "fixture")
        loader.load(request, entitlement: entitlement, service: service, reportsErrors: false)
        try await waitUntil { await log.all().count == 1 }; loader.cancel(request); await gate.open()
        try await Task.sleep(nanoseconds: 20_000_000)
        let state = request.snapshot(); XCTAssertEqual(state.0, 1); XCTAssertEqual(state.1, 0)
    }
    func testResourceLoaderDeliversReadyLicenseOnce() async throws {
        let request = TestKeyRequest(), ckc = Data([7, 8])
        let service = TestFairPlay(fetch: { Data([1]) }, exchange: { ckc })
        let loader = FairPlayKeyLoader(queue: DispatchQueue(label: "fixture.resource"))
        loader.load(request, entitlement: PlaybackEntitlement(url: "https://cdn.example/a", channelID: "1", drmType: "fairplay", licenseURL: "https://license.example/a", entitlementToken: "fixture"), service: service, reportsErrors: false)
        try await waitUntil { request.isFinished }
        let state = request.snapshot(); XCTAssertEqual(state.0, 1); XCTAssertEqual(state.1, 1); XCTAssertEqual(state.2, 0)
    }

    func testContentKeyCancellationDuringSPCIgnoresLateAndDuplicateCompletions() async throws {
        let request = TestKeyRequest(deferredSPC: true)
        let service = TestFairPlay(fetch: { Data([1]) }, exchange: { XCTFail("Canceled SPC must not reach the license server"); return Data([2]) })
        let loader = FairPlayKeyLoader(queue: DispatchQueue(label: "fixture.content-key"))
        let entitlement = PlaybackEntitlement(url: "https://cdn.example/a", channelID: "1", drmType: "fairplay", licenseURL: "https://license.example/a", entitlementToken: "fixture")
        loader.load(request, entitlement: entitlement, service: service, reportsErrors: false)
        try await waitUntil { request.snapshot().0 == 1 }
        loader.cancelAll()
        try await waitUntil { request.isFinished }
        request.completeSPC(.success(Data([1])))
        request.completeSPC(.failure(URLError(.cannotDecodeContentData)))
        try await Task.sleep(nanoseconds: 20_000_000)
        let state = request.snapshot(); XCTAssertEqual(state.1, 0); XCTAssertEqual(state.2, 1)
    }

    func testSupersededContentKeyOperationCannotDeliverAnOldLicense() async throws {
        let request = TestKeyRequest(deferredSPC: true), log = RequestLog()
        let service = TestFairPlay(fetch: { Data([1]) }, exchange: { _ = await log.append(APIEndpoints().certificate()); return Data([2]) })
        let loader = FairPlayKeyLoader(queue: DispatchQueue(label: "fixture.content-key"))
        let entitlement = PlaybackEntitlement(url: "https://cdn.example/a", channelID: "1", drmType: "fairplay", licenseURL: "https://license.example/a", entitlementToken: "fixture")
        loader.load(request, entitlement: entitlement, service: service, reportsErrors: false)
        try await waitUntil { request.snapshot().0 == 1 }
        loader.load(request, entitlement: entitlement, service: service, reportsErrors: false)
        try await waitUntil { request.snapshot().0 == 2 }
        request.completeSPC(.success(Data([1])))
        try await Task.sleep(nanoseconds: 20_000_000)
        let before = await log.all(); XCTAssertTrue(before.isEmpty)
        request.completeSPC(.success(Data([1])), index: 1)
        request.completeSPC(.success(Data([1])), index: 1)
        try await waitUntil { request.isFinished }
        let after = await log.all(); XCTAssertEqual(after.count, 1)
        let state = request.snapshot(); XCTAssertEqual(state.1, 1); XCTAssertEqual(state.2, 0)
    }

    func testContentKeySPCFailureFinishesOnceWithoutExchangingLicense() async throws {
        let request = TestKeyRequest(deferredSPC: true)
        let service = TestFairPlay(fetch: { Data([1]) }, exchange: { XCTFail("Failed SPC must not reach the license server"); return Data([2]) })
        let loader = FairPlayKeyLoader(queue: DispatchQueue(label: "fixture.content-key"))
        loader.load(request, entitlement: PlaybackEntitlement(url: "https://cdn.example/a", channelID: "1", drmType: "fairplay", licenseURL: "https://license.example/a", entitlementToken: "fixture"), service: service, reportsErrors: false)
        try await waitUntil { request.snapshot().0 == 1 }
        request.completeSPC(.failure(APIError.invalidPlayback))
        request.completeSPC(.success(Data([1])))
        try await waitUntil { request.isFinished }
        let state = request.snapshot(); XCTAssertEqual(state.1, 0); XCTAssertEqual(state.2, 1)
    }

    func testNativeContentKeyIdentifiersPreserveSKDNormalization() throws {
        for identifier: Any in ["skd://0xfixture", NSURL(string: "skd://0xfixture")!] {
            let url = try XCTUnwrap(AVFoundationFairPlaySession.keyURL(for: identifier))
            XCTAssertEqual(FairPlayLicenseRequest.assetID(for: url), "fixture")
        }
        XCTAssertNil(AVFoundationFairPlaySession.keyURL(for: nil))
        XCTAssertNil(AVFoundationFairPlaySession.keyURL(for: 123))
        let ordinary = try XCTUnwrap(AVFoundationFairPlaySession.keyURL(for: "https://cdn.example.com/a"))
        XCTAssertNil(FairPlayLicenseRequest.assetID(for: ordinary))
    }

    func testResourceLoaderClassifiesStreamingKeysAndFinishesExactlyOnce() throws {
        for text in ["skd://0xfixture", "skd://fixture"] {
            var contentTypes = [String]()
            let handled = AVFoundationFairPlaySession.routeResourceKey(url: URL(string: text), hasSession: true) { contentTypes.append($0) }
            XCTAssertTrue(handled)
            XCTAssertEqual(contentTypes, [AVStreamingKeyDeliveryContentKeyType])
        }
    }

    func testResourceLoaderRejectsUnownedKeysAndLeavesPlaylistsForTheirHandler() {
        for text in [nil, "https://cdn.example/master.m3u8", "f1-resolution://playlist/fixture.m3u8", "skd://"] as [String?] {
            XCTAssertFalse(AVFoundationFairPlaySession.routeResourceKey(url: text.flatMap(URL.init(string:)), hasSession: true) { _ in XCTFail("Unsupported resource must not finish as a key") })
        }
        XCTAssertFalse(AVFoundationFairPlaySession.routeResourceKey(url: URL(string: "skd://fixture"), hasSession: false) { _ in XCTFail("No native session owns this key") })
    }

    func testNativeKeySessionsOwnIndependentRecipientsAndInvalidateIdempotently() throws {
        let service = TestFairPlay(fetch: { XCTFail("Registration must be lazy"); return Data([1]) }, exchange: { XCTFail("Registration must not request a license"); return Data([2]) })
        let entitlement = PlaybackEntitlement(url: "https://cdn.example/a", channelID: "1", drmType: "fairplay", licenseURL: "https://license.example/a", entitlementToken: "fixture")
        let main = try XCTUnwrap(AVFoundationFairPlaySession(entitlement: entitlement, service: service, queue: DispatchQueue(label: "fixture.main-key"), reportsErrors: false, onError: { _ in XCTFail("No media is loaded") }))
        let preview = try XCTUnwrap(AVFoundationFairPlaySession(entitlement: entitlement, service: service, queue: DispatchQueue(label: "fixture.preview-key"), reportsErrors: false, onError: { _ in XCTFail("No media is loaded") }))
        let mainAsset = AVURLAsset(url: URL(string: "https://cdn.example/main.m3u8")!)
        let previewAsset = AVURLAsset(url: URL(string: "https://cdn.example/preview.m3u8")!)
        main.register(mainAsset); preview.register(previewAsset)
        XCTAssertFalse(main.session === preview.session)
        XCTAssertEqual(main.session.contentKeyRecipients.count, 1)
        XCTAssertEqual(preview.session.contentKeyRecipients.count, 1)
        XCTAssertTrue(main.session.contentKeyRecipients.first as? AVURLAsset === mainAsset)
        main.invalidate(); main.invalidate()
        XCTAssertNil(main.session.delegate)
        XCTAssertNotNil(preview.session.delegate)
        main.register(AVURLAsset(url: URL(string: "https://cdn.example/ignored.m3u8")!))
        XCTAssertEqual(main.session.contentKeyRecipients.count, 1)
        preview.invalidate()
    }

}
@main enum BackendTestRunner {
    static func main() { let suite = BackendServiceTests.defaultTestSuite; suite.run(); exit(suite.testRun?.totalFailureCount == 0 ? 0 : 1) }
}

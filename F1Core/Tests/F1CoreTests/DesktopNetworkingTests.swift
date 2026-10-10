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
final class DesktopNetworkingTests: XCTestCase {
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

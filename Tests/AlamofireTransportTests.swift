import Foundation
import Alamofire
import XCTest

private final class ProtocolState: @unchecked Sendable {
    private let lock = NSLock()
    var status = 200
    private var started = 0, stopped = 0
    func start() { lock.lock(); started += 1; lock.unlock() }
    func stop() { lock.lock(); stopped += 1; lock.unlock() }
    func counts() -> (Int, Int) { lock.lock(); defer { lock.unlock() }; return (started, stopped) }
}
private final class FixtureURLProtocol: URLProtocol, @unchecked Sendable {
    static let state = ProtocolState()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.state.start()
        if request.url!.path == "/pending" { return }
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.state.status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("fixture".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { Self.state.stop() }
}
final class AlamofireTransportTests: XCTestCase {
    private func transport() -> AlamofireHTTPTransport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureURLProtocol.self]
        return AlamofireHTTPTransport(session: Session(configuration: configuration))
    }
    func testTransportReturnsBytesAndRejectsHTTPStatus() async throws {
        let transport = transport(), request = URLRequest(url: URL(string: "https://fixture.example/data")!)
        FixtureURLProtocol.state.status = 200
        let data = try await transport.send(request); XCTAssertEqual(data, Data("fixture".utf8))
        FixtureURLProtocol.state.status = 403
        do { _ = try await transport.send(request); XCTFail("Expected HTTP validation") } catch { XCTAssertEqual(error as? APIError, .http(403)) }
    }
    func testTaskCancellationStopsUnderlyingAlamofireRequest() async throws {
        let before = FixtureURLProtocol.state.counts(), transport = transport()
        let task = Task { try await transport.send(URLRequest(url: URL(string: "https://fixture.example/pending")!)) }
        for _ in 0..<200 { if FixtureURLProtocol.state.counts().0 > before.0 { break }; try await Task.sleep(nanoseconds: 5_000_000) }
        XCTAssertGreaterThan(FixtureURLProtocol.state.counts().0, before.0); task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
        for _ in 0..<200 { if FixtureURLProtocol.state.counts().1 > before.1 { break }; try await Task.sleep(nanoseconds: 5_000_000) }
        XCTAssertGreaterThan(FixtureURLProtocol.state.counts().1, before.1)
    }
}
@main enum TransportTestRunner {
    static func main() { let suite = AlamofireTransportTests.defaultTestSuite; suite.run(); exit(suite.testRun?.totalFailureCount == 0 ? 0 : 1) }
}

import XCTest
import AVFoundation
import ImageIO
@testable import F1Core

private final class ThumbnailURLProtocol: URLProtocol, @unchecked Sendable {
    static var image = Data()
    static var playlist = ""
    static var requests: [String] = []
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "thumbnail.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        Self.requests.append(path)
        let data = path.hasSuffix(".png") ? Self.image : Data(Self.playlist.utf8)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
final class ThumbnailProviderTests: XCTestCase {
    @MainActor private func fixture() async -> (FairPlayer, PlaybackThumbnailProvider, URLSession) {
        ThumbnailURLProtocol.requests = []
        let context = CGContext(data: nil, width: 4, height: 2, bitsPerComponent: 8, bytesPerRow: 16, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1)); context.fill(CGRect(x: 2, y: 0, width: 2, height: 2))
        let data = NSMutableData(), destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil); CGImageDestinationFinalize(destination); ThumbnailURLProtocol.image = data as Data
        ThumbnailURLProtocol.playlist = """
        #EXTM3U
        #EXT-X-IMAGES-ONLY
        #EXT-X-PROGRAM-DATE-TIME:2026-10-09T12:00:00Z
        #EXT-X-TILES:RESOLUTION=2x2,LAYOUT=2x1,DURATION=2
        #EXTINF:4,
        tiles.png
        #EXT-X-ENDLIST
        """
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [ThumbnailURLProtocol.self]
        let session = URLSession(configuration: config), player = FairPlayer()
        player.reportsPlaybackErrors = false
        player.playStream(streamEntitlement: PlaybackEntitlement(url: "https://thumbnail.invalid/master.m3u8", channelID: "fixture", drmType: nil, licenseURL: nil, entitlementToken: "fixture"))
        let prepared = expectation(description: "Cached thumbnail manifest prepared")
        player.prepareStream(cachedManifest: """
        #EXTM3U
        #EXT-X-IMAGE-STREAM-INF:URI="images.m3u8"
        #EXT-X-STREAM-INF:BANDWIDTH=100000,RESOLUTION=320x180
        http://127.0.0.1:1/media.m3u8
        """, cachedBaseURL: URL(string: "https://thumbnail.invalid/master.m3u8")!) { _ in prepared.fulfill() }
        await fulfillment(of: [prepared], timeout: 2)
        return (player, PlaybackThumbnailProvider(player: player, session: session), session)
    }
    @MainActor func testImagePlaylistTilesAndTwoSecondCache() async throws {
        let (player, provider, session) = await fixture()
        defer { provider.reset(); player.stopStream(); session.invalidateAndCancel() }
        let first = expectation(description: "First tile"), second = expectation(description: "Second tile"), cached = expectation(description: "Cached tile")
        var a: CGImage?, b: CGImage?
        provider.request(at: 0.5) { a = $0; first.fulfill() }; await fulfillment(of: [first], timeout: 3)
        provider.request(at: 2.5) { b = $0; second.fulfill() }; await fulfillment(of: [second], timeout: 3)
        XCTAssertEqual(a?.width, 2); XCTAssertEqual(b?.height, 2)
        let aBytes = try XCTUnwrap(a?.dataProvider?.data) as Data, bBytes = try XCTUnwrap(b?.dataProvider?.data) as Data
        XCTAssertNotEqual(aBytes, bBytes)
        provider.request(at: 2.7) { XCTAssertTrue($0 === b); cached.fulfill() }; await fulfillment(of: [cached], timeout: 1)
        XCTAssertEqual(ThumbnailURLProtocol.requests.filter { $0 == "/images.m3u8" }.count, 1)
        XCTAssertEqual(ThumbnailURLProtocol.requests.filter { $0 == "/tiles.png" }.count, 1)
    }
    @MainActor func testSupersededRequestAndResetDoNotDeliverStaleFrame() async {
        let (player, provider, session) = await fixture()
        defer { provider.reset(); player.stopStream(); session.invalidateAndCancel() }
        let old = expectation(description: "Superseded request"), latest = expectation(description: "Latest request")
        old.isInverted = true
        provider.request(at: 0) { _ in old.fulfill() }
        provider.request(at: 2) { XCTAssertNotNil($0); latest.fulfill() }
        await fulfillment(of: [latest, old], timeout: 0.6)
        let closed = expectation(description: "Reset request"); closed.isInverted = true
        provider.request(at: 0) { _ in closed.fulfill() }; provider.reset()
        await fulfillment(of: [closed], timeout: 0.3)
    }
}

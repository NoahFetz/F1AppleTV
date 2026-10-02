import Foundation
import XCTest

final class PreviewPlaylistTests: XCTestCase {
    private let baseURL = URL(string: "https://cdn.example.com/redirected/images/playlist.m3u8?signature=one")!

    func testManifestFindsRealImageAndIFrameRenditions() {
        let text = """
        #EXTM3U
        #EXT-X-IMAGE-STREAM-INF:BANDWIDTH=1234,CODECS="jpeg",URI="../thumbs/list.m3u8?signature=a,b"
        #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=2345,RESOLUTION=320x180,URI="iframe.m3u8"
        """
        let manifest = HLSPreviewManifest(text: text, baseURL: baseURL)
        XCTAssertTrue(manifest.hasIFrameRenditions)
        XCTAssertEqual(manifest.imagePlaylists.map { $0.absoluteString }, ["https://cdn.example.com/redirected/thumbs/list.m3u8?signature=a,b"])
    }

    func testOrdinaryVideoIsNotAssumedToSupportFrameExtraction() {
        let manifest = HLSPreviewManifest(text: "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1234\nvideo.m3u8", baseURL: baseURL)
        XCTAssertFalse(manifest.hasIFrameRenditions)
        XCTAssertTrue(manifest.imagePlaylists.isEmpty)
    }

    func testSpriteTileLookupAndBoundaries() throws {
        let text = """
        #EXTM3U
        #EXT-X-IMAGES-ONLY
        #EXT-X-TILES:RESOLUTION=320x180,LAYOUT=2x2,DURATION=2
        #EXTINF:8,
        first.jpg?token=a%2Fb
        #EXT-X-TILES:RESOLUTION=320x180,LAYOUT=2x2,DURATION=2
        #EXTINF:8,
        /second.jpg
        #EXT-X-ENDLIST
        """
        let playlist = try HLSImagePlaylist(text: text, baseURL: baseURL)
        XCTAssertFalse(playlist.isLive)
        XCTAssertEqual(playlist.frame(at: 4.2, date: nil)?.index, 2)
        XCTAssertEqual(playlist.frame(at: 4.2, date: nil)?.tile?.width, 320)
        XCTAssertEqual(playlist.frame(at: 4.2, date: nil)?.url.absoluteString, "https://cdn.example.com/redirected/images/first.jpg?token=a%2Fb")
        XCTAssertEqual(playlist.frame(at: 8, date: nil)?.url.absoluteString, "https://cdn.example.com/second.jpg")
        XCTAssertEqual(playlist.frame(at: 8, date: nil)?.index, 0)
        XCTAssertNil(playlist.frame(at: 16, date: nil))
        XCTAssertNil(playlist.frame(at: -.infinity, date: nil))
    }

    func testLiveImagesUseProgramDatesRatherThanGuessedTimeline() throws {
        let text = """
        #EXTM3U
        #EXT-X-IMAGES-ONLY
        #EXT-X-PROGRAM-DATE-TIME:2026-09-29T21:00:00.500Z
        #EXTINF:5,
        first.jpg
        #EXTINF:5,
        second.jpg
        """
        let playlist = try HLSImagePlaylist(text: text, baseURL: baseURL)
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = try XCTUnwrap(parser.date(from: "2026-09-29T21:00:07.500Z"))
        XCTAssertTrue(playlist.isLive)
        XCTAssertTrue(playlist.frame(at: 5000, date: date)?.url.absoluteString.hasSuffix("second.jpg") == true)
        XCTAssertNil(playlist.frame(at: 7, date: nil))
    }

    func testSingleJPEGSegmentsAndCRLF() throws {
        let text = "#EXTM3U\r\n#EXT-X-IMAGES-ONLY\r\n#EXTINF:3,\r\nframe.jpg\r\n#EXT-X-ENDLIST\r\n"
        let playlist = try HLSImagePlaylist(text: text, baseURL: baseURL)
        XCTAssertNil(playlist.frame(at: 2, date: nil)?.tile)
        XCTAssertEqual(playlist.frame(at: 2, date: nil)?.index, 0)
    }

    func testMalformedSpritesAndMissingImagesFailSafely() {
        XCTAssertThrowsError(try HLSImagePlaylist(text: "#EXTM3U\n#EXT-X-IMAGES-ONLY\n#EXT-X-TILES:RESOLUTION=320x180,LAYOUT=0x2,DURATION=2\n#EXTINF:4,\nimg.jpg", baseURL: baseURL))
        XCTAssertThrowsError(try HLSImagePlaylist(text: "#EXTM3U\n#EXT-X-IMAGES-ONLY\n#EXTINF:-1,\nimg.jpg", baseURL: baseURL))
        XCTAssertThrowsError(try HLSImagePlaylist(text: "#EXTM3U\n#EXT-X-IMAGES-ONLY", baseURL: baseURL))
    }
}

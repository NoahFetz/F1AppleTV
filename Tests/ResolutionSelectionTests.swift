import Foundation
import XCTest

final class ResolutionSelectionTests: XCTestCase {
    private let baseURL = URL(string: "https://cdn.example.com/redirected/master.m3u8?token=original")!
    private let fixture = """
    #EXTM3U
    #EXT-X-VERSION:7
    #EXT-X-INDEPENDENT-SEGMENTS
    #EXT-X-SESSION-KEY:METHOD=SAMPLE-AES,URI="skd://abasset",KEYFORMAT="com.apple.streamingkeydelivery"
    #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",URI="../audio/en.m3u8?signature=a,b=c"
    #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",URI="/subs/en.m3u8"
    #EXT-X-STREAM-INF:BANDWIDTH=128000,CODECS="mp4a.40.2"
    audio-only.m3u8
    #EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=960x540,CODECS="avc1.64001f,mp4a.40.2",AUDIO="audio",SUBTITLES="subs"
    low/video.m3u8?token=low
    #EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720,CODECS="avc1.64001f,mp4a.40.2",AUDIO="audio",SUBTITLES="subs"
    //media.example.com/720.m3u8?signed=yes
    #EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,AUDIO="audio",SUBTITLES="subs"
    https://media.example.com/high.m3u8?token=one%2Ftwo
    #EXT-X-STREAM-INF:BANDWIDTH=4000000,RESOLUTION=1920x1080,AUDIO="audio",SUBTITLES="subs"
    high/alternate.m3u8
    #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=50000,RESOLUTION=1280x720,URI="iframe/720.m3u8"
    #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=80000,RESOLUTION=1920x1080,URI="iframe/1080.m3u8"
    #EXT-X-CONTENT-STEERING:SERVER-URI="steering.json",PATHWAY-ID="primary"
    #EXT-X-CUSTOM-TAG:VALUE="preserve,me"
    """

    private let rangeFixture = """
    #EXTM3U
    #EXT-X-SESSION-KEY:METHOD=SAMPLE-AES,URI="skd://asset",KEYFORMAT="com.apple.streamingkeydelivery"
    #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",URI="audio.m3u8"
    #EXT-X-STREAM-INF:BANDWIDTH=17000000,RESOLUTION=3840x2160,VIDEO-RANGE=HLG,AUDIO="audio"
    hdr2160.m3u8
    #EXT-X-STREAM-INF:BANDWIDTH=7900000,RESOLUTION=1920x1080,VIDEO-RANGE=HLG,AUDIO="audio"
    hdr1080.m3u8
    #EXT-X-STREAM-INF:BANDWIDTH=8000000,RESOLUTION=1920x1080,VIDEO-RANGE=PQ,AUDIO="audio"
    pq1080.m3u8
    #EXT-X-STREAM-INF:BANDWIDTH=9500000,RESOLUTION=2880x1620,VIDEO-RANGE=SDR,AUDIO="audio"
    sdr1620.m3u8
    #EXT-X-STREAM-INF:BANDWIDTH=6600000,RESOLUTION=1920x1080,VIDEO-RANGE=SDR,AUDIO="audio"
    sdr1080.m3u8
    """

    func testSDRAndHDRSelectDifferentVariantsAtSameResolution() throws {
        let playlist = try HLSResolutionPlaylist(text: rangeFixture, baseURL: baseURL)
        let resolution = StreamResolution(attribute: "1920x1080")!
        let sdr = String(decoding: try playlist.filtered(resolution: resolution, dynamicRange: .sdr), as: UTF8.self)
        let hdr = String(decoding: try playlist.filtered(resolution: resolution, dynamicRange: .hdr), as: UTF8.self)
        XCTAssertTrue(sdr.contains("sdr1080.m3u8"))
        XCTAssertFalse(sdr.contains("hdr1080.m3u8"))
        XCTAssertFalse(sdr.contains("pq1080.m3u8"))
        XCTAssertTrue(hdr.contains("hdr1080.m3u8"))
        XCTAssertTrue(hdr.contains("pq1080.m3u8"))
        XCTAssertFalse(hdr.contains("sdr1080.m3u8"))
        for output in [sdr, hdr] {
            XCTAssertTrue(output.contains("skd://asset"))
            XCTAssertTrue(output.contains("GROUP-ID=\"audio\""))
        }
    }

    func testRangeSpecificQualityListsAndHighestSelection() throws {
        let playlist = try HLSResolutionPlaylist(text: rangeFixture, baseURL: baseURL)
        XCTAssertEqual(playlist.videoRanges, ["HLG", "PQ", "SDR"])
        XCTAssertEqual(playlist.resolutions(for: .hdr).map(\.height), [2160, 1080])
        XCTAssertEqual(playlist.resolutions(for: .sdr).map(\.height), [1620, 1080])
        XCTAssertEqual(playlist.startupResolution(maximumHeight: nil, dynamicRange: .sdr)?.height, 1620)
        XCTAssertEqual(playlist.startupResolution(maximumHeight: 2160, dynamicRange: .sdr)?.height, 1620)
        XCTAssertEqual(playlist.startupResolution(maximumHeight: 1080, dynamicRange: .hdr)?.height, 1080)
        XCTAssertThrowsError(try playlist.filtered(resolution: StreamResolution(attribute: "3840x2160"), dynamicRange: .sdr))
    }

    func testMissingRangeIsSDRAndHDRFallbackRemainsPlayable() throws {
        let playlist = try HLSResolutionPlaylist(text: fixture, baseURL: baseURL)
        XCTAssertEqual(playlist.videoRanges, ["SDR"])
        XCTAssertEqual(playlist.effectiveDynamicRange(.hdr), .sdr)
        XCTAssertEqual(try playlist.filtered(resolution: nil, dynamicRange: .hdr), try playlist.filtered(resolution: nil, dynamicRange: .sdr))
        let hdrOnly = try HLSResolutionPlaylist(text: "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=8000000,RESOLUTION=1920x1080,VIDEO-RANGE=HLG\nhdr.m3u8", baseURL: baseURL)
        XCTAssertEqual(hdrOnly.effectiveDynamicRange(.sdr), .hdr)
        XCTAssertEqual(hdrOnly.resolutions(for: .sdr).map(\.height), [1080])
    }

    func testFilteredMasterRejectsLocalFilesAndNonMediaSchemes() throws {
        for reference in ["file:///private/tmp/video.m3u8", "ftp://cdn.example.com/video.m3u8"] {
            let text = "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1920x1080\n" + reference
            let playlist = try HLSResolutionPlaylist(text: text, baseURL: baseURL)
            XCTAssertThrowsError(try playlist.filtered(resolution: nil))
        }
        let localAudio = fixture.replacingOccurrences(of: "../audio/en.m3u8?signature=a,b=c", with: "file:///private/tmp/audio.m3u8")
        XCTAssertThrowsError(try HLSResolutionPlaylist(text: localAudio, baseURL: baseURL).filtered(resolution: nil))
    }

    func testResolutionsAreSortedAndDeduplicated() throws {
        let playlist = try HLSResolutionPlaylist(text: fixture, baseURL: baseURL)
        XCTAssertEqual(playlist.resolutions.map { $0.label(in: playlist.resolutions) }, ["1080p", "720p", "540p"])
    }

    func testStartupHeightSelectsHighestAtOrBelowCapAndFallsBackToLowest() throws {
        let playlist = try HLSResolutionPlaylist(text: fixture, baseURL: baseURL)
        XCTAssertEqual(playlist.startupResolution(maximumHeight: nil)?.height, 1080)
        XCTAssertEqual(playlist.startupResolution(maximumHeight: 2160)?.height, 1080)
        XCTAssertEqual(playlist.startupResolution(maximumHeight: 1080)?.height, 1080)
        XCTAssertEqual(playlist.startupResolution(maximumHeight: 900)?.height, 720)
        XCTAssertEqual(playlist.startupResolution(maximumHeight: 360)?.height, 540)
    }

    func testDefaultKeepsOnlyHighestResolutionVariants() throws {
        let playlist = try HLSResolutionPlaylist(text: fixture, baseURL: baseURL)
        let output = String(decoding: try playlist.filtered(resolution: nil), as: UTF8.self)
        XCTAssertEqual(output.components(separatedBy: "#EXT-X-STREAM-INF:").count - 1, 2)
        XCTAssertTrue(output.contains("high.m3u8?token=one%2Ftwo"))
        XCTAssertTrue(output.contains("https://cdn.example.com/redirected/high/alternate.m3u8"))
        XCTAssertFalse(output.contains("#EXT-X-STREAM-INF:BANDWIDTH=3000000"))
        XCTAssertTrue(output.contains("iframe/720.m3u8"))
        XCTAssertFalse(output.contains("audio-only.m3u8"))
        XCTAssertFalse(output.contains("EXT-X-CONTENT-STEERING"))
    }

    func testFixedSelectionPreservesMediaAndDRM() throws {
        let playlist = try HLSResolutionPlaylist(text: fixture, baseURL: baseURL)
        let output = String(decoding: try playlist.filtered(resolution: StreamResolution(attribute: "1280x720")), as: UTF8.self)
        XCTAssertTrue(output.contains("URI=\"skd://abasset\""))
        XCTAssertTrue(output.contains("URI=\"https://cdn.example.com/audio/en.m3u8?signature=a,b=c\""))
        XCTAssertTrue(output.contains("URI=\"https://cdn.example.com/subs/en.m3u8\""))
        XCTAssertTrue(output.contains("https://media.example.com/720.m3u8?signed=yes"))
        XCTAssertTrue(output.contains("URI=\"https://cdn.example.com/redirected/iframe/720.m3u8\""))
        XCTAssertTrue(output.contains("CODECS=\"avc1.64001f,mp4a.40.2\""))
        XCTAssertTrue(output.contains("#EXT-X-CUSTOM-TAG:VALUE=\"preserve,me\""))
        XCTAssertTrue(output.contains("#EXT-X-INDEPENDENT-SEGMENTS"))
        XCTAssertFalse(output.contains("#EXT-X-STREAM-INF:BANDWIDTH=6000000"))
        XCTAssertTrue(output.contains("iframe/1080.m3u8"))
    }

    func testQuotedAttributesAndAudioOnlyVariant() throws {
        let tag = try EXT_X_STREAM_INF(text: "#EXT-X-STREAM-INF:BANDWIDTH=123,CODECS=\"avc1.64001f,mp4a.40.2\",AUDIO=\"audio\"\nvideo.m3u8", tagType: EXT_X_STREAM_INF.self, extraParams: nil)
        XCTAssertEqual(tag.attributes["CODECS"], "avc1.64001f,mp4a.40.2")
        XCTAssertEqual(tag.audio, "audio")
        XCTAssertEqual(tag.resolution, "")
    }

    func testRedirectBaseAndCRLF() throws {
        let playlist = try HLSResolutionPlaylist(text: fixture.replacingOccurrences(of: "\n", with: "\r\n"), baseURL: baseURL)
        let output = String(decoding: try playlist.filtered(resolution: StreamResolution(attribute: "960x540")), as: UTF8.self)
        XCTAssertTrue(output.contains("https://cdn.example.com/redirected/low/video.m3u8?token=low"))
    }

    func testMissingMetadataAndMalformedPlaylists() {
        XCTAssertThrowsError(try HLSResolutionPlaylist(text: "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=123\nvideo.m3u8", baseURL: baseURL))
        XCTAssertThrowsError(try HLSResolutionPlaylist(text: "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=123,RESOLUTION=1280x720", baseURL: baseURL))
        XCTAssertThrowsError(try HLSResolutionPlaylist(text: "", baseURL: baseURL))
        XCTAssertNil(StreamResolution(attribute: "0x1080"))
        XCTAssertNil(StreamResolution(attribute: "bad"))
    }

    func testUnsupportedReferencesFailRatherThanBreakPlayback() throws {
        let playlist = try HLSResolutionPlaylist(text: fixture.replacingOccurrences(of: "high/alternate.m3u8", with: "{$host}/video.m3u8"), baseURL: baseURL)
        XCTAssertThrowsError(try playlist.filtered(resolution: nil))
        XCTAssertThrowsError(try playlist.filtered(resolution: StreamResolution(attribute: "3840x2160")))
    }

    func testSameHeightLabelsAreUnambiguous() {
        let first = StreamResolution(attribute: "1920x1080")!
        let second = StreamResolution(attribute: "1440x1080")!
        XCTAssertEqual(first.label(in: [first, second]), "1920x1080")
        XCTAssertEqual(second.label(in: [first, second]), "1440x1080")
    }

    func testFailurePreservesCommittedChoice() {
        var state = ResolutionSwitchState()
        let resolution = StreamResolution(attribute: "1280x720")!
        let first = state.begin()
        XCTAssertNil(state.selected)
        XCTAssertTrue(state.finish(first, resolution: resolution, succeeded: true))
        let failed = state.begin()
        XCTAssertTrue(state.finish(failed, resolution: nil, succeeded: false))
        XCTAssertEqual(state.selected, resolution)
        let reset = state.begin()
        XCTAssertTrue(state.finish(reset, resolution: nil, succeeded: true))
        XCTAssertNil(state.selected)
    }

    func testRapidSelectionsIgnoreStaleCompletions() {
        var state = ResolutionSwitchState()
        let old = state.begin()
        let latest = state.begin()
        XCTAssertFalse(state.finish(old, resolution: StreamResolution(attribute: "1920x1080"), succeeded: true))
        XCTAssertEqual(state.pending, latest)
        XCTAssertTrue(state.finish(latest, resolution: StreamResolution(attribute: "1280x720"), succeeded: true))
        XCTAssertEqual(state.selected?.height, 720)
    }

    func testClosingStreamInvalidatesPendingSwitch() {
        var state = ResolutionSwitchState()
        let request = state.begin()
        state.cancel()
        XCTAssertFalse(state.finish(request, resolution: StreamResolution(attribute: "1280x720"), succeeded: true))
        XCTAssertNil(state.pending)
        XCTAssertNil(state.selected)
    }

}

@main
enum ResolutionTestRunner {
    static func main() {
        let suite = ResolutionSelectionTests.defaultTestSuite
        suite.run()
        let playbackSuite = FairPlayerResolutionTests.defaultTestSuite
        playbackSuite.run()
        let previewSuite = PreviewPlaylistTests.defaultTestSuite
        previewSuite.run()
        exit(suite.testRun?.totalFailureCount == 0 && playbackSuite.testRun?.totalFailureCount == 0 && previewSuite.testRun?.totalFailureCount == 0 ? 0 : 1)
    }
}

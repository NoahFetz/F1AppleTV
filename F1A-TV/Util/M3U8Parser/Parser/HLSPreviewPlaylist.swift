import Foundation

struct HLSPreviewManifest {
    let imagePlaylists: [URL]
    let hasIFrameRenditions: Bool

    init(text: String, baseURL: URL) {
        var images = [URL]()
        var hasIFrames = false
        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("#EXT-X-I-FRAME-STREAM-INF:") { hasIFrames = true }
            let prefix = "#EXT-X-IMAGE-STREAM-INF:"
            if line.hasPrefix(prefix) {
                let attributes = EXT_X_STREAM_INF.getAttributes(from: String(line.dropFirst(prefix.count)), seperatedBy: ",", extrasToRemove: ["\""])
                if let uri = attributes["URI"], !uri.contains("{$"),
                   let url = URL(string: uri, relativeTo: baseURL)?.absoluteURL,
                   ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                    images.append(url)
                }
            }
        }
        imagePlaylists = images
        hasIFrameRenditions = hasIFrames
    }
}

struct HLSImagePlaylist {
    struct Tile {
        let width: Int
        let height: Int
        let columns: Int
        let rows: Int
        let duration: Double
    }
    struct Segment {
        let url: URL
        let start: Double
        let duration: Double
        let date: Date?
        let tile: Tile?
    }
    struct Frame {
        let url: URL
        let tile: Tile?
        let index: Int
    }
    let segments: [Segment]
    let isLive: Bool

    init(text: String, baseURL: URL) throws {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: .newlines)
        guard lines.first == "#EXTM3U", lines.contains("#EXT-X-IMAGES-ONLY") else {
            throw HLSResolutionPlaylist.PlaylistError.malformed
        }
        var segments = [Segment]()
        var start: Double = 0
        var duration: Double?
        var tile: Tile?
        var date: Date?
        let dateParser = ISO8601DateFormatter()
        let fractionalDateParser = ISO8601DateFormatter()
        fractionalDateParser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for line in lines {
            if line.hasPrefix("#EXT-X-PROGRAM-DATE-TIME:") {
                let value = String(line.dropFirst("#EXT-X-PROGRAM-DATE-TIME:".count))
                date = fractionalDateParser.date(from: value) ?? dateParser.date(from: value)
            } else if line.hasPrefix("#EXT-X-TILES:") {
                let attrs = EXT_X_STREAM_INF.getAttributes(from: String(line.dropFirst("#EXT-X-TILES:".count)), seperatedBy: ",", extrasToRemove: ["\""])
                guard let size = attrs["RESOLUTION"].flatMap(StreamResolution.init(attribute:)),
                      let layout = attrs["LAYOUT"]?.split(separator: "x"), layout.count == 2,
                      let columns = Int(layout[0]), let rows = Int(layout[1]),
                      columns > 0, rows > 0, columns <= 100, rows <= 100,
                      let interval = attrs["DURATION"].flatMap(Double.init), interval.isFinite, interval > 0 else {
                    throw HLSResolutionPlaylist.PlaylistError.malformed
                }
                tile = Tile(width: size.width, height: size.height, columns: columns, rows: rows, duration: interval)
            } else if line.hasPrefix("#EXTINF:") {
                duration = Double(line.dropFirst("#EXTINF:".count).split(separator: ",").first ?? "")
            } else if !line.isEmpty && !line.hasPrefix("#"), let interval = duration {
                guard interval.isFinite, interval > 0, !line.contains("{$"),
                      let url = URL(string: line, relativeTo: baseURL)?.absoluteURL,
                      ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
                    throw HLSResolutionPlaylist.PlaylistError.malformed
                }
                segments.append(Segment(url: url, start: start, duration: interval, date: date, tile: tile))
                start += interval
                date = date?.addingTimeInterval(interval)
                duration = nil
                tile = nil
            }
        }
        guard !segments.isEmpty else { throw HLSResolutionPlaylist.PlaylistError.unavailable }
        self.segments = segments
        self.isLive = !lines.contains("#EXT-X-ENDLIST")
    }

    func frame(at time: Double, date: Date?) -> Frame? {
        guard time.isFinite else { return nil }
        for segment in segments {
            let offset: Double
            if let date = date, let startDate = segment.date {
                offset = date.timeIntervalSince(startDate)
            } else if !isLive {
                offset = time - segment.start
            } else {
                continue
            }
            guard offset >= 0, offset < segment.duration else { continue }
            let index = segment.tile.map { Int(min(floor(offset / $0.duration), Double($0.columns * $0.rows - 1))) } ?? 0
            return Frame(url: segment.url, tile: segment.tile, index: index)
        }
        return nil
    }
}

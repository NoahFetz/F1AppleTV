import Foundation

public struct HLSPreviewManifest {
    public struct IFrameRendition {
        public let url: URL
        public let resolution: StreamResolution?
        public let bandwidth: Double
        public let videoRange: String
    }
    public let imagePlaylists: [URL]
    public let iFrameRenditions: [IFrameRendition]
    public var hasIFrameRenditions: Bool { !iFrameRenditions.isEmpty }

    /// A scrub surface does not need the main feed's UHD/HDR rendition.
    public var preferredIFrameRendition: IFrameRendition? {
        let sdr = iFrameRenditions.filter { $0.videoRange == "SDR" }
        return (sdr.isEmpty ? iFrameRenditions : sdr).min {
            let left = $0.resolution.map { Double($0.width) * Double($0.height) } ?? .infinity
            let right = $1.resolution.map { Double($0.width) * Double($0.height) } ?? .infinity
            return left == right ? $0.bandwidth < $1.bandwidth : left < right
        }
    }

    public init(text: String, baseURL: URL) {
        var images = [URL]()
        var iFrames = [IFrameRendition]()
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let imagePrefix = "#EXT-X-IMAGE-STREAM-INF:"
            let iframePrefix = "#EXT-X-I-FRAME-STREAM-INF:"
            if line.hasPrefix(imagePrefix) || line.hasPrefix(iframePrefix) {
                let prefix = line.hasPrefix(imagePrefix) ? imagePrefix : iframePrefix
                let attributes = EXT_X_STREAM_INF.getAttributes(from: String(line.dropFirst(prefix.count)), seperatedBy: ",", extrasToRemove: ["\""])
                if let uri = attributes["URI"], !uri.contains("{$"),
                   let url = URL(string: uri, relativeTo: baseURL)?.absoluteURL,
                   ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                    if prefix == imagePrefix { images.append(url) }
                    else {
                        iFrames.append(IFrameRendition(url: url, resolution: attributes["RESOLUTION"].flatMap(StreamResolution.init(attribute:)),
                                                       bandwidth: attributes["BANDWIDTH"].flatMap(Double.init) ?? .infinity,
                                                       videoRange: (attributes["VIDEO-RANGE"] ?? "SDR").uppercased()))
                    }
                }
            }
        }
        imagePlaylists = images
        iFrameRenditions = iFrames
    }
}

public struct HLSImagePlaylist {
    public struct Tile {
        public let width: Int
        public let height: Int
        public let columns: Int
        public let rows: Int
        public let duration: Double
    }
    public struct Segment {
        public let url: URL
        public let start: Double
        public let duration: Double
        public let date: Date?
        public let tile: Tile?
    }
    public struct Frame {
        public let url: URL
        public let tile: Tile?
        public let index: Int
    }
    public let segments: [Segment]
    public let isLive: Bool

    public init(text: String, baseURL: URL) throws {
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

    public func frame(at time: Double, date: Date?) -> Frame? {
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

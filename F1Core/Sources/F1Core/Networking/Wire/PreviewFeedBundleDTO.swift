import Foundation

public struct PreviewFeedBundle: Sendable {
    let contentID: String
    let defaultChannelID: String?
    let feeds: [String: PlaybackEntitlement]

    public struct Composite: Sendable {
        public let url: URL
        public let videoRects: [String: CGRect]
    }
    public let composite: Composite?

    public func entitlement(for channel: PlaybackChannel) -> PlaybackEntitlement? {
        channelID(for: channel).flatMap { feeds[$0] }
    }

    public func channelID(for channel: PlaybackChannel) -> String? {
        guard channel.contentID == contentID else { return nil }
        let query = URLComponents(string: channel.target.uri)?.queryItems
        if let explicitID = query?.first(where: { $0.name == "channelId" }) {
            return explicitID.value
        }
        return channel.kind == .MainFeed ? defaultChannelID : nil
    }
}

struct PreviewFeedBundleDTO: Decodable {
    private struct Bundle: Decodable {
        struct Metadata: Decodable {
            let contentID: WireIdentifier?
            enum CodingKeys: String, CodingKey { case contentID = "content_id" }
        }

        struct Feed: Decodable {
            struct Metadata: Decodable {
                let channelID: WireIdentifier?
                enum CodingKeys: String, CodingKey { case channelID = "channel_id" }
            }
            let metadata: Metadata?
            let url: String?
            let uuid: String?
        }
        struct CompositeDTO: Decodable {
            struct Tile: Decodable {
                struct Rect: Decodable {
                    let x: Double, y: Double, width: Double, height: Double
                    enum CodingKeys: String, CodingKey { case x = "offset_x", y = "offset_y", width, height }

                    var videoRect: CGRect? {
                        let values = [x, y, width, height]
                        guard values.allSatisfy({ $0.isFinite && $0 >= 0 }),
                              width > 0, height > 0, x + width <= 1.000001, y + height <= 1.000001 else { return nil }
                        return CGRect(x: x, y: max(0, 1 - y - height), width: width, height: height)
                    }
                }
                let uuid: String
                let rect: Rect
                enum CodingKeys: String, CodingKey { case uuid, rect = "norm_rect" }
            }
            let url: String
            let tiles: LossyArray<Tile>
            enum CodingKeys: String, CodingKey { case url, tiles = "sub_feeds" }
        }

        let composites: LossyArray<CompositeDTO>?
        let metadata: Metadata?
        let feeds: LossyArray<Feed>?
        enum CodingKeys: String, CodingKey { case metadata, feeds, composites = "composite_feeds" }
    }

    private let channelId: WireIdentifier?
    private let entitlementToken: String?
    private let drmType: String?
    private let laURL: String?
    private let laUrl: String?
    private let tme: Bundle?

    func model(for contentID: String) -> PreviewFeedBundle? {
        guard let tme, let token = entitlementToken, !token.isEmpty else { return nil }
        if let bundledID = tme.metadata?.contentID?.value, bundledID != contentID { return nil }

        // Protected feeds still use their individual FairPlay entitlement.
        let drm = drmType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard ["", "none", "clear"].contains(drm),
              (laURL ?? "").isEmpty, (laUrl ?? "").isEmpty else { return nil }

        var feeds: [String: PlaybackEntitlement] = [:]
        var channelByUUID: [String: String] = [:]
        for feed in tme.feeds?.values ?? [] {
            guard let id = feed.metadata?.channelID?.value, !id.isEmpty, feeds[id] == nil,
                  let value = feed.url, let url = URL(string: value), url.scheme == "https",
                  url.host != nil, url.pathExtension.lowercased() == "m3u8" else { continue }
            if let uuid = feed.uuid { channelByUUID[uuid] = id }
            feeds[id] = PlaybackEntitlement(url: value, channelID: id, drmType: nil, licenseURL: nil, entitlementToken: token)
        }
        guard !feeds.isEmpty else { return nil }
        let composite = tme.composites?.values.lazy.compactMap { candidate -> PreviewFeedBundle.Composite? in
            guard let url = URL(string: candidate.url), url.scheme == "https", url.host != nil,
                  url.pathExtension.lowercased() == "m3u8" else { return nil }
            var rects: [String: CGRect] = [:]
            for tile in candidate.tiles.values {
                if let channel = channelByUUID[tile.uuid], let rect = tile.rect.videoRect { rects[channel] = rect }
            }
            guard !rects.isEmpty else { return nil }
            return .init(url: url, videoRects: rects)
        }.first
        return PreviewFeedBundle(contentID: contentID, defaultChannelID: channelId?.value, feeds: feeds, composite: composite)
    }
}

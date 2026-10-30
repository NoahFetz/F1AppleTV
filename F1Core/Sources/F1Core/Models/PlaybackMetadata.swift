import Foundation

/// Display context belongs to the session, not the channel's playback URL.
/// Artwork bytes are optional and never gate preparation of a stream.
public struct PlaybackMetadata: Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public let description: String?
    public let artworkID: String?
    public var artworkData: Data?

    public init(session: ContentItem, channel: PlaybackChannel? = nil, feedTitle: String? = nil) {
        func clean(_ value: String?) -> String? {
            guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return text
        }
        let contentTitle = clean(session.title) ?? clean(session.titleBrief) ?? ""
        let race = session.race
        let isSession = race?.videoType.lowercased() == "meetingsession"
        var meeting = isSession ? clean(race?.meetingName) ?? clean(race?.meetingOfficialName) ?? clean(race?.globalMeetingName) : nil
        if let name = meeting, let date = race?.sessionStartDate, date.timeIntervalSince1970 > 0 {
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let year = String(calendar.component(.year, from: date))
            if name.range(of: "(?<![0-9])" + year + "(?![0-9])", options: .regularExpression) == nil { meeting = name + " " + year }
        }
        let mainTitle = meeting ?? contentTitle
        title = mainTitle
        let driver = clean([channel?.driverFirstName, channel?.driverLastName].compactMap { $0 }.joined(separator: " "))
        let feed = clean(feedTitle) ?? (channel?.kind == .OnBoardCamera ? driver : nil) ?? clean(channel?.title)
        let sessionTitle = isSession ? clean(session.titleBrief) ?? clean(session.title) : nil
        subtitle = [sessionTitle, feed].compactMap { $0 }.filter { $0 != mainTitle }.reduce(into: [String]()) { values, value in
            if !values.contains(value) { values.append(value) }
        }.joined(separator: " • ")
        description = clean(session.longDescription)
        artworkID = clean(session.pictureUrl) ?? clean(channel?.artwork)
    }
}

/// Playback rate is intentionally absent: pausing must not change the owner.
public struct NowPlayingFeed: Sendable {
    public let id: String
    public let isAvailable: Bool
    public let isMuted: Bool
    public let volume: Float
    public init(id: String, isAvailable: Bool, isMuted: Bool, volume: Float) {
        self.id = id; self.isAvailable = isAvailable; self.isMuted = isMuted; self.volume = volume
    }
    /// Inputs are ordered main-first. Focus never participates in this choice.
    public static func owner(in feeds: [NowPlayingFeed]) -> String? {
        let available = feeds.filter(\.isAvailable)
        let audible = available.filter { !$0.isMuted && $0.volume.isFinite && $0.volume > 0 }
        return audible.count == 1 ? audible[0].id : available.first?.id
    }
}

import Foundation

public struct CatalogDestination: Equatable, Sendable {
    public init(uri: String, href: String = "") { self.uri = uri; self.href = href }

    public let uri: String
    public var href: String = ""
}
public struct PlaybackTarget: Equatable, Sendable {
    public init(uri: String, requiresVideoDetails: Bool) { self.uri = uri; self.requiresVideoDetails = requiresVideoDetails }

    public let uri: String
    public let requiresVideoDetails: Bool
}
public enum CatalogAction: Sendable { case destination(CatalogDestination), playback(PlaybackTarget) }

public struct RaceMetadata: Sendable {
    public init(meetingName: String? = nil, videoType: String = "", meetingKey: String = "", meetingCountryKey: String? = nil, meetingCountryName: String? = nil, globalMeetingName: String? = nil, meetingOfficialName: String? = nil, meetingDisplayDate: String? = nil, championshipMeetingOrdinal: String? = nil, series: String? = nil, sessionStartDate: Date? = nil, sessionEndDate: Date? = nil) { self.meetingName = meetingName; self.videoType = videoType; self.meetingKey = meetingKey; self.meetingCountryKey = meetingCountryKey; self.meetingCountryName = meetingCountryName; self.globalMeetingName = globalMeetingName; self.meetingOfficialName = meetingOfficialName; self.meetingDisplayDate = meetingDisplayDate; self.championshipMeetingOrdinal = championshipMeetingOrdinal; self.series = series; self.sessionStartDate = sessionStartDate; self.sessionEndDate = sessionEndDate }

    public var meetingName: String?
    public var videoType: String = ""
    public var meetingKey: String = ""
    public var meetingCountryKey: String?
    public var meetingCountryName: String?
    public var globalMeetingName: String?
    public var meetingOfficialName: String?
    public var meetingDisplayDate: String?
    public var championshipMeetingOrdinal: String?
    public var series: String?
    public var sessionStartDate: Date?
    public var sessionEndDate: Date?
}

/// Values needed by a card or destination, independent of the API's container hierarchy.
public struct ContentItem: Identifiable, Sendable {
    public init() {  }

    public var id = ""
    public var objectType: ContentObjectType = .Unknown
    public var title: String?
    public var titleBrief: String?
    public var longDescription: String?
    public var label: String?
    public var contentId: String?
    public var pictureUrl: String?
    public var uiDuration: String?
    public var contentSubtype: String?
    public var race: RaceMetadata?
    public var series: String?
    public var interactive: Bool?
    public var locked: Bool?
    public var action: CatalogAction?
    public var channel: PlaybackChannel?
    public var resumePosition: Double?
    public var channelType: ChannelType? { channel?.kind }
    public var previewIdentity: String { channel?.id ?? id }
    public var canPlay: Bool { objectType == .Video && (contentId.flatMap(Int64.init) ?? 0) > 0 && interactive != false && locked != true }
}

public struct PlaybackChannel: Identifiable, Sendable {
    public init(id: String, target: PlaybackTarget, kind: ChannelType, contentID: String, title: String, racingNumber: Int = 0, driverFirstName: String? = nil, driverLastName: String? = nil, teamName: String = "", driverImg: String = "", teamImg: String = "", hex: String? = nil, artwork: String? = nil, contentSubtype: String? = nil, resumePosition: Double? = nil) { self.id = id; self.target = target; self.kind = kind; self.contentID = contentID; self.title = title; self.racingNumber = racingNumber; self.driverFirstName = driverFirstName; self.driverLastName = driverLastName; self.teamName = teamName; self.driverImg = driverImg; self.teamImg = teamImg; self.hex = hex; self.artwork = artwork; self.contentSubtype = contentSubtype; self.resumePosition = resumePosition }

    public let id: String
    public let target: PlaybackTarget
    public let kind: ChannelType
    public let contentID: String
    public let title: String
    public var racingNumber: Int = 0
    public var driverFirstName: String?
    public var driverLastName: String?
    public var teamName = ""
    public var driverImg = ""
    public var teamImg = ""
    public var hex: String?
    public var artwork: String?
    public var contentSubtype: String?
    public var resumePosition: Double?
    public var displayItem: ContentItem {
        var item = ContentItem(); item.id = id; item.objectType = .Video
        item.title = title; item.contentId = contentID; item.pictureUrl = artwork; item.contentSubtype = contentSubtype
        item.channel = self; item.action = .playback(target); item.resumePosition = resumePosition
        return item
    }
}
public struct VideoDetails: Sendable {
    public init(item: ContentItem, channels: [PlaybackChannel]) { self.item = item; self.channels = channels }

    public let item: ContentItem
    public let channels: [PlaybackChannel]
    public var isLive: Bool { item.contentSubtype == "LIVE" }
}
public struct CatalogDocument: Sendable {
    public init(sections: [ContentSection]) { self.sections = sections }
 public let sections: [ContentSection] }

public enum CatalogSectionContent: Sendable {
    case row([ContentItem]), grid([ContentItem]), hero([ContentItem]), banner(ContentItem), destination(ContentItem)
    case heading, schedule(CatalogSchedule)
}
public struct ContentSection: Identifiable, Sendable {
    public init() {  }

    public var id = ""
    public var title = ""
    public var subtitle = ""
    public var layoutType: ContainerLayoutType = .ContentItem
    public var content: CatalogSectionContent = .grid([])
    public var total: Int?
    public var viewAllAction: CatalogDestination?
    public var artwork: String?
    public var schedule: CatalogSchedule? { if case .schedule(let value) = content { return value }; return nil }
    public var items: [ContentItem] {
        get {
            switch content {
            case .row(let items), .grid(let items), .hero(let items): return items
            case .banner(let item), .destination(let item): return [item]
            case .heading, .schedule: return []
            }
        }
        set {
            switch layoutType {
            case .Hero: content = .hero(newValue)
            case .GpBanner: if let first = newValue.first { content = .banner(first) } else { content = .grid([]) }
            case .PageHeader: if let first = newValue.first { content = .destination(first) } else { content = .grid([]) }
            default: content = layoutType.isHorizontal ? .row(newValue) : .grid(newValue)
            }
        }
    }
}

public struct CatalogSchedule: Sendable {
    public struct Group: Sendable { public let name: String; public let label: String; public let events: [ContentItem] }
    public struct Day: Sendable { public let date: Date?; public let events: [ContentItem] }
    public let groups: [Group]
    public init(groups: [Group]) {
        var groups = groups
        if let index = groups.firstIndex(where: { $0.name == "ALL" }) { groups.insert(groups.remove(at: index), at: 0) }
        else if !groups.isEmpty { groups.insert(Group(name: "ALL", label: "ALL", events: Self.unique(groups.flatMap(\.events))), at: 0) }
        self.groups = groups.map { Group(name: $0.name, label: $0.label, events: Self.unique($0.events)) }
    }
    public func days(groupName: String, calendar: Calendar = .current) -> [Day] {
        let events = groups.first(where: { $0.name == groupName })?.events ?? groups.first?.events ?? []
        let sorted = events.enumerated().sorted {
            let lhs = Self.startDate($0.element) ?? .distantFuture, rhs = Self.startDate($1.element) ?? .distantFuture
            return lhs == rhs ? $0.offset < $1.offset : lhs < rhs
        }.map(\.element)
        var days = [Day]()
        for event in sorted {
            let date = Self.startDate(event).map { calendar.startOfDay(for: $0) }
            if let last = days.last, last.date == date { days[days.count - 1] = Day(date: date, events: last.events + [event]) }
            else { days.append(Day(date: date, events: [event])) }
        }
        return days
    }
    public static func startDate(_ event: ContentItem) -> Date? { event.race?.sessionStartDate }
    public static func canPlay(_ event: ContentItem) -> Bool { event.canPlay }
    private static func unique(_ events: [ContentItem]) -> [ContentItem] { var seen = Set<String>(); return events.filter { seen.insert($0.id).inserted } }
}

import Foundation

struct CatalogDestination: Equatable, Sendable {
    let uri: String
    var href: String = ""
}
struct PlaybackTarget: Equatable, Sendable {
    let uri: String
    let requiresVideoDetails: Bool
}
enum CatalogAction: Sendable { case destination(CatalogDestination), playback(PlaybackTarget) }

struct RaceMetadata: Sendable {
    var videoType: String = ""
    var meetingKey: String = ""
    var meetingCountryKey: String?
    var meetingCountryName: String?
    var globalMeetingName: String?
    var meetingOfficialName: String?
    var meetingDisplayDate: String?
    var championshipMeetingOrdinal: String?
    var series: String?
    var sessionStartDate: Date?
    var sessionEndDate: Date?
}

/// Values needed by a card or destination, independent of the API's container hierarchy.
struct ContentItem: Identifiable, Sendable {
    var id = ""
    var objectType: ContentObjectType = .Unknown
    var title: String?
    var titleBrief: String?
    var longDescription: String?
    var label: String?
    var contentId: String?
    var pictureUrl: String?
    var uiDuration: String?
    var contentSubtype: String?
    var race: RaceMetadata?
    var series: String?
    var interactive: Bool?
    var locked: Bool?
    var action: CatalogAction?
    var channel: PlaybackChannel?
    var resumePosition: Double?
    var channelType: ChannelType? { channel?.kind }
    var previewIdentity: String { channel?.id ?? id }
    var canPlay: Bool { objectType == .Video && (contentId.flatMap(Int64.init) ?? 0) > 0 && interactive != false && locked != true }
}

struct PlaybackChannel: Identifiable, Sendable {
    let id: String
    let target: PlaybackTarget
    let kind: ChannelType
    let contentID: String
    let title: String
    var racingNumber: Int = 0
    var driverFirstName: String?
    var driverLastName: String?
    var teamName = ""
    var driverImg = ""
    var teamImg = ""
    var hex: String?
    var artwork: String?
    var contentSubtype: String?
    var resumePosition: Double?
    var displayItem: ContentItem {
        var item = ContentItem(); item.id = id; item.objectType = .Video
        item.title = title; item.contentId = contentID; item.pictureUrl = artwork; item.contentSubtype = contentSubtype
        item.channel = self; item.action = .playback(target); item.resumePosition = resumePosition
        return item
    }
}
struct VideoDetails: Sendable {
    let item: ContentItem
    let channels: [PlaybackChannel]
    var isLive: Bool { item.contentSubtype == "LIVE" }
}
struct CatalogDocument: Sendable { let sections: [ContentSection] }

enum CatalogSectionContent: Sendable {
    case row([ContentItem]), grid([ContentItem]), hero([ContentItem]), banner(ContentItem), destination(ContentItem)
    case heading, schedule(CatalogSchedule)
}
struct ContentSection: Identifiable, Sendable {
    var id = ""
    var title = ""
    var subtitle = ""
    var layoutType: ContainerLayoutType = .ContentItem
    var content: CatalogSectionContent = .grid([])
    var total: Int?
    var viewAllAction: CatalogDestination?
    var artwork: String?
    var schedule: CatalogSchedule? { if case .schedule(let value) = content { return value }; return nil }
    var items: [ContentItem] {
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

struct CatalogSchedule: Sendable {
    struct Group: Sendable { let name: String; let label: String; let events: [ContentItem] }
    struct Day: Sendable { let date: Date?; let events: [ContentItem] }
    let groups: [Group]
    init(groups: [Group]) {
        var groups = groups
        if let index = groups.firstIndex(where: { $0.name == "ALL" }) { groups.insert(groups.remove(at: index), at: 0) }
        else if !groups.isEmpty { groups.insert(Group(name: "ALL", label: "ALL", events: Self.unique(groups.flatMap(\.events))), at: 0) }
        self.groups = groups.map { Group(name: $0.name, label: $0.label, events: Self.unique($0.events)) }
    }
    func days(groupName: String, calendar: Calendar = .current) -> [Day] {
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
    static func startDate(_ event: ContentItem) -> Date? { event.race?.sessionStartDate }
    static func canPlay(_ event: ContentItem) -> Bool { event.canPlay }
    private static func unique(_ events: [ContentItem]) -> [ContentItem] { var seen = Set<String>(); return events.filter { seen.insert($0.id).inserted } }
}

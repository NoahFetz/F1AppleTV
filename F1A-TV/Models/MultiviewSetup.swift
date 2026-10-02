import Foundation

/// A cross-session selection, never a playback URL or entitlement.
enum StreamSelection: Codable, Equatable, Hashable {
    case international, f1Live, tracker, data, pitLane
    case driver(number: Int, name: String)
    case additional(name: String)

    static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ")
    }
    init(channel: PlaybackChannel) {
        if channel.kind == .MainFeed { self = .international; return }
        if channel.kind == .OnBoardCamera {
            self = .driver(number: channel.racingNumber, name: Self.normalized([channel.driverFirstName, channel.driverLastName].compactMap { $0 }.joined(separator: " ")))
            return
        }
        switch Self.normalized(channel.title) {
        case "f1 live": self = .f1Live
        case "tracker", "driver tracker": self = .tracker
        case "data", "data channel": self = .data
        case "pit lane", "pit lane channel": self = .pitLane
        default: self = .additional(name: Self.normalized(channel.title))
        }
    }
    func matches(_ channel: PlaybackChannel) -> Bool {
        let other = StreamSelection(channel: channel)
        if case .driver(let number, let name) = self, case .driver(let otherNumber, let otherName) = other {
            // A matching name protects against racing-number reuse in another season.
            if !name.isEmpty && !otherName.isEmpty { return name == otherName }
            return number > 0 && number == otherNumber
        }
        return self == other
    }
}

enum PlaybackSelection {
    static func initialChannel(in channels: [PlaybackChannel], preference: DefaultFeed) -> PlaybackChannel? {
        if preference == .f1Live, let live = channels.first(where: { StreamSelection(channel: $0) == .f1Live }) { return live }
        return channels.first(where: { $0.kind == .MainFeed }) ?? channels.first
    }
}

struct SavedStream: Codable, Equatable {
    let selection: StreamSelection
    var volume: Float
    var muted: Bool
}
struct MultiviewSetup: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var layout: MultiviewLayout
    // The first stream is the main/reference stream.
    var streams: [SavedStream]
}
struct ResolvedSetup {
    var channels: [PlaybackChannel]
    var audio: [SavedStream]
    var missingCount: Int
}
enum SetupResolver {
    static func resolve(_ setup: MultiviewSetup, channels: [PlaybackChannel]) -> ResolvedSetup {
        var result = ResolvedSetup(channels: [], audio: [], missingCount: 0)
        var used = Set<String>()
        for stream in setup.streams {
            guard let channel = channels.first(where: { !used.contains($0.id) && stream.selection.matches($0) }) else {
                result.missingCount += 1; continue
            }
            used.insert(channel.id); result.channels.append(channel); result.audio.append(stream)
        }
        return result
    }
}

/// Stored independently of player preferences and credentials.
@MainActor
final class MultiviewSetupStore {
    static let shared = MultiviewSetupStore()
    private let defaults: UserDefaults
    private let key = "MultiviewSetups.v1"
    private struct Archive: Codable { var version = 1; let setups: [MultiviewSetup] }
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> [MultiviewSetup] {
        guard let data = defaults.data(forKey: key), let archive = try? JSONDecoder().decode(Archive.self, from: data), archive.version == 1 else { return [] }
        var ids = Set<UUID>()
        return archive.setups.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.streams.isEmpty && ids.insert($0.id).inserted }
    }
    func save(_ setup: MultiviewSetup) throws {
        var copy = setup
        copy.name = setup.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !copy.name.isEmpty, !copy.streams.isEmpty else { return }
        copy.streams = copy.streams.map { SavedStream(selection: $0.selection, volume: $0.volume.isFinite ? min(1, max(0, $0.volume)) : 1, muted: $0.muted) }
        var setups = load()
        if let index = setups.firstIndex(where: { $0.id == copy.id }) { setups[index] = copy } else { setups.append(copy) }
        try write(setups)
    }
    func delete(id: UUID) throws { try write(load().filter { $0.id != id }) }
    private func write(_ setups: [MultiviewSetup]) throws {
        defaults.set(try JSONEncoder().encode(Archive(setups: setups)), forKey: key)
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
    static let didChange = Notification.Name("MultiviewSetupsChanged")
}

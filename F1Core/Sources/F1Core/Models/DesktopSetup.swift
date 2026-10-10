import Foundation

public struct DesktopWindowFrame: Codable, Equatable {
    public var x: Double, y: Double, width: Double, height: Double
    public var displayID: UInt32?
    public init(rect: CGRect, displayID: UInt32?) {
        x = rect.minX; y = rect.minY; width = rect.width; height = rect.height; self.displayID = displayID
    }
    public var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
    public func visibleRect(on visibleFrame: CGRect) -> CGRect {
        let valid = [x, y, width, height].allSatisfy(\.isFinite) && width > 0 && height > 0
        let proposed = valid ? rect : CGRect(x: visibleFrame.midX - 320, y: visibleFrame.midY - 220, width: 640, height: 440)
        let w = min(max(480, proposed.width), visibleFrame.width)
        let h = min(max(320, proposed.height), visibleFrame.height)
        return CGRect(x: max(visibleFrame.minX, min(proposed.minX, visibleFrame.maxX - w)),
                      y: max(visibleFrame.minY, min(proposed.minY, visibleFrame.maxY - h)), width: w, height: h)
    }
}
public struct DesktopSavedFeed: Codable, Equatable {
    public var stream: SavedStream
    public var window: DesktopWindowFrame?
    public init(stream: SavedStream, window: DesktopWindowFrame?) { self.stream = stream; self.window = window }
}
public struct DesktopSetup: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var feeds: [DesktopSavedFeed]
    public init(id: UUID = UUID(), name: String, feeds: [DesktopSavedFeed]) { self.id = id; self.name = name; self.feeds = feeds }
    public func resolve(channels: [PlaybackChannel]) -> [(PlaybackChannel, DesktopSavedFeed)] {
        var used = Set<String>()
        return feeds.compactMap { feed in
            guard let channel = channels.first(where: { !used.contains($0.id) && feed.stream.selection.matches($0) }) else { return nil }
            used.insert(channel.id); return (channel, feed)
        }
    }
}
@MainActor public final class DesktopSetupStore {
    private let defaults: UserDefaults
    private let key = "DesktopSetups.v1"
    private struct Archive: Codable { var version = 1; var setups: [DesktopSetup] }
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func load() -> [DesktopSetup] {
        guard let data = defaults.data(forKey: key), let archive = try? JSONDecoder().decode(Archive.self, from: data), archive.version == 1 else { return [] }
        var ids = Set<UUID>()
        return archive.setups.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.feeds.isEmpty && ids.insert($0.id).inserted }
    }
    public func save(_ setup: DesktopSetup) throws {
        var setup = setup; setup.name = setup.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !setup.name.isEmpty, !setup.feeds.isEmpty else { return }
        setup.feeds = setup.feeds.map { feed in
            var feed = feed
            feed.stream.volume = feed.stream.volume.isFinite ? min(1, max(0, feed.stream.volume)) : 1
            return feed
        }
        var setups = load(); setups.removeAll { $0.id == setup.id }; setups.append(setup)
        defaults.set(try JSONEncoder().encode(Archive(setups: setups)), forKey: key)
    }
    public func delete(_ id: UUID) throws {
        defaults.set(try JSONEncoder().encode(Archive(setups: load().filter { $0.id != id })), forKey: key)
    }
}

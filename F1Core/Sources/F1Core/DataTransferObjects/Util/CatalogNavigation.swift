import Foundation

public struct CatalogMenuEntry: Codable, Equatable {
    public init(title: String, uri: String, href: String) { self.title = title; self.uri = uri; self.href = href }

    public let title: String
    public let uri: String
    public let href: String
    public var identity: String { uri }

}

public struct PreviewWindow {
    public static func indices(visible: Set<Int>, count: Int) -> Set<Int> {
        let valid = visible.filter { $0 >= 0 && $0 < count }
        guard let first = valid.min(), let last = valid.max() else { return [] }
        return Set(max(0, first - 1)...min(count - 1, last + 1))
    }
}

/// Only successful responses replace the language-specific fallback menu.
public struct CatalogMenuCache {
    public init(defaults: UserDefaults) { self.defaults = defaults }

    public let defaults: UserDefaults
    public func load(language: String) -> [CatalogMenuEntry] {
        guard let data = defaults.data(forKey: "CatalogMenu.\(language)") else { return [] }
        return (try? JSONDecoder().decode([CatalogMenuEntry].self, from: data)) ?? []
    }
    public func store(_ entries: [CatalogMenuEntry], language: String) {
        guard !entries.isEmpty, let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: "CatalogMenu.\(language)")
    }
}

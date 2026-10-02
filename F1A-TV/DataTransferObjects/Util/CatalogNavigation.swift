import Foundation

struct CatalogMenuEntry: Codable, Equatable {
    let title: String
    let uri: String
    let href: String
    var identity: String { uri }

}

struct PreviewWindow {
    static func indices(visible: Set<Int>, count: Int) -> Set<Int> {
        let valid = visible.filter { $0 >= 0 && $0 < count }
        guard let first = valid.min(), let last = valid.max() else { return [] }
        return Set(max(0, first - 1)...min(count - 1, last + 1))
    }
}

/// Only successful responses replace the language-specific fallback menu.
struct CatalogMenuCache {
    let defaults: UserDefaults
    func load(language: String) -> [CatalogMenuEntry] {
        guard let data = defaults.data(forKey: "CatalogMenu.\(language)") else { return [] }
        return (try? JSONDecoder().decode([CatalogMenuEntry].self, from: data)) ?? []
    }
    func store(_ entries: [CatalogMenuEntry], language: String) {
        guard !entries.isEmpty, let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: "CatalogMenu.\(language)")
    }
}

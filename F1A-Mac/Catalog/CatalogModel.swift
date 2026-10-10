import SwiftUI
import F1Core

@MainActor final class CatalogModel: ObservableObject {
    struct Route { let destination: CatalogDestination; let item: ContentItem?; let title: String }
    @Published var menu: [CatalogMenuEntry] = []
    @Published var sections: [ContentSection] = []
    @Published var history: [Route] = []
    @Published var loading = false
    @Published var error: String?
    @Published var artworkID: String?
    var usesEventBackground: Bool {
        CatalogPresentation.isEventDestination(history.last?.item, sections: sections)
    }
    private let services: MacServices
    private var task: Task<Void, Never>?
    private var generation = UUID()
    init(services: MacServices) { self.services = services }
    var title: String { history.last?.title ?? "Vroom TV" }
    func start() async {
        let cache = CatalogMenuCache(defaults: .standard)
        menu = cache.load(language: services.language)
        do { menu = try await services.catalog.menu(); cache.store(menu, language: services.language) }
        catch { recordServiceFailure(error, operation: .menu); self.error = "Could not load navigation. Retry to reconnect." }
        if let first = menu.first, history.isEmpty { select(first) }
    }
    func select(_ entry: CatalogMenuEntry) {
        history = [Route(destination: CatalogDestination(uri: entry.uri, href: entry.href), item: nil, title: entry.title)]; load()
    }
    func navigate(_ destination: CatalogDestination, item: ContentItem? = nil, title: String? = nil) {
        history.append(Route(destination: destination, item: item, title: title ?? item?.title ?? "Browse")); load()
    }
    func back() { guard history.count > 1 else { return }; history.removeLast(); load() }
    func load() {
        guard let route = history.last else { Task { await start() }; return }
        task?.cancel(); generation = UUID(); let epoch = generation
        loading = true; error = nil
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let document = try await services.catalog.page(route.destination)
                try Task.checkCancellation(); guard generation == epoch else { return }
                sections = CatalogPresentation.sections(document.sections, destination: route.item)
                artworkID = route.item?.pictureUrl ?? sections.first(where: { [.Hero, .GpBanner, .PageHeader].contains($0.layoutType) })?.items.first?.pictureUrl
                loading = false
            } catch {
                guard !Task.isCancelled, generation == epoch else { return }
                recordServiceFailure(error, operation: .page); loading = false; self.error = "Could not load this page. Please retry."
            }
        }
    }
    deinit { task?.cancel() }
}

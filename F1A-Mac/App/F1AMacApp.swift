import SwiftUI
import AppKit

@MainActor final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DesktopApplicationIcon.install()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
@main struct F1AMacApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var delegate
    @Environment(\.openWindow) private var openWindow
    private let services: MacServices
    @StateObject private var catalog: CatalogModel
    @StateObject private var session: DesktopSession
    init() {
        DesktopTypography.register()
        let services = MacServices(); self.services = services
        _catalog = StateObject(wrappedValue: CatalogModel(services: services))
        _session = StateObject(wrappedValue: DesktopSession(services: services))
    }
    var body: some Scene {
        Window("Vroom TV", id: "catalog") {
            MainCatalogView(model: catalog, session: session, preferences: services.preferences).frame(minWidth: 800, minHeight: 560)
                .task {
                    DesktopApplicationIcon.install()
                    #if DEBUG
                    if let value = ProcessInfo.processInfo.environment["F1_PLAYBACK_FIXTURE_URL"], let url = URL(string: value), session.feeds.isEmpty { session.openLocalFixture(url) }
                    #endif
                }
        }.defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(after: .windowArrangement) { Button("Show Catalog") { showCatalog() }.keyboardShortcut("0", modifiers: .command) }
            CommandMenu("Playback") { SessionMenu(session: session) }
            #if DEBUG
            CommandMenu("Development") { Button("Open Local HLS Fixture…") { session.promptLocalFixture() } }
            #endif
        }
    }
    private func showCatalog() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "catalog" || $0.title == "Vroom TV" }) { window.makeKeyAndOrderFront(nil) }
        else { openWindow(id: "catalog") }
    }
}

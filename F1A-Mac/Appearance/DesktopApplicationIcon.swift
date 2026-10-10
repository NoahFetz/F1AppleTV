import AppKit

@MainActor enum DesktopApplicationIcon {
    @discardableResult static func install(from bundle: Bundle = .main) -> Bool {
        guard let url = bundle.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: url), icon.isValid else { return false }
        // AppKit panels ask the named-image cache, while the Dock uses NSApp.
        // Refresh both after adding an icon to an existing development build.
        let applicationIconName = NSImage.Name("NSApplicationIcon")
        NSApp.applicationIconImage = icon
        NSImage(named: applicationIconName)?.setName(nil)
        icon.setName(applicationIconName)
        return true
    }
}

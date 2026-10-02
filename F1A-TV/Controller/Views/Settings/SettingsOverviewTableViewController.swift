import UIKit

/// Programmatic settings panels; the historic name is retained for existing callers.
final class SettingsOverviewTableViewController: UIViewController {
    private var settings = CredentialHelper.getPlayerSettings()
    private var stack: UIStackView!
    private weak var lastFocusedControl: UIView?
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if let lastFocusedControl, lastFocusedControl.window != nil { return [lastFocusedControl] }
        return stack?.arrangedSubviews.compactMap { $0 as? TVActionButton }.first.map { [$0] } ?? super.preferredFocusEnvironments
    }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if let next = context.nextFocusedView, next.isDescendant(of: view) { lastFocusedControl = next }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        stack = TVDesign.stack(in: view, title: "settings_title".localizedString)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let latest = CredentialHelper.getPlayerSettings()
        guard stack.arrangedSubviews.count <= 1 || (try? JSONEncoder().encode(latest)) != (try? JSONEncoder().encode(settings)) else { return }
        settings = latest
        stack.arrangedSubviews.dropFirst().forEach { $0.removeFromSuperview() }
        renderControls()
    }
    private func renderControls() {
        section("Browsing")
        choice("Background", values: ["Follow hero", "Static branding"], selected: settings.followsHeroBackground ? 0 : 1) { self.settings.followsHeroBackground = $0 == 0 }
        section("Previews")
        choice("Live previews", values: ["On", "Off"], selected: settings.livePreviews ? 0 : 1) { self.settings.livePreviews = $0 == 0 }
        choice("Preview quality", values: ["360p", "540p"], selected: settings.previewHeight == 540 ? 1 : 0) { self.settings.previewHeight = $0 == 0 ? 360 : 540 }
        section("Playback")
        choice("default_feed".localizedString, values: ["international_feed_title".localizedString, "f1_live_feed_title".localizedString], selected: settings.defaultFeed == .f1Live ? 1 : 0) { self.settings.defaultFeed = $0 == 1 ? .f1Live : .international }
        stack.addArrangedSubview(TVDesign.button("saved_setups".localizedString) { [weak self] in
            self?.presentFullscreen(viewController: SetupPickerViewController())
        })
        let heights: [Int?] = [nil, 2160, 1080, 720]
        choice("Startup quality", values: ["Highest", "2160p", "1080p", "720p"], selected: heights.firstIndex(of: settings.startupMaximumHeight) ?? 0) { self.settings.startupMaximumHeight = heights[$0] }
        choice("Start live sessions", values: ["Ask", "Live", "From beginning"], selected: LiveStartPreference.allCases.firstIndex(of: settings.liveStart) ?? 0) { self.settings.liveStart = LiveStartPreference.allCases[$0] }
        section("Audio and captions")
        let codes = ["default", "en", "de", "fr", "es", "nl", "pt"]
        let languages = ["Stream default", "English", "Deutsch", "Français", "Español", "Nederlands", "Português"]
        for type in ChannelType.allCases {
            let id = type.getIdentifier()
            let name = ["Main Feed", "Additional Feed", "Onboard"][id]
            let audio = settings.audioDefaults[id]
            let legacyAudio = settings.preferredChannelLanguage[id] ?? nil
            choice(name + " · Audio", values: languages, selected: codes.firstIndex(of: audio ?? "default") ?? 0, legacy: audio == nil ? legacyAudio : nil) { self.settings.audioDefaults[id] = codes[$0] }
            let captions = settings.captionDefaults[id]
            let legacyCaptions = settings.preferredChannelCaptions[id] ?? nil
            let captionCodes = ["off"] + codes
            choice(name + " · Captions", values: ["Off"] + languages, selected: captionCodes.firstIndex(of: captions ?? "default") ?? 1, legacy: captions == nil ? legacyCaptions : nil) { self.settings.captionDefaults[id] = captionCodes[$0] }
        }
        section("Channels")
        choice("Driver sorting", values: DriverChannelSortType.allCases.map { $0.getDisplayName() }, selected: settings.driverChannelSorting.rawValue) { self.settings.driverChannelSorting = DriverChannelSortType(rawValue: $0) ?? DriverChannelSortType() }
        choice("Fun driver names", values: ["Off", "On"], selected: settings.showFunNames ? 1 : 0) { self.settings.showFunNames = $0 == 1 }
        section("diagnostics_title".localizedString)
        stack.addArrangedSubview(TVDesign.button("diagnostics_error_log".localizedString) { [weak self] in
            self?.presentFullscreen(viewController: ErrorLogViewController())
        })
        section("About")
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        stack.addArrangedSubview(TVDesign.button("About F1 Apple TV") { [weak self] in
            let about = UIViewController()
            about.view.backgroundColor = ConstantsUtil.brandingBackgroundColor
            let panel = TVDesign.stack(in: about.view, title: "About")
            panel.addArrangedSubview(TVDesign.label("F1 Apple TV · \(version) (\(build))"))
            panel.addArrangedSubview(TVDesign.label("disclaimer".localizedString, size: 25))
            panel.addArrangedSubview(TVDesign.button("Close") { [weak about] in about?.dismiss(animated: true) })
            self?.present(about, animated: true)
        })
    }
    private func section(_ title: String) { stack.addArrangedSubview(TVDesign.label(title, size: 30, bold: true)) }
    private func choice(_ title: String, values: [String], selected: Int, legacy: String? = nil, change: @escaping (Int) -> Void) {
        let button = TVActionButton(type: .custom)
        button.contentHorizontalAlignment = .left
        var current = min(max(0, selected), values.count - 1)
        button.setTitle(title + "    ·    " + (legacy ?? values[current]), for: .normal)
        button.addAction(UIAction { [weak self, weak button] _ in
            guard let self else { return }
            let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
            for (index, value) in values.enumerated() {
                alert.addAction(UIAlertAction(title: value + (index == current && legacy == nil ? " ✓" : ""), style: .default) { _ in
                    current = index; change(index)
                    button?.setTitle(title + "    ·    " + value, for: .normal)
                    CredentialHelper.setPlayerSettings(playerSettings: self.settings)
                    NotificationCenter.default.post(name: .tvSettingsChanged, object: nil)
                })
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self.present(alert, animated: true)
        }, for: .primaryActionTriggered)
        stack.addArrangedSubview(button)
    }
}

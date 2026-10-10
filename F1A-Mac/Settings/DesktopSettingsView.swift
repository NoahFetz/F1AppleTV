import SwiftUI
import F1Core

struct DesktopSettingsView: View {
    @ObservedObject var preferences: MacPreferences
    @ObservedObject var session: DesktopSession
    private let languages = [("default", "Stream default"), ("en", "English"), ("de", "Deutsch"), ("fr", "Français"), ("es", "Español"), ("nl", "Nederlands"), ("pt", "Português")]
    var body: some View {
        Form {
            Section("Appearance") {
                Toggle("Follow featured artwork", isOn: $preferences.player.followsHeroBackground)
            }
            Section("Playback") {
                Toggle("settings_scrub_previews".localizedString, isOn: Binding(get: { preferences.player.scrubPreviews }, set: { preferences.player.scrubPreviews = $0 }))
                Text("settings_scrub_previews_detail".localizedString).font(.caption).foregroundStyle(.secondary)
                Picker("Dynamic range for new players", selection: $preferences.dynamicRange) {
                    ForEach(PlayerDynamicRange.allCases) { Text($0.label).tag($0) }
                }
                Picker("Default feed", selection: $preferences.player.defaultFeed) { Text("International").tag(DefaultFeed.international); Text("F1 Live").tag(DefaultFeed.f1Live) }
                Picker("Startup quality", selection: $preferences.player.startupMaximumHeight) {
                    Text("Highest").tag(Int?.none); ForEach([2160, 1080, 720], id: \.self) { Text(verbatim: "\($0)p").tag(Optional($0)) }
                }
                Picker("Start live sessions", selection: $preferences.player.liveStart) { Text("Ask").tag(LiveStartPreference.ask); Text("Live").tag(LiveStartPreference.live); Text("From beginning").tag(LiveStartPreference.beginning) }
                Picker("Driver sorting", selection: $preferences.player.driverChannelSorting) { ForEach(DriverChannelSortType.allCases, id: \.self) { Text($0.getDisplayName()).tag($0) } }
            }
            ForEach(ChannelType.allCases, id: \.self) { type in
                Section(["Main feed", "Additional feed", "Onboard"][type.getIdentifier()]) {
                    Picker("Audio", selection: language(type, captions: false)) { ForEach(languages, id: \.0) { Text($0.1).tag($0.0) } }
                    Picker("Captions", selection: language(type, captions: true)) { Text("Off").tag("off"); ForEach(languages, id: \.0) { Text($0.1).tag($0.0) } }
                    Slider(value: Binding(get: { preferences.player.getPreferredVolume(for: type) }, set: { preferences.player.setPreferredVolume(for: type, volume: $0) }), in: 0...1) { Text("Initial volume") }
                    Toggle("Initially muted", isOn: Binding(get: { preferences.player.getPreferredMute(for: type) }, set: { preferences.player.setPreferredMute(for: type, mute: $0) }))
                }
            }
            Section("Saved setups") {
                if session.setups.isEmpty { Text("Save a setup from a playback window to restore feeds and window positions.").foregroundStyle(.secondary) }
                ForEach(session.setups) { setup in
                    HStack {
                        Text(setup.name); Spacer()
                        Button("Load") { session.restore(setup) }.disabled(session.details == nil)
                        Button("Delete", role: .destructive) { session.deleteSetup(setup.id) }
                    }
                }
            }
            Section("About") {
                Text("Vroom TV for macOS")
                Text("disclaimer".localizedString).font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).scrollContentBackground(.hidden).navigationTitle("Settings")
    }
    private func language(_ type: ChannelType, captions: Bool) -> Binding<String> {
        Binding(get: { (captions ? preferences.player.captionDefaults : preferences.player.audioDefaults)[type.getIdentifier()] ?? "default" }, set: { value in
            if captions { preferences.player.captionDefaults[type.getIdentifier()] = value }
            else { preferences.player.audioDefaults[type.getIdentifier()] = value }
        })
    }
}

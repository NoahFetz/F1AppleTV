import AVFoundation

/// Startup media preferences shared by the native and multiview players.
enum PlaybackDefaults {
    @MainActor
    static func apply(to item: AVPlayerItem, channel: ChannelType, settings: PlayerSettings, isCurrent: () -> Bool) async {
        guard !Task.isCancelled, isCurrent() else { return }
        let id = channel.getIdentifier()
        for (kind, preference, legacy) in [
            (AVMediaCharacteristic.audible, settings.audioDefaults[id], settings.preferredChannelLanguage[id] ?? nil),
            (AVMediaCharacteristic.legible, settings.captionDefaults[id], settings.preferredChannelCaptions[id] ?? nil)
        ] {
            guard let group = try? await item.asset.loadMediaSelectionGroup(for: kind) else { continue }
            guard !Task.isCancelled, isCurrent() else { return }
            if preference == "off", group.allowsEmptySelection { item.select(nil, in: group); continue }
            if preference == "default" { item.selectMediaOptionAutomatically(in: group); continue }
            let option: AVMediaSelectionOption?
            if let code = preference {
                option = group.options.first { ($0.extendedLanguageTag ?? $0.locale?.language.languageCode?.identifier ?? "").lowercased().split(separator: "-").first.map(String.init) == code }
            } else {
                option = group.options.first { $0.displayName == legacy }
            }
            if let option { item.select(option, in: group) }
            else if preference != nil { item.selectMediaOptionAutomatically(in: group) }
        }
    }
}

import UIKit
#if canImport(F1Core)
import F1Core
#endif

extension TVPlayerPreference {
    var tvDisplayName: String {
        switch self {
        case .native: return "player_native".localizedString
        case .multiview: return "player_multiview".localizedString
        case .ask: return "player_ask".localizedString
        }
    }
}

/// The native feed menu and multiview picker share names and ordering.
enum TVPlaybackChannels {
    static func items(for channels: [PlaybackChannel], settings: PlayerSettings) -> [ContentItem] {
        channels.map { channel -> ContentItem in
            var item = channel.displayItem
            if channel.kind == .MainFeed { item.title = "international_feed_title".localizedString }
            else if channel.kind == .OnBoardCamera {
                let name = [channel.driverFirstName, channel.driverLastName].compactMap { $0 }.joined(separator: " ")
                let alternate = AlternateUniverseDrivers.fromOriginalName(originalName: name)
                item.title = settings.showFunNames && alternate != .None ? alternate.getAlternateName() : name.isEmpty ? channel.title : name
            } else {
                let keys = ["TRACKER": "tracker_feed_title", "PIT LANE": "pit_lane_feed_title", "DATA": "data_feed_title", "F1 LIVE": "f1_live_feed_title"]
                item.title = keys[channel.title].map { $0.localizedString } ?? channel.title
            }
            return item
        }.sorted {
            let lhs = $0.channelType ?? .MainFeed, rhs = $1.channelType ?? .MainFeed
            if lhs != rhs { return lhs.getIdentifier() < rhs.getIdentifier() }
            if settings.driverChannelSorting == .DriverNumber { return ($0.channel?.racingNumber ?? 0) < ($1.channel?.racingNumber ?? 0) }
            return ($0.channel?.title ?? "") < ($1.channel?.title ?? "")
        }
    }
}

extension FairPlayer {
    func resolutionMenu() -> UIMenu {
        let symbol = UIImage(systemName: "slider.horizontal.3")
        guard resolutionStatus == .available || resolutionStatus == .switching else {
            let title = resolutionStatus == .loading ? "Loading resolutions..." : "Resolutions unavailable"
            return UIMenu(title: "Resolution", image: symbol, children: [UIAction(title: title, attributes: .disabled) { _ in }])
        }
        let disabled: UIMenuElement.Attributes = resolutionStatus == .switching ? .disabled : []
        let defaultTitle = availableResolutions.first.map { "Default (\($0.label(in: availableResolutions)))" } ?? "Default"
        var actions: [UIMenuElement] = [UIAction(title: defaultTitle, attributes: disabled, state: selectedResolution == nil ? .on : .off) { [weak self] _ in
            self?.selectResolution(nil)
        }]
        actions += availableResolutions.map { resolution in
            UIAction(title: resolution.label(in: availableResolutions), attributes: disabled, state: selectedResolution == resolution ? .on : .off) { [weak self] _ in
                self?.selectResolution(resolution)
            }
        }
        if resolutionStatus == .switching {
            actions.insert(UIAction(title: "Changing resolution...", attributes: .disabled) { _ in }, at: 0)
        }
        if let error = resolutionError {
            actions.append(UIAction(title: error, attributes: .disabled) { _ in })
        }
        return UIMenu(title: "Resolution", image: symbol, children: actions)
    }

}

func tvPlaybackError(_ error: Error) {
    UserInteractionHelper.instance.showError(title: "error".localizedString, message: "diagnostics_summary_operation".localizedString, recordsError: false)
}

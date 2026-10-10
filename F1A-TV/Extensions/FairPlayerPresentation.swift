import UIKit
#if canImport(F1Core)
import F1Core
#endif

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

import Foundation

final class UserInteractionHelper {
    static let instance = UserInteractionHelper()
    func showError(title: String, message: String, recordsError: Bool = true) { print("\(title): \(message)") }
}

extension String { var localizedString: String { self } }

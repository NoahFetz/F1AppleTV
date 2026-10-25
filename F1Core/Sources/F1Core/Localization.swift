import Foundation
public enum CoreLocalization {
    public static var locale: Locale {
        #if SWIFT_PACKAGE
        return Locale(identifier: Bundle.module.preferredLocalizations.first ?? "en")
        #else
        return Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        #endif
    }
    public static func string(_ key: String) -> String {
        #if SWIFT_PACKAGE
        return NSLocalizedString(key, bundle: .module, comment: "")
        #else
        return NSLocalizedString(key, comment: "")
        #endif
    }
}

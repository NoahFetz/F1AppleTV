import Foundation
public enum CoreLocalization {
    public static func string(_ key: String) -> String {
        #if SWIFT_PACKAGE
        return NSLocalizedString(key, bundle: .module, comment: "")
        #else
        return NSLocalizedString(key, comment: "")
        #endif
    }
}

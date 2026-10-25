import Foundation

public struct AccountProfile: Codable, Equatable, Sendable {
    public let firstName: String, lastName: String, email: String, country: String, subscriberID: Int
    public let subscriptionStatus: String
    public var hasSubscription: Bool { subscriptionStatus == "active" }
    public var localizedSubscriptionStatus: String {
        let status = subscriptionStatus.lowercased()
        let key: String
        switch status {
        case "active", "inactive", "expired", "suspended": key = "account_status_" + status
        case "cancelled", "canceled": key = "account_status_cancelled"
        default: key = "account_status_unknown"
        }
        return CoreLocalization.string(key)
    }
}

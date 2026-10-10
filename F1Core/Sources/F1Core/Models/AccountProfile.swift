import Foundation

public struct AccountProfile: Codable, Equatable, Sendable {
    public let firstName: String, lastName: String, email: String, country: String, subscriberID: Int
    public let subscriptionStatus: String
    public var hasSubscription: Bool { subscriptionStatus == "active" }
}

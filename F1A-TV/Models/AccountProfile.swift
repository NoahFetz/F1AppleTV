import Foundation

struct AccountProfile: Equatable, Sendable {
    let firstName: String, lastName: String, email: String, country: String, subscriberID: Int
    let subscriptionStatus: String
    var hasSubscription: Bool { subscriptionStatus == "active" }
}

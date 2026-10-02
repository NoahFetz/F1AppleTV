import Foundation

/// Account response data is separate from the legacy Keychain serialization.
struct AccountTokenDTO: Decodable {
    let subscriptionToken: String
    let subscriptionStatus: String?
    var stored: AuthDataDto { AuthDataDto(subscriptionStatus: subscriptionStatus ?? "", subscriptionToken: subscriptionToken) }
}
struct AccountDisplayDTO: Decodable {
    let firstName: String?, lastName: String?, homeCountry: String?, email: String?, login: String?
    let subscriberID: WireIdentifier?
    enum CodingKeys: String, CodingKey {
        case firstName = "FirstName", lastName = "LastName", homeCountry = "HomeCountry", email = "Email", login = "Login", subscriberID = "SubscriberId", id = "Id"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName); lastName = try c.decodeIfPresent(String.self, forKey: .lastName)
        homeCountry = try c.decodeIfPresent(String.self, forKey: .homeCountry); email = try c.decodeIfPresent(String.self, forKey: .email)
        login = try c.decodeIfPresent(String.self, forKey: .login)
        subscriberID = try c.decodeIfPresent(WireIdentifier.self, forKey: .subscriberID) ?? c.decodeIfPresent(WireIdentifier.self, forKey: .id)
    }
    var stored: DeviceRegistrationSessionSummaryDto {
        var value = DeviceRegistrationSessionSummaryDto()
        value.firstName = firstName ?? ""; value.lastName = lastName ?? ""; value.homeCountry = homeCountry ?? ""
        value.email = email ?? ""; value.login = login ?? ""; value.subscriberId = subscriberID.flatMap { Int($0.value) } ?? -1
        return value
    }
}
struct AccountRegistrationDTO: Decodable {
    struct Device: Decodable {
        let authenticationKey: String, deviceID: WireIdentifier
        enum CodingKeys: String, CodingKey { case authenticationKey = "AuthenticationKey", deviceID = "DeviceId" }
    }
    let device: Device, sessionID: String, summary: AccountDisplayDTO?, data: AccountTokenDTO
    enum CodingKeys: String, CodingKey { case device = "PhysicalDevice", sessionID = "SessionId", summary = "SessionSummary", data }
    func stored() throws -> DeviceRegistrationResultDto {
        guard !device.authenticationKey.isEmpty, !device.deviceID.value.isEmpty, !sessionID.isEmpty, !data.subscriptionToken.isEmpty else { throw APIError.authentication }
        var value = DeviceRegistrationResultDto()
        value.physicalDevice.authenticationKey = device.authenticationKey; value.physicalDevice.deviceId = device.deviceID.value
        value.sessionId = sessionID; value.sessionSummary = summary?.stored ?? DeviceRegistrationSessionSummaryDto(); value.data = data.stored
        return value
    }
}
struct AccountRefreshDTO: Decodable {
    let authenticationKey: String, subscriber: AccountDisplayDTO?, data: AccountTokenDTO
    enum CodingKeys: String, CodingKey { case authenticationKey = "AuthenticationKey", subscriber = "Subscriber", data }
}

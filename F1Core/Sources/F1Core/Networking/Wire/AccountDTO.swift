import Foundation

/// Account response data is separate from the legacy Keychain serialization.
public struct AccountTokenDTO: Decodable {
    public let subscriptionToken: String
    public let subscriptionStatus: String?
    public var stored: AuthDataDto { AuthDataDto(subscriptionStatus: subscriptionStatus ?? "", subscriptionToken: subscriptionToken) }
}
public struct AccountDisplayDTO: Decodable {
    public let firstName: String?, lastName: String?, homeCountry: String?, email: String?, login: String?
    public let subscriberID: WireIdentifier?
    public enum CodingKeys: String, CodingKey {
        case firstName = "FirstName", lastName = "LastName", homeCountry = "HomeCountry", email = "Email", login = "Login", subscriberID = "SubscriberId", id = "Id"
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName); lastName = try c.decodeIfPresent(String.self, forKey: .lastName)
        homeCountry = try c.decodeIfPresent(String.self, forKey: .homeCountry); email = try c.decodeIfPresent(String.self, forKey: .email)
        login = try c.decodeIfPresent(String.self, forKey: .login)
        subscriberID = try c.decodeIfPresent(WireIdentifier.self, forKey: .subscriberID) ?? c.decodeIfPresent(WireIdentifier.self, forKey: .id)
    }
    public var stored: DeviceRegistrationSessionSummaryDto {
        var value = DeviceRegistrationSessionSummaryDto()
        value.firstName = firstName ?? ""; value.lastName = lastName ?? ""; value.homeCountry = homeCountry ?? ""
        value.email = email ?? ""; value.login = login ?? ""; value.subscriberId = subscriberID.flatMap { Int($0.value) } ?? -1
        return value
    }
}
public struct AccountRegistrationDTO: Decodable {
    public struct Device: Decodable {
        public let authenticationKey: String, deviceID: WireIdentifier
        public enum CodingKeys: String, CodingKey { case authenticationKey = "AuthenticationKey", deviceID = "DeviceId" }
    }
    public let device: Device, sessionID: String, summary: AccountDisplayDTO?, data: AccountTokenDTO
    public enum CodingKeys: String, CodingKey { case device = "PhysicalDevice", sessionID = "SessionId", summary = "SessionSummary", data }
    public func stored() throws -> DeviceRegistrationResultDto {
        guard !device.authenticationKey.isEmpty, !device.deviceID.value.isEmpty, !sessionID.isEmpty, !data.subscriptionToken.isEmpty else { throw APIError.authentication }
        var value = DeviceRegistrationResultDto()
        value.physicalDevice.authenticationKey = device.authenticationKey; value.physicalDevice.deviceId = device.deviceID.value
        value.sessionId = sessionID; value.sessionSummary = summary?.stored ?? DeviceRegistrationSessionSummaryDto(); value.data = data.stored
        return value
    }
}
public struct AccountRefreshDTO: Decodable {
    public let authenticationKey: String, subscriber: AccountDisplayDTO?, data: AccountTokenDTO
    public enum CodingKeys: String, CodingKey { case authenticationKey = "AuthenticationKey", subscriber = "Subscriber", data }
}

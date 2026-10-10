//
//  DeviceRegistrationSessionSummaryDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

public struct DeviceRegistrationSessionSummaryDto: Codable {
    public var email: String
    public var externalAuthorizations: [DeviceRegistrationSessionSummaryExternalAuthorizationDto]?
    public var firstName: String
    public var homeCountry: String
    public var lastName: String
    public var login: String
    public var subscriberId: Int
    public var subscriberLanguage: String?
    public var termsAndConditionsAccepted: String?
    public var title: String?
    
    public init() {
        self.email = ""
        self.firstName = ""
        self.homeCountry = ""
        self.lastName = ""
        self.login = ""
        self.subscriberId = -1
    }

    public init(email: String, externalAuthorizations: [DeviceRegistrationSessionSummaryExternalAuthorizationDto]?, firstName: String, homeCountry: String, lastName: String, login: String, subscriberId: Int, subscriberLanguage: String?, termsAndConditionsAccepted: String?, title: String?) {
        self.email = email
        self.externalAuthorizations = externalAuthorizations
        self.firstName = firstName
        self.homeCountry = homeCountry
        self.lastName = lastName
        self.login = login
        self.subscriberId = subscriberId
        self.subscriberLanguage = subscriberLanguage
        self.termsAndConditionsAccepted = termsAndConditionsAccepted
        self.title = title
    }
    
    public enum CodingKeys: String, CodingKey {
        case email = "Email"
        case externalAuthorizations = "ExternalAuthorizations"
        case firstName = "FirstName"
        case homeCountry = "HomeCountry"
        case lastName = "LastName"
        case login = "Login"
        case subscriberId = "SubscriberId"
        case subscriberLanguage = "SubscriberLanguage"
        case termsAndConditionsAccepted = "TermsAndConditionsAccepted"
        case title = "Title"
    }
}

//
//  DeviceRegistrationSessionSummaryExternalAuthorizationDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

struct DeviceRegistrationSessionSummaryExternalAuthorizationDto: Codable {
    var contextData: String?
    var id: Int?
    var provider: Int?
    var subscriberExternalReference: String?
    var tokenActive: Bool?

    init() {
    }
    
    init(contextData: String?, id: Int?, provider: Int?, subscriberExternalReference: String?, tokenActive: Bool?) {
        self.contextData = contextData
        self.id = id
        self.provider = provider
        self.subscriberExternalReference = subscriberExternalReference
        self.tokenActive = tokenActive
    }
    
    enum CodingKeys: String, CodingKey {
        case contextData = "ContextData"
        case id = "Id"
        case provider = "Provider"
        case subscriberExternalReference = "SubscriberExternalReference"
        case tokenActive = "TokenActive"
    }
}

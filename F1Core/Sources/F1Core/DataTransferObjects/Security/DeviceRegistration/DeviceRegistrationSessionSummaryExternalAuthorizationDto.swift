//
//  DeviceRegistrationSessionSummaryExternalAuthorizationDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

public struct DeviceRegistrationSessionSummaryExternalAuthorizationDto: Codable {
    public var contextData: String?
    public var id: Int?
    public var provider: Int?
    public var subscriberExternalReference: String?
    public var tokenActive: Bool?

    public init() {
    }
    
    public init(contextData: String?, id: Int?, provider: Int?, subscriberExternalReference: String?, tokenActive: Bool?) {
        self.contextData = contextData
        self.id = id
        self.provider = provider
        self.subscriberExternalReference = subscriberExternalReference
        self.tokenActive = tokenActive
    }
    
    public enum CodingKeys: String, CodingKey {
        case contextData = "ContextData"
        case id = "Id"
        case provider = "Provider"
        case subscriberExternalReference = "SubscriberExternalReference"
        case tokenActive = "TokenActive"
    }
}

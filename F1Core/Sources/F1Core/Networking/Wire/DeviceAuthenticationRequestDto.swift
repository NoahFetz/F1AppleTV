//
//  DeviceAuthenticationRequestDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

public struct DeviceAuthenticationRequestDto: Encodable {
    public var distributionChannel: String
    public var authenticationKey: String
    public var language: String
    public var deviceId: String
    
    public init(distributionChannel: String, authenticationKey: String, language: String, deviceId: String) {
        self.distributionChannel = distributionChannel
        self.authenticationKey = authenticationKey
        self.language = language
        self.deviceId = deviceId
    }
    
    public enum CodingKeys: String, CodingKey {
        case distributionChannel = "DistributionChannel"
        case authenticationKey = "AuthenticationKey"
        case language = "Language"
        case deviceId = "DeviceId"
    }
}

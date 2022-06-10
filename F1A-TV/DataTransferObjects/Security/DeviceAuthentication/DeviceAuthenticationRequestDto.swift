//
//  DeviceAuthenticationRequestDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

struct DeviceAuthenticationRequestDto: Codable {
    var distributionChannel: String
    var authenticationKey: String
    var language: String
    var deviceId: String
    
    init() {
        self.distributionChannel = ConstantsUtil.deviceRegistrationDistributionChannel
        self.authenticationKey = CredentialHelper.instance.getDeviceRegistration().physicalDevice.authenticationKey
        self.language = "en-GB"
        self.deviceId = CredentialHelper.instance.getDeviceRegistration().physicalDevice.deviceId
    }
    
    init(distributionChannel: String, authenticationKey: String, language: String, deviceId: String) {
        self.distributionChannel = distributionChannel
        self.authenticationKey = authenticationKey
        self.language = language
        self.deviceId = deviceId
    }
    
    enum CodingKeys: String, CodingKey {
        case distributionChannel = "DistributionChannel"
        case authenticationKey = "AuthenticationKey"
        case language = "Language"
        case deviceId = "DeviceId"
    }
}

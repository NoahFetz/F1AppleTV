//
//  DeviceUnregistrationRequestDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

struct DeviceUnregistrationRequestDto: Codable {
    var deviceId: String
    var authenticationKey: String

    init() {
        self.deviceId = CredentialHelper.instance.getDeviceRegistration().physicalDevice.deviceId
        self.authenticationKey = CredentialHelper.instance.getDeviceRegistration().physicalDevice.authenticationKey
    }
    
    init(deviceId: String, authenticationKey: String) {
        self.deviceId = deviceId
        self.authenticationKey = authenticationKey
    }
    
    enum CodingKeys: String, CodingKey {
        case deviceId = "DeviceId"
        case authenticationKey = "AuthenticationKey"
    }
}

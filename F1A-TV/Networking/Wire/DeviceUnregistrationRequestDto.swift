//
//  DeviceUnregistrationRequestDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

struct DeviceUnregistrationRequestDto: Encodable {
    var deviceId: String
    var authenticationKey: String

    init(deviceId: String, authenticationKey: String) {
        self.deviceId = deviceId
        self.authenticationKey = authenticationKey
    }
    
    enum CodingKeys: String, CodingKey {
        case deviceId = "DeviceId"
        case authenticationKey = "AuthenticationKey"
    }
}

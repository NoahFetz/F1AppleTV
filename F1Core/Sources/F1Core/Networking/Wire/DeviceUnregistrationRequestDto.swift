//
//  DeviceUnregistrationRequestDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

public struct DeviceUnregistrationRequestDto: Encodable {
    public var deviceId: String
    public var authenticationKey: String

    public init(deviceId: String, authenticationKey: String) {
        self.deviceId = deviceId
        self.authenticationKey = authenticationKey
    }
    
    public enum CodingKeys: String, CodingKey {
        case deviceId = "DeviceId"
        case authenticationKey = "AuthenticationKey"
    }
}

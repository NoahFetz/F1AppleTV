//
//  DeviceRegistrationRequestDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

public struct DeviceRegistrationRequestDto: Encodable {
    public var physicalDevice: DeviceRegistrationRequestDeviceDto
    public var nickname: String
    public var login: String
    public var password: String
    
    public init(physicalDevice: DeviceRegistrationRequestDeviceDto, nickname: String, login: String, password: String) {
        self.physicalDevice = physicalDevice
        self.nickname = nickname
        self.login = login
        self.password = password
    }
    
    public enum CodingKeys: String, CodingKey {
        case physicalDevice = "PhysicalDevice"
        case nickname = "Nickname"
        case login = "Login"
        case password = "Password"
    }
}

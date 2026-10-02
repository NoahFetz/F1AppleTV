//
//  DeviceRegistrationRequestDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

struct DeviceRegistrationRequestDto: Encodable {
    var physicalDevice: DeviceRegistrationRequestDeviceDto
    var nickname: String
    var login: String
    var password: String
    
    init(physicalDevice: DeviceRegistrationRequestDeviceDto, nickname: String, login: String, password: String) {
        self.physicalDevice = physicalDevice
        self.nickname = nickname
        self.login = login
        self.password = password
    }
    
    enum CodingKeys: String, CodingKey {
        case physicalDevice = "PhysicalDevice"
        case nickname = "Nickname"
        case login = "Login"
        case password = "Password"
    }
}

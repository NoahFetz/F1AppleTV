//
//  DeviceRegistrationRequestDeviceDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

class DeviceRegistrationRequestDeviceDto: Codable {
    var deviceTypeCode: Int
    var deviceId: String
    var physicalDeviceTypeCode: Int

    init() {
        self.deviceTypeCode = 12 //10 -> iPhone, 11 -> iPad, 12 -> AppleTV
        self.deviceId = "\(UUID().uuidString)-tvOS"
        self.physicalDeviceTypeCode = 1002
    }
    
    init(deviceTypeCode: Int, deviceId: String, physicalDeviceTypeCode: Int) {
        self.deviceTypeCode = deviceTypeCode
        self.deviceId = deviceId
        self.physicalDeviceTypeCode = physicalDeviceTypeCode
    }
    
    enum CodingKeys: String, CodingKey {
        case deviceTypeCode = "DeviceTypeCode"
        case deviceId = "DeviceId"
        case physicalDeviceTypeCode = "PhysicalDeviceTypeCode"
    }
}

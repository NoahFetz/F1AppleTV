//
//  DeviceRegistrationRequestDeviceDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

public class DeviceRegistrationRequestDeviceDto: Encodable {
    public var deviceTypeCode: Int
    public var deviceId: String
    public var physicalDeviceTypeCode: Int

    public init() {
        self.deviceTypeCode = 12 //10 -> iPhone, 11 -> iPad, 12 -> AppleTV
        self.deviceId = "\(UUID().uuidString)-tvOS"
        self.physicalDeviceTypeCode = 1002
    }
    
    public init(deviceTypeCode: Int, deviceId: String, physicalDeviceTypeCode: Int) {
        self.deviceTypeCode = deviceTypeCode
        self.deviceId = deviceId
        self.physicalDeviceTypeCode = physicalDeviceTypeCode
    }
    
    public enum CodingKeys: String, CodingKey {
        case deviceTypeCode = "DeviceTypeCode"
        case deviceId = "DeviceId"
        case physicalDeviceTypeCode = "PhysicalDeviceTypeCode"
    }
}

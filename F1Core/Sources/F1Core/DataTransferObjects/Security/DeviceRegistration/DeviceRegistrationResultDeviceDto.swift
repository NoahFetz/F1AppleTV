//
//  DeviceRegistrationResultDeviceDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

// Legacy Keychain serialization only. Endpoint responses decode through AccountDTO.

public struct DeviceRegistrationResultDeviceDto: Codable {
    public var addDate: String
    public var authenticationKey: String
    public var deviceId: String
    public var deviceTypeCode: Int
    public var deviceTypeName: String
    public var id: Int
    public var modDate: String
    public var physicalDeviceTypeCode: Int
    public var serialNumber: String
    public var status: Int
    public var statusName: String

    public init() {
        self.addDate = ""
        self.authenticationKey = ""
        self.deviceId = ""
        self.deviceTypeCode = -1
        self.deviceTypeName = ""
        self.id = -1
        self.modDate = ""
        self.physicalDeviceTypeCode = -1
        self.serialNumber = ""
        self.status = -1
        self.statusName = ""
    }
    
    public init(addDate: String, authenticationKey: String, deviceId: String, deviceTypeCode: Int, deviceTypeName: String, id: Int, modDate: String, physicalDeviceTypeCode: Int, serialNumber: String, status: Int, statusName: String) {
        self.addDate = addDate
        self.authenticationKey = authenticationKey
        self.deviceId = deviceId
        self.deviceTypeCode = deviceTypeCode
        self.deviceTypeName = deviceTypeName
        self.id = id
        self.modDate = modDate
        self.physicalDeviceTypeCode = physicalDeviceTypeCode
        self.serialNumber = serialNumber
        self.status = status
        self.statusName = statusName
    }
    
    public enum CodingKeys: String, CodingKey {
        case addDate = "AddDate"
        case authenticationKey = "AuthenticationKey"
        case deviceId = "DeviceId"
        case deviceTypeCode = "DeviceTypeCode"
        case deviceTypeName = "DeviceTypeName"
        case id = "Id"
        case modDate = "ModDate"
        case physicalDeviceTypeCode = "PhysicalDeviceTypeCode"
        case serialNumber = "SerialNumber"
        case status = "Status"
        case statusName = "StatusName"
    }
}

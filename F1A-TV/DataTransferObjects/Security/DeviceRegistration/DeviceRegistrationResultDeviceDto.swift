//
//  DeviceRegistrationResultDeviceDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

struct DeviceRegistrationResultDeviceDto: Codable {
    var addDate: String
    var authenticationKey: String
    var deviceId: String
    var deviceTypeCode: Int
    var deviceTypeName: String
    var id: Int
    var modDate: String
    var physicalDeviceTypeCode: Int
    var serialNumber: String
    var status: Int
    var statusName: String

    init() {
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
    
    init(addDate: String, authenticationKey: String, deviceId: String, deviceTypeCode: Int, deviceTypeName: String, id: Int, modDate: String, physicalDeviceTypeCode: Int, serialNumber: String, status: Int, statusName: String) {
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
    
    enum CodingKeys: String, CodingKey {
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

//
//  DeviceRegistrationResultDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

struct DeviceRegistrationResultDto: Codable {
    var physicalDevice: DeviceRegistrationResultDeviceDto
    var remainingDeviceAssociations: Int
    var sessionId: String
    var sessionSummary: DeviceRegistrationSessionSummaryDto
    var data: AuthDataDto
    
    init() {
        self.physicalDevice = DeviceRegistrationResultDeviceDto()
        self.remainingDeviceAssociations = -1
        self.sessionId = ""
        self.sessionSummary = DeviceRegistrationSessionSummaryDto()
        self.data = AuthDataDto()
    }
    
    init(physicalDevice: DeviceRegistrationResultDeviceDto, remainingDeviceAssociations: Int, sessionId: String, sessionSummary: DeviceRegistrationSessionSummaryDto, data: AuthDataDto) {
        self.physicalDevice = physicalDevice
        self.remainingDeviceAssociations = remainingDeviceAssociations
        self.sessionId = sessionId
        self.sessionSummary = sessionSummary
        self.data = data
    }
    
    enum CodingKeys: String, CodingKey {
        case physicalDevice = "PhysicalDevice"
        case remainingDeviceAssociations = "RemainingDeviceAssociations"
        case sessionId = "SessionId"
        case sessionSummary = "SessionSummary"
        case data = "data"
    }
}

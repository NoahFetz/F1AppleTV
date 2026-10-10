//
//  DeviceRegistrationResultDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

// Legacy Keychain serialization only. Endpoint responses decode through AccountDTO.

public struct DeviceRegistrationResultDto: Codable {
    public var physicalDevice: DeviceRegistrationResultDeviceDto
    public var remainingDeviceAssociations: Int
    public var sessionId: String
    public var sessionSummary: DeviceRegistrationSessionSummaryDto
    public var data: AuthDataDto
    
    public init() {
        self.physicalDevice = DeviceRegistrationResultDeviceDto()
        self.remainingDeviceAssociations = -1
        self.sessionId = ""
        self.sessionSummary = DeviceRegistrationSessionSummaryDto()
        self.data = AuthDataDto()
    }
    
    public init(physicalDevice: DeviceRegistrationResultDeviceDto, remainingDeviceAssociations: Int, sessionId: String, sessionSummary: DeviceRegistrationSessionSummaryDto, data: AuthDataDto) {
        self.physicalDevice = physicalDevice
        self.remainingDeviceAssociations = remainingDeviceAssociations
        self.sessionId = sessionId
        self.sessionSummary = sessionSummary
        self.data = data
    }
    
    public enum CodingKeys: String, CodingKey {
        case physicalDevice = "PhysicalDevice"
        case remainingDeviceAssociations = "RemainingDeviceAssociations"
        case sessionId = "SessionId"
        case sessionSummary = "SessionSummary"
        case data = "data"
    }
}

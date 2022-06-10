//
//  DeviceRegistrationLoadedProtocol.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.06.22.
//

import Foundation

protocol DeviceRegistrationLoadedProtocol {
    func didPerformDeviceRegistration(deviceRegistration: DeviceRegistrationResultDto)
    func didPerformDeviceUnregistration()
}

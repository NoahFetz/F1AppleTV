//
//  StreamEntitlementResultDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct StreamEntitlementResultDto: Codable {
    var resultCode: String
    var message: String
    var errorDescription: String
    var resultObj: StreamEntitlementDto?
    var systemTime: Int

    init() {
        self.resultCode = ""
        self.message = ""
        self.errorDescription = ""
        self.systemTime = 0
    }
    
    init(resultCode: String, message: String, errorDescription: String, resultObj: StreamEntitlementDto?, systemTime: Int) {
        self.resultCode = resultCode
        self.message = message
        self.errorDescription = errorDescription
        self.resultObj = resultObj
        self.systemTime = systemTime
    }
    
    enum CodingKeys: String, CodingKey {
        case resultCode = "resultCode"
        case message = "message"
        case errorDescription = "errorDescription"
        case resultObj = "resultObj"
        case systemTime = "systemTime"
    }
}

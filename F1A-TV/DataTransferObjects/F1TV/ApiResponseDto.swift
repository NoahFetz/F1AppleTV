//
//  ApiResponseDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct ApiResponseDto: Codable {
    var resultCode: String
    var message: String
    var errorDescription: String
    var resultObj: ResultObjectDto?
    var source: String
    var systemTime: Int64

    init() {
        self.resultCode = ""
        self.message = ""
        self.errorDescription = ""
        self.source = ""
        self.systemTime = 0
    }
    
    init(resultCode: String, message: String, errorDescription: String, resultObj: ResultObjectDto?, source: String, systemTime: Int64) {
        self.resultCode = resultCode
        self.message = message
        self.errorDescription = errorDescription
        self.resultObj = resultObj
        self.source = source
        self.systemTime = systemTime
    }
    
    enum CodingKeys: String, CodingKey {
        case resultCode = "resultCode"
        case message = "message"
        case errorDescription = "errorDescription"
        case resultObj = "resultObj"
        case source = "source"
        case systemTime = "systemTime"
    }
}

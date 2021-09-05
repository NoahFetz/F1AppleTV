//
//  PlayTimeReportingResultDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 03.08.21.
//

import Foundation

struct PlayTimeReportingResultDto: Codable {
    var resultCode: String
    
    init() {
        self.resultCode = ""
    }
    
    init(resultCode: String) {
        self.resultCode = resultCode
    }
    
    enum CodingKeys: String, CodingKey {
        case resultCode = "resultCode"
    }
}

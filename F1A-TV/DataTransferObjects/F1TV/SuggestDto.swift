//
//  SuggestDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct SuggestDto: Codable {
    var input: [String]
    var payload: PayloadDto

    init() {
        self.input = [String]()
        self.payload = PayloadDto()
    }
    
    init(input: [String], payload: PayloadDto) {
        self.input = input
        self.payload = payload
    }
    
    enum CodingKeys: String, CodingKey {
        case input = "input"
        case payload = "payload"
    }
}

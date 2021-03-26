//
//  F1TVsImSometimesAnIntAndSometimesAStringDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 26.03.21.
//

import Foundation

struct F1TVsImSometimesAnIntAndSometimesAStringDto: Codable {
    var value: Int64
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int64.self) {
            self.value = Int64(value)
            return
        }
        
        if let value = try? container.decode(String.self) {
            self.value = Int64(value) ?? 0
            return
        }
        throw DecodingError.typeMismatch(F1TVsImSometimesAnIntAndSometimesAStringDto.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "They changed it again to something else, who knows what it could be now"))
    }
}

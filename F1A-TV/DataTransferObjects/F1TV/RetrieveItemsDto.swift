//
//  RetrieveItemsDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct RetrieveItemsDto: Codable {
    var resultObj: ResultObjectDto
    var uriOriginal: String
    var typeOriginal: String

    init() {
        self.resultObj = ResultObjectDto()
        self.uriOriginal = ""
        self.typeOriginal = ""
    }
    
    init(resultObj: ResultObjectDto, uriOriginal: String, typeOriginal: String) {
        self.resultObj = resultObj
        self.uriOriginal = uriOriginal
        self.typeOriginal = typeOriginal
    }
    
    enum CodingKeys: String, CodingKey {
        case resultObj = "resultObj"
        case uriOriginal = "uriOriginal"
        case typeOriginal = "typeOriginal"
    }
}

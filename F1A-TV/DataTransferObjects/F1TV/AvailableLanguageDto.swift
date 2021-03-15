//
//  AvailableLanguageDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct AvailableLanguageDto: Codable {
    var languageCode: String
    var languageName: String

    init() {
        self.languageCode = ""
        self.languageName = ""
    }
    
    init(languageCode: String, languageName: String) {
        self.languageCode = languageCode
        self.languageName = languageName
    }
    
    enum CodingKeys: String, CodingKey {
        case languageCode = "languageCode"
        case languageName = "languageName"
    }
}

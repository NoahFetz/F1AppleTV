//
//  AudioLanguageDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct AudioLanguageDto: Codable {
    var audioLanguageName: String
    var audioId: String
    var isPreferred: Bool

    init() {
        self.audioLanguageName = ""
        self.audioId = ""
        self.isPreferred = false
    }
    
    init(audioLanguageName: String, audioId: String, isPreferred: Bool) {
        self.audioLanguageName = audioLanguageName
        self.audioId = audioId
        self.isPreferred = isPreferred
    }
    
    enum CodingKeys: String, CodingKey {
        case audioLanguageName = "audioLanguageName"
        case audioId = "audioId"
        case isPreferred = "isPreferred"
    }
}

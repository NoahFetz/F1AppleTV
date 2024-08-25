//
//  AudioLanguageDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct AudioLanguageDto: Codable {
    var audioLanguageName: String
    //var audioId: Int //Seems to be an Int now but we're not even using this property at the moment
    var isPreferred: Bool

    init() {
        self.audioLanguageName = ""
        //self.audioId = 1
        self.isPreferred = false
    }
    
    init(audioLanguageName: String, isPreferred: Bool) {
        self.audioLanguageName = audioLanguageName
        //self.audioId = audioId
        self.isPreferred = isPreferred
    }
    
    enum CodingKeys: String, CodingKey {
        case audioLanguageName = "audioLanguageName"
        //case audioId = "audioId"
        case isPreferred = "isPreferred"
    }
}

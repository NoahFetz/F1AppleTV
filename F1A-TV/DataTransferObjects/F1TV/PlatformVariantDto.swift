//
//  PlatformVariantDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct PlatformVariantDto: Codable {
    var audioLanguages: [AudioLanguageDto]
    var cpId: Int
    var videoType: String
    var pictureUrl: String
    var technicalPackages: [TechnicalPackageDto]
    var trailerUrl: String
    var hasTrailer: Bool
    
    init() {
        self.audioLanguages = [AudioLanguageDto]()
        self.cpId = 0
        self.videoType = ""
        self.pictureUrl = ""
        self.technicalPackages = [TechnicalPackageDto]()
        self.trailerUrl = ""
        self.hasTrailer = false
    }
    
    init(audioLanguages: [AudioLanguageDto], cpId: Int, videoType: String, pictureUrl: String, technicalPackages: [TechnicalPackageDto], trailerUrl: String, hasTrailer: Bool) {
        self.audioLanguages = audioLanguages
        self.cpId = cpId
        self.videoType = videoType
        self.pictureUrl = pictureUrl
        self.technicalPackages = technicalPackages
        self.trailerUrl = trailerUrl
        self.hasTrailer = hasTrailer
    }

    enum CodingKeys: String, CodingKey {
        case audioLanguages = "audioLanguages"
        case cpId = "cpId"
        case videoType = "videoType"
        case pictureUrl = "pictureUrl"
        case technicalPackages = "technicalPackages"
        case trailerUrl = "trailerUrl"
        case hasTrailer = "hasTrailer"
    }
}

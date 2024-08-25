//
//  PlatformVariantDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct PlatformVariantDto: Codable {
    var audioLanguages: [AudioLanguageDto]
    var cpId: Int?
    var videoType: String?
    var pictureUrl: String?
    //var technicalPackages: [TechnicalPackageDto]? //Seems to be optional now but we're not even using this property at the moment
    var trailerUrl: String?
    var hasTrailer: Bool?
    
    init() {
        self.audioLanguages = [AudioLanguageDto]()
        //self.technicalPackages = [TechnicalPackageDto]()
    }
    
    init(audioLanguages: [AudioLanguageDto], cpId: Int?, videoType: String?, pictureUrl: String?, trailerUrl: String?, hasTrailer: Bool?) {
        self.audioLanguages = audioLanguages
        self.cpId = cpId
        self.videoType = videoType
        self.pictureUrl = pictureUrl
        //self.technicalPackages = technicalPackages
        self.trailerUrl = trailerUrl
        self.hasTrailer = hasTrailer
    }

    enum CodingKeys: String, CodingKey {
        case audioLanguages = "audioLanguages"
        case cpId = "cpId"
        case videoType = "videoType"
        case pictureUrl = "pictureUrl"
        //case technicalPackages = "technicalPackages"
        case trailerUrl = "trailerUrl"
        case hasTrailer = "hasTrailer"
    }
}

//
//  MetadataDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct MetadataDto: Codable {
    var emfAttributes: EmfAttributesDto?
    var longDescription: String?
    var year: String?
    var directors: [String]?
    var isAdvAllowed: Bool?
    var contractStartDate: Int?
    var contractEndDate: Int?
    var externalId: String?
    var availableAlso: [String]?
    var title: String?
    var titleBrief: String?
    var objectType: String?
    var duration: Int?
    var genres: [String]?
    var contentSubtype: String?
    var pcLevel: Int?
    var contentId: Int?
    var starRating: Int?
    var pictureUrl: String?
    var contentType: String?
    var language: String?
    var uiDuration: String?
    var availableLanguages: [AvailableLanguageDto]?
    var additionalStreams: [AdditionalStreamDto]?
    var label: String?
    var channelType: ChannelType?
    
    init() {
    }
    
    init(emfAttributes: EmfAttributesDto?, longDescription: String?, year: String?, directors: [String]?, isAdvAllowed: Bool?, contractStartDate: Int?, contractEndDate: Int?, externalId: String?, availableAlso: [String]?, title: String?, titleBrief: String?, objectType: String?, duration: Int?, genres: [String]?, contentSubtype: String?, pcLevel: Int?, contentId: Int?, starRating: Int?, pictureUrl: String?, contentType: String?, language: String?, uiDuration: String?, availableLanguages: [AvailableLanguageDto]?, additionalStreams: [AdditionalStreamDto]?, label: String?, channelType: ChannelType?) {
        self.emfAttributes = emfAttributes
        self.longDescription = longDescription
        self.year = year
        self.directors = directors
        self.isAdvAllowed = isAdvAllowed
        self.contractStartDate = contractStartDate
        self.contractEndDate = contractEndDate
        self.externalId = externalId
        self.availableAlso = availableAlso
        self.title = title
        self.titleBrief = titleBrief
        self.objectType = objectType
        self.duration = duration
        self.genres = genres
        self.contentSubtype = contentSubtype
        self.pcLevel = pcLevel
        self.contentId = contentId
        self.starRating = starRating
        self.pictureUrl = pictureUrl
        self.contentType = contentType
        self.language = language
        self.uiDuration = uiDuration
        self.availableLanguages = availableLanguages
        self.additionalStreams = additionalStreams
        self.label = label
        self.channelType = channelType
    }
    
    enum CodingKeys: String, CodingKey {
        case emfAttributes = "emfAttributes"
        case longDescription = "longDescription"
        case year = "year"
        case directors = "directors"
        case isAdvAllowed = "isADVAllowed"
        case contractStartDate = "contractStartDate"
        case contractEndDate = "contractEndDate"
        case externalId = "externalId"
        case availableAlso = "availableAlso"
        case title = "title"
        case titleBrief = "titleBrief"
        case objectType = "objectType"
        case duration = "duration"
        case genres = "genres"
        case contentSubtype = "contentSubtype"
        case pcLevel = "pcLevel"
        case contentId = "contentId"
        case starRating = "starRating"
        case pictureUrl = "pictureUrl"
        case contentType = "contentType"
        case language = "language"
        case uiDuration = "uiDuration"
        case availableLanguages = "availableLanguages"
        case additionalStreams = "additionalStreams"
        case label = "label"
    }
}

//
//  ContainerDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct ContainerDto: Codable {
//    var id: String? //Lmao they can't decide in their api if it's a string or int so let's ignore that to prevent json decoding errors
    var layout: String?
    var actions: [ActionDto]?
    var properties: [PropertyDto]?
    var metadata: MetadataDto?
    var bundles: [BundleDto]?
    var categories: [CategoryDto]?
    var platformVariants: [PlatformVariantDto]?
    var retrieveItems: RetrieveItemsDto?
    var contentId: Int?
    var suggest: SuggestDto?
    var platformName: String?
    var eventName: String?
    var events: [ContainerDto]?

    init() {
    }
    
    init(layout: String?, actions: [ActionDto]?, properties: [PropertyDto]?, metadata: MetadataDto?, bundles: [BundleDto]?, categories: [CategoryDto]?, platformVariants: [PlatformVariantDto]?, retrieveItems: RetrieveItemsDto?, contentId: Int?, suggest: SuggestDto?, platformName: String?, eventName: String?, events: [ContainerDto]?) {
        self.layout = layout
        self.actions = actions
        self.properties = properties
        self.metadata = metadata
        self.bundles = bundles
        self.categories = categories
        self.platformVariants = platformVariants
        self.retrieveItems = retrieveItems
        self.contentId = contentId
        self.suggest = suggest
        self.platformName = platformName
        self.eventName = eventName
        self.events = events
    }
    
    enum CodingKeys: String, CodingKey {
        case layout = "layout"
        case actions = "actions"
        case properties = "properties"
        case metadata = "metadata"
        case bundles = "bundles"
        case categories = "categories"
        case platformVariants = "platformVariants"
        case retrieveItems = "retrieveItems"
        case contentId = "contentId"
        case suggest = "suggest"
        case platformName = "platformName"
        case eventName = "eventName"
        case events = "events"
    }
}

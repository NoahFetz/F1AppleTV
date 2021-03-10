//
//  NationDto.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 09.03.21.
//

import Foundation

struct NationDto: Codable {
    var imageUrls: [String]
    var uid: String
    var isoCountryCode: String
    var iocCountryCode: String
    var name: String
    var slug: String
    
    init() {
        self.imageUrls = [String]()
        self.uid = ""
        self.isoCountryCode = ""
        self.iocCountryCode = ""
        self.name = ""
        self.slug = ""
    }
    
    init(imageUrls: [String], uid: String, isoCountryCode: String, iocCountryCode: String, name: String, slug: String) {
        self.imageUrls = imageUrls
        self.uid = uid
        self.isoCountryCode = isoCountryCode
        self.iocCountryCode = iocCountryCode
        self.name = name
        self.slug = slug
    }
    
    enum CodingKeys: String, CodingKey {
        case imageUrls = "image_urls"
        case uid = "uid"
        case isoCountryCode = "iso_country_code"
        case iocCountryCode = "ioc_country_code"
        case name = "name"
        case slug = "slug"
    }
}

//
//  TeamDto.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 09.03.21.
//

import Foundation
import UIKit

struct TeamDto: Codable {
    var imageUrls: [String]
    var contentUrls: [String]
    var nationUrl: String
    var driverOccurrenceUrls: [String]
    var uid: String
    var colour: String
    var name: String
    
    init() {
        self.imageUrls = [String]()
        self.contentUrls = [String]()
        self.nationUrl = ""
        self.driverOccurrenceUrls = [String]()
        self.uid = ""
        self.colour = ""
        self.name = ""
    }

    init(imageUrls: [String], contentUrls: [String], nationUrl: String, driverOccurrenceUrls: [String], uid: String, colour: String, name: String) {
        self.imageUrls = imageUrls
        self.contentUrls = contentUrls
        self.nationUrl = nationUrl
        self.driverOccurrenceUrls = driverOccurrenceUrls
        self.uid = uid
        self.colour = colour
        self.name = name
    }
    
    enum CodingKeys: String, CodingKey {
        case imageUrls = "image_urls"
        case contentUrls = "content_urls"
        case nationUrl = "nation_url"
        case driverOccurrenceUrls = "driveroccurrence_urls"
        case uid = "uid"
        case colour = "colour"
        case name = "name"
    }
    
    func getColor() -> UIColor {
        return UIColor(rgb: self.colour)
    }
}

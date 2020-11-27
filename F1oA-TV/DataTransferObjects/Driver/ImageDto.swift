//
//  ImageDto.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 27.11.20.
//

import Foundation

struct ImageDto: Codable {
    let url: String
    let imageType: String?
    let uid: String
    let objectId: Int
    let title: String
    let description: String

    init() {
        self.url = ""
        self.imageType = ""
        self.uid = ""
        self.objectId = 0
        self.title = ""
        self.description = ""
    }
    
    init(url: String, imageType: String?, uid: String, objectId: Int, title: String, description: String) {
        self.url = url
        self.imageType = imageType
        self.uid = uid
        self.objectId = objectId
        self.title = title
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case url = "url"
        case imageType = "image_type"
        case uid = "uid"
        case objectId = "object_id"
        case title = "title"
        case description = "description"
    }
}

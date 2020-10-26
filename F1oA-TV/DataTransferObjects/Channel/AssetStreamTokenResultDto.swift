//
//  AssetStreamTokenResultDto.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import Foundation

struct AssetStreamTokenResultDto: Codable {
    let assetStreamTokenObjects: [AssetStreamTokenResultDtoObject]

    enum CodingKeys: String, CodingKey {
        case assetStreamTokenObjects = "objects"
    }

    init(assetStreamTokenObjects: [AssetStreamTokenResultDtoObject]) {
        self.assetStreamTokenObjects = assetStreamTokenObjects
    }
}

struct AssetStreamTokenResultDtoObject: Codable {
    let assetStreamToken: AssetStreamTokenResultDtoToken

    enum CodingKeys: String, CodingKey {
        case assetStreamToken = "tata"
    }

    init(assetStreamToken: AssetStreamTokenResultDtoToken) {
        self.assetStreamToken = assetStreamToken
    }
}

struct AssetStreamTokenResultDtoToken: Codable {
    let tokenisedURL: String

    enum CodingKeys: String, CodingKey {
        case tokenisedURL = "tokenised_url"
    }

    init(tokenisedURL: String) {
        self.tokenisedURL = tokenisedURL
    }
}

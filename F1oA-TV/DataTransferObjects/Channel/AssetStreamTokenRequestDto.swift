//
//  AssetStreamTokenRequestDto.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import Foundation

struct AssetStreamTokenRequestDto: Codable {
    var assetUrl: String
    
    init() {
        self.assetUrl = ""
    }
    
    init(assetUrl: String) {
        self.assetUrl = assetUrl
    }
    
    enum CodingKeys: String, CodingKey {
        case assetUrl = "asset_url"
    }
}

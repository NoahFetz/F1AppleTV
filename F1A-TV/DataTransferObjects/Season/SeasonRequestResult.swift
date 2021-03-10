//
//  SeasonRequestResult.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation

struct SeasonRequestResult: Codable {
    var resultObjects: [SeasonDto]
    
    enum CodingKeys: String, CodingKey {
        case resultObjects = "objects"
    }
}

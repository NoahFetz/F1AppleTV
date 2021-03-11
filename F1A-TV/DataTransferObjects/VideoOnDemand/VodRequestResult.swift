//
//  VodRequestResult.swift
//  F1A-TV
//
//  Created by Noah Fetz on 11.03.21.
//

import Foundation

struct VodRequestResult: Codable {
    var resultObjects: [VodDto]
    
    enum CodingKeys: String, CodingKey {
        case resultObjects = "objects"
    }
}

//
//  BundleDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct BundleDto: Codable {
    var bundleSubtype: String
    var isParent: Bool
    var orderId: Int
    var bundleId: Int
    var bundleType: String

    init() {
        self.bundleSubtype = ""
        self.isParent = false
        self.orderId = 0
        self.bundleId = 0
        self.bundleType = ""
    }
    
    init(bundleSubtype: String, isParent: Bool, orderId: Int, bundleId: Int, bundleType: String) {
        self.bundleSubtype = bundleSubtype
        self.isParent = isParent
        self.orderId = orderId
        self.bundleId = bundleId
        self.bundleType = bundleType
    }
    
    enum CodingKeys: String, CodingKey {
        case bundleSubtype = "bundleSubtype"
        case isParent = "isParent"
        case orderId = "orderId"
        case bundleId = "bundleId"
        case bundleType = "bundleType"
    }
}

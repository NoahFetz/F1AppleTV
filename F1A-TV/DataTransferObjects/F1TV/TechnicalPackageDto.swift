//
//  TechnicalPackageDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct TechnicalPackageDto: Codable {
    var packageId: Int?
    var packageName: String?
    var packageType: String

    init() {
        self.packageType = ""
    }
    
    init(packageId: Int?, packageName: String?, packageType: String) {
        self.packageId = packageId
        self.packageName = packageName
        self.packageType = packageType
    }
    
    enum CodingKeys: String, CodingKey {
        case packageId = "packageId"
        case packageName = "packageName"
        case packageType = "packageType"
    }
}

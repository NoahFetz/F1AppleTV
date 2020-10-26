//
//  DriverDto.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import Foundation

class DriverDto: Codable {
    let imageUrls: [String]
    let name: String
    let uid: String
    let dataSourceId: String
    let driverTLA: String
    let driverRacingnumber: Int
    let driverReference: String

    enum CodingKeys: String, CodingKey {
        case imageUrls = "image_urls"
        case name = "name"
        case uid = "uid"
        case dataSourceId = "data_source_id"
        case driverTLA = "driver_tla"
        case driverRacingnumber = "driver_racingnumber"
        case driverReference = "driver_reference"
    }

    init(imageUrls: [String], name: String, uid: String, dataSourceId: String, driverTLA: String, driverRacingnumber: Int, driverReference: String) {
        self.imageUrls = imageUrls
        self.name = name
        self.uid = uid
        self.dataSourceId = dataSourceId
        self.driverTLA = driverTLA
        self.driverRacingnumber = driverRacingnumber
        self.driverReference = driverReference
    }
}

//
//  DriverDto.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import Foundation

class DriverDto: Codable {
    var imageUrls: [String]
    var name: String
    var uid: String
    var dataSourceId: String
    var driverTLA: String
    var driverRacingnumber: Int
    var driverReference: String
    var teamUrl: String

    enum CodingKeys: String, CodingKey {
        case imageUrls = "image_urls"
        case name = "name"
        case uid = "uid"
        case dataSourceId = "data_source_id"
        case driverTLA = "driver_tla"
        case driverRacingnumber = "driver_racingnumber"
        case driverReference = "driver_reference"
        case teamUrl = "team_url"
    }

    init(imageUrls: [String], name: String, uid: String, dataSourceId: String, driverTLA: String, driverRacingnumber: Int, driverReference: String, teamUrl: String) {
        self.imageUrls = imageUrls
        self.name = name
        self.uid = uid
        self.dataSourceId = dataSourceId
        self.driverTLA = driverTLA
        self.driverRacingnumber = driverRacingnumber
        self.driverReference = driverReference
        self.teamUrl = teamUrl
    }
}

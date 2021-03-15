//
//  AdditionalStreamDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct AdditionalStreamDto: Codable {
    var racingNumber: Int
    var title: String
    var driverFirstName: String?
    var driverLastName: String?
    var teamName: String
    var constructorName: String?
    var type: String
    var playbackUrl: String
    var driverImg: String
    var teamImg: String
    var hex: String?
    
    init() {
        self.racingNumber = 0
        self.title = ""
        self.teamName = ""
        self.type = ""
        self.playbackUrl = ""
        self.driverImg = ""
        self.teamImg = ""
    }
    
    init(racingNumber: Int, title: String, driverFirstName: String?, driverLastName: String?, teamName: String, constructorName: String?, type: String, playbackUrl: String, driverImg: String, teamImg: String, hex: String?) {
        self.racingNumber = racingNumber
        self.title = title
        self.driverFirstName = driverFirstName
        self.driverLastName = driverLastName
        self.teamName = teamName
        self.constructorName = constructorName
        self.type = type
        self.playbackUrl = playbackUrl
        self.driverImg = driverImg
        self.teamImg = teamImg
        self.hex = hex
    }
    
    enum CodingKeys: String, CodingKey {
        case racingNumber = "racingNumber"
        case title = "title"
        case driverFirstName = "driverFirstName"
        case driverLastName = "driverLastName"
        case teamName = "teamName"
        case constructorName = "constructorName"
        case type = "type"
        case playbackUrl = "playbackUrl"
        case driverImg = "driverImg"
        case teamImg = "teamImg"
        case hex = "hex"
    }
}

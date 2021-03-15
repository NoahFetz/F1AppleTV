//
//  ResultObjectDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct ResultObjectDto: Codable {
    var containers: [ContainerDto]?
    var total: Int?

    init() {
    }
    
    init(containers: [ContainerDto]?, total: Int?) {
        self.containers = containers
        self.total = total
    }
    
    enum CodingKeys: String, CodingKey {
        case containers = "containers"
        case total = "total"
    }
}

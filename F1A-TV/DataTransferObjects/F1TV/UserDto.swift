//
//  UserDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 03.08.21.
//

import Foundation

struct UserDto: Codable {
    var resume: ResumeDto?

    init() {
    }
    
    init(resume: ResumeDto?) {
        self.resume = resume
    }
    
    enum CodingKeys: String, CodingKey {
        case resume = "resume"
    }
}

//
//  BackupStreamDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct BackupStreamDto: Codable {
    var metricsEnvKeyPreProd: String
    var metricsEnvKeyProd: String
    var streamManifest: String
    var poster: String
    
    init() {
        self.metricsEnvKeyPreProd = ""
        self.metricsEnvKeyProd = ""
        self.streamManifest = ""
        self.poster = ""
    }
    
    init(metricsEnvKeyPreProd: String, metricsEnvKeyProd: String, streamManifest: String, poster: String) {
        self.metricsEnvKeyPreProd = metricsEnvKeyPreProd
        self.metricsEnvKeyProd = metricsEnvKeyProd
        self.streamManifest = streamManifest
        self.poster = poster
    }
    
    enum CodingKeys: String, CodingKey {
        case metricsEnvKeyPreProd = "metricsEnvKeyPreProd"
        case metricsEnvKeyProd = "metricsEnvKeyProd"
        case streamManifest = "streamManifest"
        case poster = "poster"
    }
}

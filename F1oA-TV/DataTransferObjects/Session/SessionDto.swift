//
//  SessionDto.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import Foundation

struct SessionDto: Codable {
    let availableForUser: Bool
    let imageUrls: [String]
    let status: String
    let channelUrls: [String]
    let contentUrls: [String]
    let globalChannelUrls: [String]
    let uid: String
    let dataSourceId: String
    let liveSourcesPath: String
    let startTime: Date
    let endTime: Date
    let editorialStartTime: Date?
    let editorialEndTime: Date?
    let nbcPID: Int?
    let nbcStatus: String?
    let isTestSession: Bool
    let name: String
    let sessionName: String
    let slug: String

    init() {
        self.availableForUser = false
        self.imageUrls = [String]()
        self.status = ""
        self.channelUrls = [String]()
        self.contentUrls = [String]()
        self.globalChannelUrls = [String]()
        self.uid = ""
        self.dataSourceId = ""
        self.liveSourcesPath = ""
        self.startTime = Date()
        self.endTime = Date()
        self.editorialStartTime = Date()
        self.editorialEndTime = Date()
        self.nbcPID = 0
        self.nbcStatus = ""
        self.isTestSession = false
        self.name = ""
        self.sessionName = ""
        self.slug = ""
    }
    
    init(availableForUser: Bool, imageUrls: [String], status: String, channelUrls: [String], contentUrls: [String], globalChannelUrls: [String], uid: String, dataSourceId: String, liveSourcesPath: String, startTime: Date, endTime: Date, editorialStartTime: Date?, editorialEndTime: Date?, nbcPID: Int?, nbcStatus: String?, isTestSession: Bool, name: String, sessionName: String, slug: String) {
        self.availableForUser = availableForUser
        self.imageUrls = imageUrls
        self.status = status
        self.channelUrls = channelUrls
        self.contentUrls = contentUrls
        self.globalChannelUrls = globalChannelUrls
        self.uid = uid
        self.dataSourceId = dataSourceId
        self.liveSourcesPath = liveSourcesPath
        self.startTime = startTime
        self.endTime = endTime
        self.editorialStartTime = editorialStartTime
        self.editorialEndTime = editorialEndTime
        self.nbcPID = nbcPID
        self.nbcStatus = nbcStatus
        self.isTestSession = isTestSession
        self.name = name
        self.sessionName = sessionName
        self.slug = slug
    }
    
    enum CodingKeys: String, CodingKey {
        case availableForUser = "available_for_user"
        case imageUrls = "image_urls"
        case status = "status"
        case channelUrls = "channel_urls"
        case contentUrls = "content_urls"
        case globalChannelUrls = "global_channel_urls"
        case uid = "uid"
        case dataSourceId = "data_source_id"
        case liveSourcesPath = "live_sources_path"
        case startTime = "start_time"
        case endTime = "end_time"
        case editorialStartTime = "editorial_start_time"
        case editorialEndTime = "editorial_end_time"
        case nbcPID = "nbc_pid"
        case nbcStatus = "nbc_status"
        case isTestSession = "is_test_session"
        case name = "name"
        case sessionName = "session_name"
        case slug = "slug"
    }
}

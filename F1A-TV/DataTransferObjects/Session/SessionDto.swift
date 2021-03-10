//
//  SessionDto.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import Foundation

struct SessionDto: Codable {
    var availableForUser: Bool
    var imageUrls: [String]
    var status: String
    var channelUrls: [String]
    var contentUrls: [String]
    var globalChannelUrls: [String]
    var uid: String
    var dataSourceId: String
    var liveSourcesPath: String
    var startTime: Date
    var endTime: Date
    var editorialStartTime: Date?
    var editorialEndTime: Date?
    var nbcPID: Int?
    var nbcStatus: String?
    var isTestSession: Bool
    var name: String
    var sessionName: String
    var slug: String
    var seriesUrl: String

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
        self.seriesUrl = ""
    }
    
    init(availableForUser: Bool, imageUrls: [String], status: String, channelUrls: [String], contentUrls: [String], globalChannelUrls: [String], uid: String, dataSourceId: String, liveSourcesPath: String, startTime: Date, endTime: Date, editorialStartTime: Date?, editorialEndTime: Date?, nbcPID: Int?, nbcStatus: String?, isTestSession: Bool, name: String, sessionName: String, slug: String, seriesUrl: String) {
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
        self.seriesUrl = seriesUrl
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
        case seriesUrl = "series_url"
    }
}

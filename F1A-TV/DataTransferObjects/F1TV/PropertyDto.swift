//
//  PropertyDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct PropertyDto: Codable {
    var meetingNumber: Int
    var sessionEndTime: Int
    var series: String
    var lastUpdatedDate: Int
    var seasonMeetingOrdinal: Int
    var meetingStartDate: Int
    var meetingEndDate: Int
    var sessionIndex: Int
    var meetingSessionKey: Int?
    var sessionStartDate: Int?
    var sessionEndDate: Int?

    init() {
        self.meetingNumber = 0
        self.sessionEndTime = 0
        self.series = ""
        self.lastUpdatedDate = 0
        self.seasonMeetingOrdinal = 0
        self.meetingStartDate = 0
        self.meetingEndDate = 0
        self.sessionIndex = 0
    }
    
    init(meetingNumber: Int, sessionEndTime: Int, series: String, lastUpdatedDate: Int, seasonMeetingOrdinal: Int, meetingStartDate: Int, meetingEndDate: Int, sessionIndex: Int, meetingSessionKey: Int?, sessionStartDate: Int?, sessionEndDate: Int?) {
        self.meetingNumber = meetingNumber
        self.sessionEndTime = sessionEndTime
        self.series = series
        self.lastUpdatedDate = lastUpdatedDate
        self.seasonMeetingOrdinal = seasonMeetingOrdinal
        self.meetingStartDate = meetingStartDate
        self.meetingEndDate = meetingEndDate
        self.sessionIndex = sessionIndex
        self.meetingSessionKey = meetingSessionKey
        self.sessionStartDate = sessionStartDate
        self.sessionEndDate = sessionEndDate
    }
    
    enum CodingKeys: String, CodingKey {
        case meetingNumber = "meeting_Number"
        case sessionEndTime = "sessionEndTime"
        case series = "series"
        case lastUpdatedDate = "lastUpdatedDate"
        case seasonMeetingOrdinal = "season_Meeting_Ordinal"
        case meetingStartDate = "meeting_Start_Date"
        case meetingEndDate = "meeting_End_Date"
        case sessionIndex = "session_index"
        case meetingSessionKey = "meetingSessionKey"
        case sessionStartDate = "sessionStartDate"
        case sessionEndDate = "sessionEndDate"
    }
}

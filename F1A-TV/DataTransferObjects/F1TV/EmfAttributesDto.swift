//
//  EmfAttributesDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct EmfAttributesDto: Codable {
    var videoType: String
    var meetingKey: String
    var meetingSessionKey: String
    var meetingName: String
    var meetingNumber: String?
    var circuitShortName: String
    var meetingCode: String
    var meetingCountryKey: String?
    var circuitKey: String
    var meetingLocation: String
    var series: String
    var obc: Bool
    var state: String
    var timetableKey: String?
    var sessionKey: String?
    var sessionPeriod: String?
    var circuitOfficialName: String?
    var activityDescription: String?
    var seriesMeetingSessionIdentifier: String?
    var sessionEndTime: String?
    var meetingStartDate: String?
    var meetingEndDate: String?
    var trackLength: String?
    var scheduledLapCount: String?
    var scheduledDistance: String?
    var circuitLocation: String?
    var meetingSponsor: String?
    var isTestEvent: String?
//    var seasonMeetingOrdinal: Int? // They can't decide whether this is an int or string, ignoring it to prevent json decoding errors
    var championshipMeetingOrdinal: String?
//    var sessionIndex: Int // They can't decide whether this is an int or string, ignoring it to prevent json decoding errors
    var meetingOfficialName: String?
    var meetingDisplayDate: String?
    var pageId: Int?
    var meetingCountryName: String?
//    var sessionEndDate: Int? // They can't decide whether this is an int or string, ignoring it to prevent json decoding errors
//    var sessionStartDate: Int? // They can't decide whether this is an int or string, ignoring it to prevent json decoding errors
    var globalTitle: String?
    var globalMeetingCountryName: String?
    var globalMeetingName: String?

    init() {
        self.videoType = ""
        self.meetingKey = ""
        self.meetingSessionKey = ""
        self.meetingName = ""
        self.circuitShortName = ""
        self.meetingCode = ""
        self.circuitKey = ""
        self.meetingLocation = ""
        self.series = ""
        self.obc = false
        self.state = ""
        self.trackLength = ""
    }
    
    init(videoType: String, meetingKey: String, meetingSessionKey: String, meetingName: String, meetingNumber: String?, circuitShortName: String, meetingCode: String, meetingCountryKey: String?, circuitKey: String, meetingLocation: String, series: String, obc: Bool, state: String, timetableKey: String?, sessionKey: String?, sessionPeriod: String?, circuitOfficialName: String?, activityDescription: String?, seriesMeetingSessionIdentifier: String?, sessionEndTime: String?, meetingStartDate: String?, meetingEndDate: String?, trackLength: String, scheduledLapCount: String?, scheduledDistance: String?, circuitLocation: String?, meetingSponsor: String?, isTestEvent: String?, championshipMeetingOrdinal: String?, meetingOfficialName: String?, meetingDisplayDate: String?, pageId: Int?, meetingCountryName: String?, globalTitle: String?, globalMeetingCountryName: String?, globalMeetingName: String?) {
        self.videoType = videoType
        self.meetingKey = meetingKey
        self.meetingSessionKey = meetingSessionKey
        self.meetingName = meetingName
        self.meetingNumber = meetingNumber
        self.circuitShortName = circuitShortName
        self.meetingCode = meetingCode
        self.meetingCountryKey = meetingCountryKey
        self.circuitKey = circuitKey
        self.meetingLocation = meetingLocation
        self.series = series
        self.obc = obc
        self.state = state
        self.timetableKey = timetableKey
        self.sessionKey = sessionKey
        self.sessionPeriod = sessionPeriod
        self.circuitOfficialName = circuitOfficialName
        self.activityDescription = activityDescription
        self.seriesMeetingSessionIdentifier = seriesMeetingSessionIdentifier
        self.sessionEndTime = sessionEndTime
        self.meetingStartDate = meetingStartDate
        self.meetingEndDate = meetingEndDate
        self.trackLength = trackLength
        self.scheduledLapCount = scheduledLapCount
        self.scheduledDistance = scheduledDistance
        self.circuitLocation = circuitLocation
        self.meetingSponsor = meetingSponsor
        self.isTestEvent = isTestEvent
        self.championshipMeetingOrdinal = championshipMeetingOrdinal
        self.meetingOfficialName = meetingOfficialName
        self.meetingDisplayDate = meetingDisplayDate
        self.pageId = pageId
        self.meetingCountryName = meetingCountryName
        self.globalTitle = globalTitle
        self.globalMeetingCountryName = globalMeetingCountryName
        self.globalMeetingName = globalMeetingName
    }
    
    enum CodingKeys: String, CodingKey {
        case videoType = "VideoType"
        case meetingKey = "MeetingKey"
        case meetingSessionKey = "MeetingSessionKey"
        case meetingName = "Meeting_Name"
        case meetingNumber = "Meeting_Number"
        case circuitShortName = "Circuit_Short_Name"
        case meetingCode = "Meeting_Code"
        case meetingCountryKey = "MeetingCountryKey"
        case circuitKey = "CircuitKey"
        case meetingLocation = "Meeting_Location"
        case series = "Series"
        case obc = "OBC"
        case state = "state"
        case timetableKey = "TimetableKey"
        case sessionKey = "SessionKey"
        case sessionPeriod = "SessionPeriod"
        case circuitOfficialName = "Circuit_Official_Name"
        case activityDescription = "ActivityDescription"
        case seriesMeetingSessionIdentifier = "SeriesMeetingSessionIdentifier"
        case sessionEndTime = "sessionEndTime"
        case meetingStartDate = "Meeting_Start_Date"
        case meetingEndDate = "Meeting_End_Date"
        case trackLength = "Track_Length"
        case scheduledLapCount = "Scheduled_Lap_Count"
        case scheduledDistance = "Scheduled_Distance"
        case circuitLocation = "Circuit_Location"
        case meetingSponsor = "Meeting_Sponsor"
        case isTestEvent = "IsTestEvent"
        case championshipMeetingOrdinal = "Championship_Meeting_Ordinal"
        case meetingOfficialName = "Meeting_Official_Name"
        case meetingDisplayDate = "Meeting_Display_Date"
        case pageId = "PageID"
        case meetingCountryName = "Meeting_Country_Name"
        case globalTitle = "Global_Title"
        case globalMeetingCountryName = "Global_Meeting_Country_Name"
        case globalMeetingName = "Global_Meeting_Name"
    }
}

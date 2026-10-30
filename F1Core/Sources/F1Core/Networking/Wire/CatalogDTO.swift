import Foundation

public struct WireIdentifier: Decodable {
    public let value: String
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if let number = try? value.decode(Int64.self) { self.value = String(number) }
        else { self.value = try value.decode(String.self) }
    }
}
public struct WireMilliseconds: Decodable {
    public let date: Date?
    public init(from decoder: Decoder) throws {
        let value = try WireIdentifier(from: decoder)
        guard let milliseconds = Int64(value.value) else { throw APIError.decoding }
        date = milliseconds > 0 ? Date(timeIntervalSince1970: Double(milliseconds) / 1000) : nil
    }
}
public struct LossyArray<Element: Decodable>: Decodable {
    public let values: [Element]
    public let dropped: Int
    public init(from decoder: Decoder) throws {
        var array = try decoder.unkeyedContainer(), values = [Element](), dropped = 0
        while !array.isAtEnd {
            let child = try array.superDecoder()
            do { values.append(try Element(from: child)) } catch { dropped += 1 }
        }
        self.values = values; self.dropped = dropped
    }
}
public struct CatalogPayloadDTO: Decodable {
    public let containers: LossyArray<CatalogNodeDTO>?
    public let total: Int?
}
public struct CatalogRetrieveDTO: Decodable {
    public let resultObj: CatalogPayloadDTO
    private enum CodingKeys: String, CodingKey { case resultCode, resultObj }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let code = try container.decodeIfPresent(String.self, forKey: .resultCode), code != "OK" { throw APIError.backend }
        resultObj = try container.decode(CatalogPayloadDTO.self, forKey: .resultObj)
    }
}
public struct CatalogActionDTO: Decodable { public let key: String; public let uri: String; public let href: String?; public let targetType: String? }
public struct CatalogPropertyDTO: Decodable { public let series: String? }
public struct CatalogVariantDTO: Decodable { public let pictureUrl: String? }
public struct CatalogResumeDTO: Decodable { public let playHeadPosition: Double? }
public struct CatalogUserDTO: Decodable { public let resume: CatalogResumeDTO? }
public struct CatalogNodeDTO: Decodable {
    public let id: WireIdentifier?
    public let contentId: WireIdentifier?
    public let layout: String?
    public let actions: LossyArray<CatalogActionDTO>?
    public let metadata: CatalogMetadataDTO?
    public let properties: LossyArray<CatalogPropertyDTO>?
    public let platformVariants: LossyArray<CatalogVariantDTO>?
    public let retrieveItems: CatalogRetrieveDTO?
    public let eventName: String?
    public let eventShortName: String?
    public let events: LossyArray<CatalogNodeDTO>?
    public let user: CatalogUserDTO?
}
public struct CatalogMetadataDTO: Decodable {
    public let title: String?, titleBrief: String?, label: String?, longDescription: String?, pictureUrl: String?
    public let contentId: WireIdentifier?
    public let contentType: String?, objectType: String?, contentSubtype: String?, uiDuration: String?
    public let interactive: Bool?, locked: Bool?
    public let emfAttributes: CatalogRaceDTO?
    public let additionalStreams: LossyArray<ChannelDTO>?
    public let type: String?, featureIdentifier: String?
    public enum CodingKeys: String, CodingKey {
        case title, titleBrief, label, longDescription, pictureUrl, contentId, contentType, objectType, contentSubtype, uiDuration, interactive, locked, emfAttributes, additionalStreams, type
        case featureIdentifier = "feature_indentifier"
    }
}
public struct CatalogRaceDTO: Decodable {
    public let meetingName: String?
    public let videoType: String?, meetingKey: WireIdentifier?, meetingCountryKey: String?, meetingCountryName: String?, globalMeetingName: String?
    public let meetingOfficialName: String?, meetingDisplayDate: String?, championshipMeetingOrdinal: WireIdentifier?, series: String?
    public let sessionStartDate: WireMilliseconds?, sessionEndDate: WireMilliseconds?
    public enum CodingKeys: String, CodingKey {
        case meetingName = "Meeting_Name"
        case videoType = "VideoType", meetingKey = "MeetingKey", meetingCountryKey = "MeetingCountryKey", meetingCountryName = "Meeting_Country_Name", globalMeetingName = "Global_Meeting_Name"
        case meetingOfficialName = "Meeting_Official_Name", meetingDisplayDate = "Meeting_Display_Date", championshipMeetingOrdinal = "Championship_Meeting_Ordinal", series = "Series"
        case sessionStartDate, sessionEndDate
    }
    public var model: RaceMetadata {
        RaceMetadata(meetingName: meetingName, videoType: videoType ?? "", meetingKey: meetingKey?.value ?? "", meetingCountryKey: meetingCountryKey, meetingCountryName: meetingCountryName, globalMeetingName: globalMeetingName, meetingOfficialName: meetingOfficialName, meetingDisplayDate: meetingDisplayDate, championshipMeetingOrdinal: championshipMeetingOrdinal?.value, series: series, sessionStartDate: sessionStartDate?.date, sessionEndDate: sessionEndDate?.date)
    }
}
public struct ChannelDTO: Decodable {
    public let racingNumber: WireIdentifier?
    public let title: String?, driverFirstName: String?, driverLastName: String?, teamName: String?, type: String?
    public let playbackUrl: String?, driverImg: String?, teamImg: String?, hex: String?
}
public struct EntitlementDTO: Decodable {
    public let entitlementToken: String
    public let url: String
    public let streamType: String?
    public let drmType: String?
    public let laUrl: String?
    public let channelId: WireIdentifier
    private enum CodingKeys: String, CodingKey {
        case entitlementToken, url, streamType, drmType, channelId
        case licenseURL = "laURL", legacyLicenseURL = "laUrl"
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        entitlementToken = try values.decode(String.self, forKey: .entitlementToken)
        url = try values.decode(String.self, forKey: .url)
        streamType = try values.decodeIfPresent(String.self, forKey: .streamType)
        drmType = try values.decodeIfPresent(String.self, forKey: .drmType)
        channelId = try values.decode(WireIdentifier.self, forKey: .channelId)
        // The playback API uses laURL; keep the older mixed-case response compatible.
        laUrl = try values.decodeIfPresent(String.self, forKey: .licenseURL)
            ?? values.decodeIfPresent(String.self, forKey: .legacyLicenseURL)
    }
    public func model() throws -> PlaybackEntitlement {
        guard let media = URL(string: url), media.scheme == "https", media.host != nil, !entitlementToken.isEmpty, !channelId.value.isEmpty else { throw APIError.invalidPlayback }
        if drmType?.lowercased().contains("fairplay") == true {
            guard let laUrl, let license = URL(string: laUrl), license.scheme == "https", license.host != nil else { throw APIError.invalidPlayback }
        }
        return PlaybackEntitlement(url: url, channelID: channelId.value, drmType: drmType, licenseURL: laUrl, entitlementToken: entitlementToken)
    }
}

import Foundation

struct WireIdentifier: Decodable {
    let value: String
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if let number = try? value.decode(Int64.self) { self.value = String(number) }
        else { self.value = try value.decode(String.self) }
    }
}
struct WireMilliseconds: Decodable {
    let date: Date?
    init(from decoder: Decoder) throws {
        let value = try WireIdentifier(from: decoder)
        guard let milliseconds = Int64(value.value) else { throw APIError.decoding }
        date = milliseconds > 0 ? Date(timeIntervalSince1970: Double(milliseconds) / 1000) : nil
    }
}
struct LossyArray<Element: Decodable>: Decodable {
    let values: [Element]
    let dropped: Int
    init(from decoder: Decoder) throws {
        var array = try decoder.unkeyedContainer(), values = [Element](), dropped = 0
        while !array.isAtEnd {
            let child = try array.superDecoder()
            do { values.append(try Element(from: child)) } catch { dropped += 1 }
        }
        self.values = values; self.dropped = dropped
    }
}
struct CatalogPayloadDTO: Decodable {
    let containers: LossyArray<CatalogNodeDTO>?
    let total: Int?
}
struct CatalogRetrieveDTO: Decodable {
    let resultObj: CatalogPayloadDTO
    private enum CodingKeys: String, CodingKey { case resultCode, resultObj }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let code = try container.decodeIfPresent(String.self, forKey: .resultCode), code != "OK" { throw APIError.backend }
        resultObj = try container.decode(CatalogPayloadDTO.self, forKey: .resultObj)
    }
}
struct CatalogActionDTO: Decodable { let key: String; let uri: String; let href: String?; let targetType: String? }
struct CatalogPropertyDTO: Decodable { let series: String? }
struct CatalogVariantDTO: Decodable { let pictureUrl: String? }
struct CatalogResumeDTO: Decodable { let playHeadPosition: Double? }
struct CatalogUserDTO: Decodable { let resume: CatalogResumeDTO? }
struct CatalogNodeDTO: Decodable {
    let id: WireIdentifier?
    let contentId: WireIdentifier?
    let layout: String?
    let actions: LossyArray<CatalogActionDTO>?
    let metadata: CatalogMetadataDTO?
    let properties: LossyArray<CatalogPropertyDTO>?
    let platformVariants: LossyArray<CatalogVariantDTO>?
    let retrieveItems: CatalogRetrieveDTO?
    let eventName: String?
    let eventShortName: String?
    let events: LossyArray<CatalogNodeDTO>?
    let user: CatalogUserDTO?
}
struct CatalogMetadataDTO: Decodable {
    let title: String?, titleBrief: String?, label: String?, longDescription: String?, pictureUrl: String?
    let contentId: WireIdentifier?
    let contentType: String?, objectType: String?, contentSubtype: String?, uiDuration: String?
    let interactive: Bool?, locked: Bool?
    let emfAttributes: CatalogRaceDTO?
    let additionalStreams: LossyArray<ChannelDTO>?
    let type: String?, featureIdentifier: String?
    enum CodingKeys: String, CodingKey {
        case title, titleBrief, label, longDescription, pictureUrl, contentId, contentType, objectType, contentSubtype, uiDuration, interactive, locked, emfAttributes, additionalStreams, type
        case featureIdentifier = "feature_indentifier"
    }
}
struct CatalogRaceDTO: Decodable {
    let videoType: String?, meetingKey: WireIdentifier?, meetingCountryKey: String?, meetingCountryName: String?, globalMeetingName: String?
    let meetingOfficialName: String?, meetingDisplayDate: String?, championshipMeetingOrdinal: WireIdentifier?, series: String?
    let sessionStartDate: WireMilliseconds?, sessionEndDate: WireMilliseconds?
    enum CodingKeys: String, CodingKey {
        case videoType = "VideoType", meetingKey = "MeetingKey", meetingCountryKey = "MeetingCountryKey", meetingCountryName = "Meeting_Country_Name", globalMeetingName = "Global_Meeting_Name"
        case meetingOfficialName = "Meeting_Official_Name", meetingDisplayDate = "Meeting_Display_Date", championshipMeetingOrdinal = "Championship_Meeting_Ordinal", series = "Series"
        case sessionStartDate, sessionEndDate
    }
    var model: RaceMetadata {
        RaceMetadata(videoType: videoType ?? "", meetingKey: meetingKey?.value ?? "", meetingCountryKey: meetingCountryKey, meetingCountryName: meetingCountryName, globalMeetingName: globalMeetingName, meetingOfficialName: meetingOfficialName, meetingDisplayDate: meetingDisplayDate, championshipMeetingOrdinal: championshipMeetingOrdinal?.value, series: series, sessionStartDate: sessionStartDate?.date, sessionEndDate: sessionEndDate?.date)
    }
}
struct ChannelDTO: Decodable {
    let racingNumber: WireIdentifier?
    let title: String?, driverFirstName: String?, driverLastName: String?, teamName: String?, type: String?
    let playbackUrl: String?, driverImg: String?, teamImg: String?, hex: String?
}
struct EntitlementDTO: Decodable {
    let entitlementToken: String
    let url: String
    let streamType: String?
    let drmType: String?
    let laUrl: String?
    let channelId: WireIdentifier
    private enum CodingKeys: String, CodingKey {
        case entitlementToken, url, streamType, drmType, channelId
        case licenseURL = "laURL", legacyLicenseURL = "laUrl"
    }
    init(from decoder: Decoder) throws {
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
    func model() throws -> PlaybackEntitlement {
        guard let media = URL(string: url), media.scheme == "https", media.host != nil, !entitlementToken.isEmpty, !channelId.value.isEmpty else { throw APIError.invalidPlayback }
        if drmType?.lowercased().contains("fairplay") == true {
            guard let laUrl, let license = URL(string: laUrl), license.scheme == "https", license.host != nil else { throw APIError.invalidPlayback }
        }
        return PlaybackEntitlement(url: url, channelID: channelId.value, drmType: drmType, licenseURL: laUrl, entitlementToken: entitlementToken)
    }
}

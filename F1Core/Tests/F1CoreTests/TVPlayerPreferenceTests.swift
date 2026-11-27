import XCTest
@testable import F1Core

final class TVPlayerPreferenceTests: XCTestCase {
    func testMigrationAndUnknownValuesPreserveOtherPreferences() throws {
        XCTAssertEqual(PlayerSettings().tvPlayerPreference, .multiview)
        for value in ["", #","tvPlayerPreference":"future-player""#, #","tvPlayerPreference":null"#] {
            let json = #"{"id":"saved","defaultFeed":"f1Live","liveStart":"beginning","audioDefaults":{"0":"de"},"preferredChannelVolume":{"2":0.4}"# + value + "}"
            let decoded = try JSONDecoder().decode(PlayerSettings.self, from: Data(json.utf8))
            XCTAssertEqual(decoded.tvPlayerPreference, .multiview)
            XCTAssertEqual(decoded.id, "saved")
            XCTAssertEqual(decoded.defaultFeed, .f1Live)
            XCTAssertEqual(decoded.liveStart, .beginning)
            XCTAssertEqual(decoded.audioDefaults[0], "de")
            XCTAssertEqual(decoded.preferredChannelVolume[2], 0.4)
        }
    }

    func testEveryPreferenceRoundTripsAndOnlyMultipleFeedsOfferChoice() throws {
        for preference in TVPlayerPreference.allCases {
            var settings = PlayerSettings()
            settings.tvPlayerPreference = preference
            settings.captionDefaults = [0: "off", 2: "en"]
            settings.f1LiveAudioTrack = "Commentary"
            let decoded = try JSONDecoder().decode(PlayerSettings.self, from: JSONEncoder().encode(settings))
            XCTAssertEqual(decoded.tvPlayerPreference, preference)
            XCTAssertEqual(decoded.captionDefaults, settings.captionDefaults)
            XCTAssertEqual(decoded.f1LiveAudioTrack, settings.f1LiveAudioTrack)
            XCTAssertEqual(preference.resolved(channelCount: 0), .native)
            XCTAssertEqual(preference.resolved(channelCount: 1), .native)
            XCTAssertEqual(preference.resolved(channelCount: 2), preference)
            XCTAssertEqual(preference.resolved(channelCount: 24), preference)
        }
    }
}

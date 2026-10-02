import Foundation
import XCTest

final class FairPlayLicenseRequestTests: XCTestCase {
    private let keyID = "84c4a502b5d235aa83272bf1eac8f88b"
    private let licenseURL = "https://license.example.com/CONTENT/LA/fairplay?contentId=123&channelId=1033"

    private func entitlement() -> PlaybackEntitlement {
        PlaybackEntitlement(url: "https://cdn.example.com/master.m3u8", channelID: "1033", drmType: "fairplay", licenseURL: licenseURL, entitlementToken: "stream-entitlement")
    }

    func testLicenseUsesStreamTokenAndOfficialWireFormat() throws {
        let request = try FairPlayLicenseRequest.make(streamEntitlement: entitlement(),
                                                     spcData: Data([0xfb, 0xff]), assetID: keyID,
                                                     subscriptionToken: "subscription-token")
        XCTAssertEqual(request.url?.absoluteString, licenseURL)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "entitlementtoken"), "stream-entitlement")
        XCTAssertEqual(request.value(forHTTPHeaderField: "ascendontoken"), "subscription-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/octet-stream")
        XCTAssertEqual(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8),
                       "spc=+/8=&assetId=\(keyID)")
    }

    func testPrefixedAndUnprefixedKeysUseTheSameIdentifier() throws {
        let prefixed = try XCTUnwrap(URL(string: "skd://0x" + keyID))
        let plain = try XCTUnwrap(URL(string: "skd://" + keyID))
        XCTAssertEqual(FairPlayLicenseRequest.assetID(for: prefixed), keyID)
        XCTAssertEqual(FairPlayLicenseRequest.assetID(for: plain), keyID)
        let assetID = try XCTUnwrap(FairPlayLicenseRequest.assetID(for: prefixed))
        let request = try FairPlayLicenseRequest.make(streamEntitlement: entitlement(), spcData: Data([1]),
                                                     assetID: assetID, subscriptionToken: "subscription-token")
        XCTAssertTrue(String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self).hasSuffix("&assetId=" + keyID))
    }

    func testNonDRMURLsAndEmptyKeyIDsAreRejected() throws {
        XCTAssertNil(FairPlayLicenseRequest.assetID(for: try XCTUnwrap(URL(string: "https://cdn.example.com/master.m3u8"))))
        XCTAssertNil(FairPlayLicenseRequest.assetID(for: try XCTUnwrap(URL(string: "skd://0x"))))
    }

    func testMissingEntitlementDoesNotFallBackToDeviceCredentials() {
        let stream = PlaybackEntitlement(url: entitlement().url, channelID: "1033", drmType: "fairplay", licenseURL: licenseURL, entitlementToken: "")
        XCTAssertThrowsError(try FairPlayLicenseRequest.make(streamEntitlement: stream, spcData: Data([1]),
                                                            assetID: keyID, subscriptionToken: "subscription-token")) {
            XCTAssertEqual(($0 as? URLError)?.code, .userAuthenticationRequired)
        }
    }

    func testMissingLicenseURLFailsWithoutCrashing() {
        let stream = PlaybackEntitlement(url: entitlement().url, channelID: "1033", drmType: "fairplay", licenseURL: nil, entitlementToken: "token")
        XCTAssertThrowsError(try FairPlayLicenseRequest.make(streamEntitlement: stream, spcData: Data([1]),
                                                            assetID: keyID, subscriptionToken: "subscription-token")) {
            XCTAssertEqual(($0 as? URLError)?.code, .badURL)
        }
    }

    func testEmptySPCIsNotSubmitted() {
        XCTAssertThrowsError(try FairPlayLicenseRequest.make(streamEntitlement: entitlement(), spcData: Data(),
                                                            assetID: keyID, subscriptionToken: "subscription-token")) {
            XCTAssertEqual(($0 as? CocoaError)?.code, .coderInvalidValue)
        }
    }
}

@main
enum FairPlayLicenseTestRunner {
    static func main() {
        let suite = FairPlayLicenseRequestTests.defaultTestSuite
        suite.run()
        exit(suite.testRun?.totalFailureCount == 0 ? 0 : 1)
    }
}

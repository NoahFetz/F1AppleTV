import Foundation

/// Runtime-only entitlement. URLs and tokens are never encoded or logged.
public struct PlaybackEntitlement: Sendable {
    public init(url: String, channelID: String, drmType: String?, licenseURL: String?, entitlementToken: String) { self.url = url; self.channelID = channelID; self.drmType = drmType; self.licenseURL = licenseURL; self.entitlementToken = entitlementToken }

    public let url: String
    public let channelID: String
    public let drmType: String?
    public let licenseURL: String?
    public let entitlementToken: String
}
public protocol FairPlayService: Sendable {
    func certificate() async throws -> Data
    func license(entitlement: PlaybackEntitlement, spc: Data, assetID: String) async throws -> Data
}

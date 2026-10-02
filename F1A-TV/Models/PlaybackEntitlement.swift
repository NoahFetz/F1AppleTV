import Foundation

/// Runtime-only entitlement. URLs and tokens are never encoded or logged.
struct PlaybackEntitlement: Sendable {
    let url: String
    let channelID: String
    let drmType: String?
    let licenseURL: String?
    let entitlementToken: String
}
protocol FairPlayService: Sendable {
    func certificate() async throws -> Data
    func license(entitlement: PlaybackEntitlement, spc: Data, assetID: String) async throws -> Data
}

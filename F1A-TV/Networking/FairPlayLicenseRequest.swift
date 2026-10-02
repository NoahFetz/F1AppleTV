import Foundation

enum FairPlayLicenseRequest {
    static func assetID(for keyURL: URL) -> String? {
        guard keyURL.scheme == "skd", let host = keyURL.host else { return nil }
        let assetID = host.lowercased().hasPrefix("0x") ? String(host.dropFirst(2)) : host
        return assetID.isEmpty ? nil : assetID
    }

    static func make(streamEntitlement: PlaybackEntitlement, spcData: Data, assetID: String,
                     subscriptionToken: String) throws -> URLRequest {
        try make(licenseURL: streamEntitlement.licenseURL, entitlementToken: streamEntitlement.entitlementToken, spcData: spcData, assetID: assetID, subscriptionToken: subscriptionToken)
    }

    static func make(licenseURL: String?, entitlementToken: String, spcData: Data, assetID: String, subscriptionToken: String) throws -> URLRequest {
        guard let urlString = licenseURL, let url = URL(string: urlString),
              url.scheme == "https", url.host != nil else {
            throw URLError(.badURL)
        }
        guard !entitlementToken.isEmpty, !subscriptionToken.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        guard !spcData.isEmpty, !assetID.isEmpty else {
            throw CocoaError(.coderInvalidValue)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Match the official player: base64 SPC and the normalized key ID in an octet-stream body.
        request.httpBody = "spc=\(spcData.base64EncodedString())&assetId=\(assetID)".data(using: .utf8)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(entitlementToken, forHTTPHeaderField: "entitlementtoken")
        request.setValue(subscriptionToken, forHTTPHeaderField: "ascendontoken")
        return request
    }
}

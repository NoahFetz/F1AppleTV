import Foundation

actor F1FairPlayService: FairPlayService {
    private let client: APIClient
    private let endpoints: APIEndpoints
    private let auth: any AuthorizedRequestSending
    private var cachedCertificate: Data?
    private var certificateTask: Task<Data, Error>?
    private var certificateID: UUID?
    init(client: APIClient, endpoints: APIEndpoints, auth: any AuthorizedRequestSending) { self.client = client; self.endpoints = endpoints; self.auth = auth }
    func certificate() async throws -> Data {
        try Task.checkCancellation()
        if let cachedCertificate { return cachedCertificate }
        if let certificateTask { let data = try await certificateTask.value; try Task.checkCancellation(); return data }
        let id = UUID(); certificateID = id
        let client = client, request = endpoints.certificate()
        let task = Task { () throws -> Data in
            let data = try await client.data(request, retryTransient: true)
            guard !data.isEmpty else { throw APIError.invalidResponse }; return data
        }
        certificateTask = task
        do {
            let data = try await task.value
            if certificateID == id { cachedCertificate = data; certificateTask = nil; certificateID = nil }
            try Task.checkCancellation(); return data
        } catch {
            if certificateID == id { certificateTask = nil; certificateID = nil }; throw error
        }
    }
    func license(entitlement: PlaybackEntitlement, spc: Data, assetID: String) async throws -> Data {
        try Task.checkCancellation()
        let token = try await auth.subscriptionToken()
        let request = try FairPlayLicenseRequest.make(licenseURL: entitlement.licenseURL, entitlementToken: entitlement.entitlementToken, spcData: spc, assetID: assetID, subscriptionToken: token)
        let data = try await client.data(request)
        try Task.checkCancellation()
        guard let ckc = Data(base64Encoded: data), !ckc.isEmpty else { throw APIError.invalidPlayback }
        return ckc
    }
}

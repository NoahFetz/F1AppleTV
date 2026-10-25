import Foundation

/// The provider's completed web session, without passwords or browser cookies.
public struct BrowserAccountSession: Codable, Equatable, Sendable {
    public let sessionID: String
    public let subscriptionToken: String
    public let profile: AccountProfile
    public static func decode(_ data: Data, previous: BrowserAccountSession? = nil) throws -> BrowserAccountSession {
        struct Payload: Decodable {
            var SessionId: WireIdentifier?
            var Subscriber: AccountDisplayDTO?
            var SessionSummary: AccountDisplayDTO?
            var data: AccountTokenDTO
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard !payload.data.subscriptionToken.isEmpty else { throw APIError.authentication }
        let id = payload.SessionId?.value ?? previous?.sessionID ?? tokenSessionID(payload.data.subscriptionToken)
        guard let id, !id.isEmpty else { throw APIError.authentication }
        let summary = (payload.Subscriber ?? payload.SessionSummary)?.stored
        let profile = summary.map { AccountProfile(firstName: $0.firstName, lastName: $0.lastName, email: $0.email, country: $0.homeCountry, subscriberID: $0.subscriberId, subscriptionStatus: payload.data.subscriptionStatus ?? previous?.profile.subscriptionStatus ?? "") } ?? previous?.profile
        guard let profile else { throw APIError.authentication }
        return BrowserAccountSession(sessionID: id, subscriptionToken: payload.data.subscriptionToken, profile: profile)
    }
    private static func tokenSessionID(_ token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var encoded = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let data = Data(base64Encoded: encoded), let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return value["SessionId"] as? String
    }
}

public protocol BrowserSessionCredentialStore: Sendable {
    func load() async throws -> BrowserAccountSession?
    func save(_ session: BrowserAccountSession) async throws
    func clear() async throws
}

/// Browser sessions use the website's subscriber retrieval flow. The original
/// device registration/refresh implementation remains the manual-login fallback.
public actor F1BrowserAuthService: StoredAuthService {
    private let fallback: F1AuthService
    private let client: APIClient
    private let endpoints: APIEndpoints
    private let store: any BrowserSessionCredentialStore
    private let playbackSessionID = UUID().uuidString
    private var session: BrowserAccountSession?
    private var loaded = false
    private var epoch = UUID()
    private var refreshTask: Task<Void, Error>?
    private var storageWrite: Task<Void, Error>?
    public init(fallback: F1AuthService, client: APIClient, endpoints: APIEndpoints, store: any BrowserSessionCredentialStore) {
        self.fallback = fallback; self.client = client; self.endpoints = endpoints; self.store = store
    }
    private func load() async throws {
        guard !loaded else { return }
        let generation = epoch
        let value = try await store.load()
        try Task.checkCancellation(); guard epoch == generation else { throw CancellationError() }
        session = value; loaded = true
    }
    private func persist(_ value: BrowserAccountSession?, generation: UUID) async throws {
        let previous = storageWrite, store = store
        let write = Task {
            if let previous { _ = try? await previous.value }
            try Task.checkCancellation(); guard self.epoch == generation else { throw CancellationError() }
            if let value { try await store.save(value) } else { try await store.clear() }
        }
        storageWrite = write; try await write.value
        try Task.checkCancellation(); guard epoch == generation else { throw CancellationError() }
    }
    public func accept(_ value: BrowserAccountSession) async throws -> AccountProfile {
        epoch = UUID(); let generation = epoch; refreshTask?.cancel(); refreshTask = nil
        do {
            try await persist(value, generation: generation)
            session = value; loaded = true; return value.profile
        } catch is CancellationError {
            if epoch == generation {
                epoch = UUID(); let clearing = epoch
                // A cancelled browser sheet must not leave a completed write behind.
                let cleanup = Task { try await self.persist(nil, generation: clearing) }
                try await cleanup.value
                session = nil; loaded = true
            }
            throw CancellationError()
        }
    }
    public func account() async throws -> AccountProfile? {
        try await load()
        if let session { return session.profile }
        return try await fallback.account()
    }
    public func prepareLogin(using provider: any LoginChallengeProviding) async throws -> LoginChallenge { try await fallback.prepareLogin(using: provider) }
    public func signIn(email: String, password: String, challenge: LoginChallenge) async throws -> AccountProfile {
        let profile = try await fallback.signIn(email: email, password: password, challenge: challenge)
        epoch = UUID(); let generation = epoch; refreshTask?.cancel(); refreshTask = nil
        try await persist(nil, generation: generation); session = nil; loaded = true
        return profile
    }
    public func signOut() async throws {
        try await load()
        guard session != nil else { try await fallback.signOut(); return }
        epoch = UUID(); let generation = epoch; refreshTask?.cancel(); refreshTask = nil
        // Clear the browser session even if unregistering an older fallback
        // device fails. A subsequent sign-in must not resurrect that session.
        try await persist(nil, generation: generation); session = nil; loaded = true
        do { try await fallback.signOut() }
        catch {
            guard epoch == generation else { throw CancellationError() }
            try await fallback.discardStoredSession()
            recordServiceFailure(error, operation: .logout)
        }
        guard epoch == generation else { throw CancellationError() }
    }
    public func subscriptionToken() async throws -> String {
        try await load(); try Task.checkCancellation()
        if let session { return session.subscriptionToken }
        return try await fallback.subscriptionToken()
    }
    public func discardStoredSession() async throws {
        epoch = UUID(); let generation = epoch; refreshTask?.cancel(); refreshTask = nil
        try await persist(nil, generation: generation); session = nil; loaded = true
        try await fallback.discardStoredSession()
    }
    public func authorizedData(_ request: URLRequest, mode: AuthorizationMode) async throws -> Data {
        try await load()
        guard let snapshot = session else { return try await fallback.authorizedData(request, mode: mode) }
        let generation = epoch
        func authorized(_ session: BrowserAccountSession) -> URLRequest {
            PlaybackAuthorizationHeaders.apply(to: request, subscriptionToken: session.subscriptionToken, accountSessionID: session.sessionID, playbackSessionID: playbackSessionID, mode: mode)
        }
        do {
            let data = try await client.data(authorized(snapshot))
            try Task.checkCancellation(); guard epoch == generation else { throw CancellationError() }; return data
        } catch APIError.http(401) where mode != .reporting {
            guard epoch == generation else { throw CancellationError() }
            try await refresh(snapshot, generation: generation)
            try Task.checkCancellation(); guard epoch == generation, let session else { throw CancellationError() }
            let data = try await client.data(authorized(session))
            try Task.checkCancellation(); guard epoch == generation else { throw CancellationError() }; return data
        } catch { guard epoch == generation else { throw CancellationError() }; throw error }
    }
    private func refresh(_ snapshot: BrowserAccountSession, generation: UUID) async throws {
        if session != snapshot { return }
        if let refreshTask { try await refreshTask.value; return }
        let task = Task {
            var request = URLRequest(url: self.endpoints.accountBase.appendingPathComponent("v1/account/Subscriber/RetrieveSubscriber"))
            request.httpMethod = "POST"; request.httpBody = Data("{}".utf8)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("fCUCjWrKPu9ylJwRAv8BpGLEgiAuThx7", forHTTPHeaderField: "apikey")
            request.setValue(self.endpoints.systemID, forHTTPHeaderField: "CD-SystemID")
            request.setValue(self.endpoints.language, forHTTPHeaderField: "CD-Language")
            request.setValue(snapshot.sessionID, forHTTPHeaderField: "CD-SessionID")
            let value = try BrowserAccountSession.decode(await self.client.data(request), previous: snapshot)
            try Task.checkCancellation(); guard self.epoch == generation else { throw CancellationError() }
            try await self.persist(value, generation: generation); self.session = value
        }
        refreshTask = task
        do { try await task.value; if epoch == generation { refreshTask = nil } }
        catch { if epoch == generation { refreshTask = nil }; throw error }
    }
}

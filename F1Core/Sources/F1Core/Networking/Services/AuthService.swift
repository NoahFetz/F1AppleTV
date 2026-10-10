import Foundation

public struct LoginChallenge: Sendable { fileprivate let value: String; public init(_ value: String) { self.value = value } }
public protocol LoginChallengeProviding: Sendable { func prepare() async throws -> LoginChallenge }
public protocol AuthService: Sendable {
    func account() async throws -> AccountProfile?
    func prepareLogin(using provider: any LoginChallengeProviding) async throws -> LoginChallenge
    func signIn(email: String, password: String, challenge: LoginChallenge) async throws -> AccountProfile
    func signOut() async throws
}
public protocol SessionCredentialStore: Sendable {
    func load() async throws -> DeviceRegistrationResultDto?
    func save(_ registration: DeviceRegistrationResultDto) async throws
    func clear() async throws
}

public enum AuthorizationMode: Sendable { case video, entitlement, reporting }
public protocol AuthorizedRequestSending: Sendable {
    func authorizedData(_ request: URLRequest, mode: AuthorizationMode) async throws -> Data
    func subscriptionToken() async throws -> String
}

public enum PlaybackAuthorizationHeaders {
    public static func apply(to request: URLRequest, subscriptionToken: String, accountSessionID: String, playbackSessionID: String, mode: AuthorizationMode) -> URLRequest {
        var request = request
        request.setValue(playbackSessionID, forHTTPHeaderField: "sessionid")
        request.setValue(mode == .video ? subscriptionToken : accountSessionID, forHTTPHeaderField: "entitlementtoken")
        request.setValue(subscriptionToken, forHTTPHeaderField: "ascendontoken")
        return request
    }
}

public actor F1AuthService: AuthService, AuthorizedRequestSending {
    private let client: APIClient
    private let endpoints: APIEndpoints
    private let storage: any SessionCredentialStore
    private let sessionID: String
    private let deviceFactory: @Sendable () -> DeviceRegistrationRequestDeviceDto
    private let nickname: String
    private var registration: DeviceRegistrationResultDto?
    private var loaded = false
    private var epoch = UUID()
    private var loadTask: Task<DeviceRegistrationResultDto?, Error>?
    private var refreshTask: Task<Void, Error>?
    private var refreshID: UUID?
    private var unregistered = false
    private var storageWrite: Task<Void, Error>?
    public init(client: APIClient, endpoints: APIEndpoints, storage: any SessionCredentialStore, sessionID: String = "WEB-\(UUID().uuidString)", nickname: String = "VroomTV tvOS", deviceFactory: @escaping @Sendable () -> DeviceRegistrationRequestDeviceDto = { DeviceRegistrationRequestDeviceDto() }) {
        self.client = client; self.endpoints = endpoints; self.storage = storage; self.sessionID = sessionID; self.nickname = nickname; self.deviceFactory = deviceFactory
    }
    private func load() async throws {
        guard !loaded else { return }
        let generation = epoch
        if loadTask == nil { let store = storage; loadTask = Task { do { return try await store.load() } catch { if AppErrorStore.isCancellation(error) { throw error }; throw ServiceFailure(operation: .credentials, underlying: error) } } }
        do {
            let value = try await loadTask!.value
            guard generation == epoch else { throw CancellationError() }
            registration = value; loaded = true; loadTask = nil
        } catch { if generation == epoch { loadTask = nil }; throw error }
    }
    private func credentials() async throws -> DeviceRegistrationResultDto {
        try await load(); try Task.checkCancellation()
        guard let registration, Self.valid(registration), !unregistered else { throw APIError.authentication }
        return registration
    }
    private static func valid(_ value: DeviceRegistrationResultDto) -> Bool {
        !value.sessionId.isEmpty && !value.physicalDevice.authenticationKey.isEmpty && !value.physicalDevice.deviceId.isEmpty && !value.data.subscriptionToken.isEmpty
    }
    private static func profile(_ value: DeviceRegistrationResultDto) -> AccountProfile {
        let p = value.sessionSummary
        return AccountProfile(firstName: p.firstName, lastName: p.lastName, email: p.email, country: p.homeCountry, subscriberID: p.subscriberId, subscriptionStatus: value.data.subscriptionStatus)
    }
    public func account() async throws -> AccountProfile? {
        try await load(); try Task.checkCancellation()
        guard let registration, Self.valid(registration), !unregistered else { return nil }
        return Self.profile(registration)
    }
    public func prepareLogin(using provider: any LoginChallengeProviding) async throws -> LoginChallenge {
        try Task.checkCancellation(); let challenge = try await provider.prepare(); try Task.checkCancellation(); return challenge
    }
    public func signIn(email: String, password: String, challenge: LoginChallenge) async throws -> AccountProfile {
        guard !email.isEmpty, !password.isEmpty, !challenge.value.isEmpty else { throw APIError.authentication }
        epoch = UUID(); let generation = epoch
        refreshTask?.cancel(); refreshTask = nil; refreshID = nil
        let body = DeviceRegistrationRequestDto(physicalDevice: deviceFactory(), nickname: nickname, login: email, password: password)
        let request = try endpoints.register(body, challenge: challenge.value)
        let data = try await client.data(request)
        let value = try APIClient.decode(AccountRegistrationDTO.self, from: data).stored()
        guard Self.valid(value) else { throw APIError.invalidResponse }
        try Task.checkCancellation(); guard generation == epoch else { throw CancellationError() }
        try await persist(value, generation: generation)
        guard generation == epoch else { throw CancellationError() }
        registration = value; loaded = true; unregistered = false
        return Self.profile(value)
    }
    public func signOut() async throws {
        try await load()
        epoch = UUID(); let generation = epoch
        refreshTask?.cancel(); refreshTask = nil; refreshID = nil
        if let value = registration, !unregistered {
            let body = DeviceUnregistrationRequestDto(deviceId: value.physicalDevice.deviceId, authenticationKey: value.physicalDevice.authenticationKey)
            let request = try endpoints.unregister(body, sessionID: value.sessionId)
            _ = try await client.data(request)
            guard generation == epoch else { throw CancellationError() }
            unregistered = true
        }
        try await persist(nil, generation: generation)
        guard generation == epoch else { throw CancellationError() }
        registration = nil; loaded = true; unregistered = false
    }
    /// Discard a superseded device session locally when remote unregistration fails.
    public func discardStoredSession() async throws {
        loadTask?.cancel(); loadTask = nil
        epoch = UUID(); let generation = epoch
        refreshTask?.cancel(); refreshTask = nil; refreshID = nil
        try await persist(nil, generation: generation)
        registration = nil; loaded = true; unregistered = false
    }
    /// Queue writes across actor reentrancy: logout clears after every already-running save.
    private func persist(_ value: DeviceRegistrationResultDto?, generation: UUID) async throws {
        let previous = storageWrite
        let store = storage
        let task = Task {
            if let previous { _ = try? await previous.value }
            try Task.checkCancellation()
            guard self.epoch == generation else { throw CancellationError() }
            do { if let value { try await store.save(value) } else { try await store.clear() } }
            catch { if AppErrorStore.isCancellation(error) { throw error }; throw ServiceFailure(operation: .credentials, underlying: error) }
        }
        storageWrite = task
        try await task.value
        guard generation == epoch else { throw CancellationError() }
    }
    private func headers(_ request: URLRequest, credentials value: DeviceRegistrationResultDto, mode: AuthorizationMode) -> URLRequest {
        PlaybackAuthorizationHeaders.apply(to: request, subscriptionToken: value.data.subscriptionToken, accountSessionID: value.sessionId, playbackSessionID: sessionID, mode: mode)
    }
    public func authorizedData(_ request: URLRequest, mode: AuthorizationMode) async throws -> Data {
        let value = try await credentials(); let generation = epoch
        do {
            let data = try await client.data(headers(request, credentials: value, mode: mode))
            try Task.checkCancellation(); guard generation == epoch else { throw CancellationError() }; return data
        } catch APIError.http(401) where mode != .reporting {
            guard generation == epoch else { throw CancellationError() }
            try await refresh(ifMatching: value)
            try Task.checkCancellation(); guard generation == epoch else { throw CancellationError() }
            let refreshed = try await credentials()
            let data = try await client.data(headers(request, credentials: refreshed, mode: mode))
            try Task.checkCancellation(); guard generation == epoch else { throw CancellationError() }; return data
        } catch {
            guard generation == epoch else { throw CancellationError() }; throw error
        }
    }
    private func refresh(ifMatching snapshot: DeviceRegistrationResultDto) async throws {
        if registration?.sessionId != snapshot.sessionId || registration?.data.subscriptionToken != snapshot.data.subscriptionToken { return }
        if let refreshTask { try await refreshTask.value; return }
        let id = UUID(); refreshID = id
        let generation = epoch
        let task = Task {
            do { try await self.performRefresh(snapshot: snapshot, generation: generation) }
            catch { if error is ServiceFailure || AppErrorStore.isCancellation(error) { throw error }; throw ServiceFailure(operation: .tokenRefresh, underlying: error) }
        }
        refreshTask = task
        do { try await task.value; if refreshID == id { refreshTask = nil; refreshID = nil } }
        catch { if refreshID == id { refreshTask = nil; refreshID = nil }; throw error }
    }
    private func performRefresh(snapshot: DeviceRegistrationResultDto, generation: UUID) async throws {
        let body = DeviceAuthenticationRequestDto(distributionChannel: endpoints.distributionChannel, authenticationKey: snapshot.physicalDevice.authenticationKey, language: "en-GB", deviceId: snapshot.physicalDevice.deviceId)
        let request = try endpoints.refresh(body)
        let data = try await client.data(request)
        let response = try APIClient.decode(AccountRefreshDTO.self, from: data)
        guard !response.authenticationKey.isEmpty, !response.data.subscriptionToken.isEmpty else { throw APIError.invalidResponse }
        var value = snapshot
        value.sessionId = response.authenticationKey; value.physicalDevice.authenticationKey = response.authenticationKey; value.data = response.data.stored
        if let subscriber = response.subscriber { value.sessionSummary = subscriber.stored }
        try Task.checkCancellation(); guard generation == epoch else { throw CancellationError() }
        try await persist(value, generation: generation)
        guard generation == epoch else { throw CancellationError() }
        registration = value
    }
    public func subscriptionToken() async throws -> String { try await credentials().data.subscriptionToken }
}

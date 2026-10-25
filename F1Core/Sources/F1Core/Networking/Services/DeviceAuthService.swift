import Foundation

public struct DeviceAuthorization: Sendable {
    public let userCode: String
    public let verificationURL: URL
    public let qrCodeURL: URL
    public let expiresAt: Date
    let deviceCode: String
    let interval: TimeInterval
    let identity: UUID
}

public protocol DeviceSignInService: Sendable {
    func beginSignIn() async throws -> DeviceAuthorization
    func completeSignIn(_ authorization: DeviceAuthorization) async throws -> AccountProfile
}

public enum DeviceSignInError: Int, Error, CustomNSError {
    case expired = 1101, denied, invalidResponse, unavailable, rejected
    public static var errorDomain: String { "DeviceSignIn" }
    public var errorCode: Int { rawValue }
    public var errorUserInfo: [String: Any] { [:] }
}

public struct DeviceAuthResponse: Sendable {
    public let status: Int
    public let data: Data
    public init(status: Int, data: Data) { self.status = status; self.data = data }
}

/// OAuth polling needs the error body (authorization_pending/slow_down), which
/// the ordinary API transport intentionally discards on HTTP failures.
public protocol DeviceAuthTransport: Sendable {
    func send(_ request: URLRequest) async throws -> DeviceAuthResponse
}

private final class DeviceAuthRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

public struct URLSessionDeviceAuthTransport: DeviceAuthTransport {
    private let session: URLSession
    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        session = URLSession(configuration: configuration, delegate: DeviceAuthRedirectDelegate(), delegateQueue: nil)
    }
    public func send(_ request: URLRequest) async throws -> DeviceAuthResponse {
        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse else { throw DeviceSignInError.invalidResponse }
            return DeviceAuthResponse(status: response.statusCode, data: data)
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw APIError.transport(error.errorCode)
        }
    }
}

/// Contains credentials; persist only in the platform Keychain, never preferences.
public struct DeviceAccountSession: Codable, Sendable {
    let refreshToken: String
    let expiresAt: Date
    let playback: BrowserAccountSession

    static func decode(_ data: Data, previous: DeviceAccountSession? = nil, now: Date) throws -> DeviceAccountSession {
        struct Tokens: Decodable {
            let access_token: String
            let token_type: String
            let expires_in: Double
            let refresh_token: String?
        }
        let tokens = try JSONDecoder().decode(Tokens.self, from: data)
        guard tokens.token_type.lowercased() == "bearer", tokens.expires_in.isFinite, tokens.expires_in > 0,
              let access = jwt(tokens.access_token),
              let subscription = (access["subscriptionToken"] as? String) ?? previous?.playback.subscriptionToken,
              let claims = jwt(subscription), let sessionID = claims["SessionId"] as? String, !sessionID.isEmpty,
              let expiry = claims["exp"] as? Double,
              let subscriber = claims["SubscriberId"].flatMap({ Int(String(describing: $0)) }), subscriber > 0,
              let refreshToken = tokens.refresh_token ?? previous?.refreshToken, !refreshToken.isEmpty else {
            throw DeviceSignInError.invalidResponse
        }
        // F1's hourly OAuth refresh omits subscriptionToken. That separate
        // playback credential currently lasts four days and remains usable
        // across refreshes, but its own expiration must never be extended.
        guard expiry > now.timeIntervalSince1970 else { throw DeviceSignInError.expired }
        // These are the playback claims returned by F1 over the token endpoint's
        // authenticated TLS connection. The playback server validates the token.
        let profile = AccountProfile(firstName: claims["FirstName"] as? String ?? "", lastName: claims["LastName"] as? String ?? "",
                                     email: claims["Email"] as? String ?? "", country: claims["HomeCountry"] as? String ?? "",
                                     subscriberID: subscriber, subscriptionStatus: claims["SubscriptionStatus"] as? String ?? "")
        return DeviceAccountSession(refreshToken: refreshToken,
                                    expiresAt: min(now.addingTimeInterval(tokens.expires_in), Date(timeIntervalSince1970: expiry)),
                                    playback: BrowserAccountSession(sessionID: sessionID, subscriptionToken: subscription, profile: profile))
    }
    private static func jwt(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, !parts[0].isEmpty, !parts[2].isEmpty else { return nil }
        var value = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        value += String(repeating: "=", count: (4 - value.count % 4) % 4)
        guard let data = Data(base64Encoded: value) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

public protocol DeviceSessionCredentialStore: Sendable {
    func load() async throws -> DeviceAccountSession?
    func save(_ session: DeviceAccountSession) async throws
    func clear() async throws
}

public actor F1DeviceAuthService: AuthService, AuthorizedRequestSending, DeviceSignInService {
    // Public TV client identifier published by account.formula1.com. No client
    // secret is embedded or required by the device authorization grant.
    public static let clientID = "13c21153-f2f3-484b-a642-f2a2927e55de"
    private let transport: any DeviceAuthTransport
    private let client: APIClient
    private let fallback: any StoredAuthService
    private let store: any DeviceSessionCredentialStore
    private let now: @Sendable () -> Date
    private let wait: @Sendable (TimeInterval) async throws -> Void
    private let playbackSessionID = UUID().uuidString
    private var session: DeviceAccountSession?
    private var loaded = false
    private var epoch = UUID()
    private var loginID = UUID()
    private var refreshTask: Task<Void, Error>?
    private var storageWrite: Task<Void, Error>?

    public init(client: APIClient, fallback: any StoredAuthService, store: any DeviceSessionCredentialStore,
                transport: any DeviceAuthTransport = URLSessionDeviceAuthTransport(),
                now: @escaping @Sendable () -> Date = { Date() },
                wait: @escaping @Sendable (TimeInterval) async throws -> Void = { try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) }) {
        self.client = client; self.fallback = fallback; self.store = store; self.transport = transport; self.now = now; self.wait = wait
    }
    public func beginSignIn() async throws -> DeviceAuthorization {
        struct Response: Decodable {
            let device_code: String, user_code: String, verification_uri: String
            let verification_uri_complete: String?
            let expires_in: Double
            let interval: Double?
        }
        loginID = UUID(); let identity = loginID
        epoch = UUID(); refreshTask?.cancel(); refreshTask = nil
        let response = try await form("device_authorization", ["client_id": Self.clientID, "scope": "openid f1tv_groups"])
        guard identity == loginID else { throw CancellationError() }
        guard response.status == 200 else { throw DeviceSignInError.unavailable }
        let value = try JSONDecoder().decode(Response.self, from: response.data)
        guard !value.device_code.isEmpty, !value.user_code.isEmpty, value.expires_in.isFinite, value.expires_in > 0, value.expires_in <= 86_400,
              (value.interval ?? 5).isFinite, (value.interval ?? 5) > 0,
              let url = verificationURL(value.verification_uri),
              let qr = verificationURL(value.verification_uri_complete ?? value.verification_uri) else { throw DeviceSignInError.invalidResponse }
        return DeviceAuthorization(userCode: value.user_code, verificationURL: url, qrCodeURL: qr,
                                   expiresAt: now().addingTimeInterval(value.expires_in), deviceCode: value.device_code,
                                   interval: value.interval ?? 5, identity: identity)
    }
    public func completeSignIn(_ authorization: DeviceAuthorization) async throws -> AccountProfile {
        try await completeSignIn(authorization, browserApproved: false)
    }
    /// The local browser provides a return channel (RFC 8628 section 3.5), so
    /// start the first token request when approval arrives instead of polling
    /// during credential entry. Pending responses still obey the provider interval.
    public func completeBrowserSignIn(_ authorization: DeviceAuthorization) async throws -> AccountProfile {
        try await completeSignIn(authorization, browserApproved: true)
    }
    private func completeSignIn(_ authorization: DeviceAuthorization, browserApproved: Bool) async throws -> AccountProfile {
        let generation = epoch
        var interval = authorization.interval
        var firstRequest = true
        while true {
            try Task.checkCancellation()
            guard authorization.identity == loginID, generation == epoch else { throw CancellationError() }
            let remaining = authorization.expiresAt.timeIntervalSince(now())
            guard remaining > 0 else { throw DeviceSignInError.expired }
            if !firstRequest || !browserApproved { try await wait(min(interval, remaining)) }
            firstRequest = false
            try Task.checkCancellation()
            guard authorization.identity == loginID, generation == epoch else { throw CancellationError() }
            guard authorization.expiresAt > now() else { throw DeviceSignInError.expired }
            let response: DeviceAuthResponse
            do {
                response = try await form("token", ["client_id": Self.clientID, "grant_type": "urn:ietf:params:oauth:grant-type:device_code", "device_code": authorization.deviceCode])
            } catch APIError.transport(NSURLErrorTimedOut) { interval = min(interval * 2, 60); continue }
            guard authorization.identity == loginID, generation == epoch else { throw CancellationError() }
            if response.status == 200 {
                let value = try DeviceAccountSession.decode(response.data, now: now())
                epoch = UUID(); let acceptance = epoch
                refreshTask?.cancel(); refreshTask = nil
                try await accept(value, generation: acceptance)
                loginID = UUID()
                return value.playback.profile
            }
            if response.status >= 500 { interval = min(interval * 2, 60); continue }
            switch oauthError(response.data) {
            case "authorization_pending": continue
            case "slow_down": interval += 5
            case "access_denied": throw DeviceSignInError.denied
            case "expired_token": throw DeviceSignInError.expired
            default: throw DeviceSignInError.rejected
            }
        }
    }
    private func accept(_ value: DeviceAccountSession, generation: UUID) async throws {
        do {
            try await persist(value, generation: generation)
            session = value; loaded = true
        } catch is CancellationError {
            if epoch == generation {
                epoch = UUID(); let clearing = epoch
                let cleanup = Task { try await self.persist(nil, generation: clearing); self.session = nil; self.loaded = true }
                try await cleanup.value
            }
            throw CancellationError()
        }
    }
    private func load() async throws {
        guard !loaded else { return }
        let generation = epoch
        let value = try await store.load()
        try Task.checkCancellation(); guard epoch == generation else { throw CancellationError() }
        session = value; loaded = true
    }
    private func persist(_ value: DeviceAccountSession?, generation: UUID) async throws {
        let previous = storageWrite, store = store
        let task = Task {
            if let previous { _ = try? await previous.value }
            try Task.checkCancellation(); guard self.epoch == generation else { throw CancellationError() }
            if let value { try await store.save(value) } else { try await store.clear() }
        }
        storageWrite = task; try await task.value
        try Task.checkCancellation(); guard epoch == generation else { throw CancellationError() }
    }
    public func account() async throws -> AccountProfile? {
        try await load()
        if let session { return session.playback.profile }
        return try await fallback.account()
    }
    public func hasOAuthSession() async throws -> Bool { try await load(); return session != nil }
    public func prepareLogin(using provider: any LoginChallengeProviding) async throws -> LoginChallenge { try await fallback.prepareLogin(using: provider) }
    public func signIn(email: String, password: String, challenge: LoginChallenge) async throws -> AccountProfile {
        throw DeviceSignInError.unavailable
    }
    public func signOut() async throws {
        try await load()
        let hasDeviceSession = session != nil
        epoch = UUID(); let generation = epoch; loginID = UUID()
        refreshTask?.cancel(); refreshTask = nil
        if !hasDeviceSession { try await fallback.signOut(); return }
        try await persist(nil, generation: generation); session = nil; loaded = true
        // A successful OAuth sign-in supersedes an existing legacy login.
        // Clearing it prevents signing out from resurrecting that old account.
        try await fallback.discardStoredSession()
    }
    public func subscriptionToken() async throws -> String {
        try await load()
        guard let value = session else { return try await fallback.subscriptionToken() }
        if value.expiresAt.timeIntervalSince(now()) <= 30 { try await refresh(value, generation: epoch) }
        try Task.checkCancellation()
        guard let session else { throw APIError.authentication }
        return session.playback.subscriptionToken
    }
    public func authorizedData(_ request: URLRequest, mode: AuthorizationMode) async throws -> Data {
        try await load()
        guard session != nil else { return try await fallback.authorizedData(request, mode: mode) }
        let generation = epoch
        _ = try await subscriptionToken()
        guard generation == epoch, let snapshot = session else { throw CancellationError() }
        func authorized(_ value: DeviceAccountSession) -> URLRequest {
            PlaybackAuthorizationHeaders.apply(to: request, subscriptionToken: value.playback.subscriptionToken,
                                               accountSessionID: value.playback.sessionID, playbackSessionID: playbackSessionID, mode: mode)
        }
        do {
            let data = try await client.data(authorized(snapshot))
            try Task.checkCancellation(); guard generation == epoch else { throw CancellationError() }; return data
        } catch APIError.http(401) where mode != .reporting {
            try await refresh(snapshot, generation: generation)
            guard generation == epoch, let session else { throw CancellationError() }
            let data = try await client.data(authorized(session))
            try Task.checkCancellation(); guard generation == epoch else { throw CancellationError() }; return data
        }
    }
    private func refresh(_ snapshot: DeviceAccountSession, generation: UUID) async throws {
        guard generation == epoch else { throw CancellationError() }
        if session?.refreshToken != snapshot.refreshToken || session?.expiresAt != snapshot.expiresAt { return }
        if let refreshTask { try await refreshTask.value; return }
        let task = Task {
            let response = try await self.form("token", ["client_id": Self.clientID, "grant_type": "refresh_token", "refresh_token": snapshot.refreshToken])
            guard self.epoch == generation else { throw CancellationError() }
            if response.status == 400, self.oauthError(response.data) == "invalid_grant" {
                try await self.persist(nil, generation: generation); self.session = nil; self.loaded = true
                try await self.fallback.discardStoredSession()
                throw DeviceSignInError.rejected
            }
            guard response.status == 200 else { throw DeviceSignInError.rejected }
            let value: DeviceAccountSession
            do { value = try DeviceAccountSession.decode(response.data, previous: snapshot, now: self.now()) }
            catch DeviceSignInError.expired {
                try await self.persist(nil, generation: generation); self.session = nil; self.loaded = true
                try await self.fallback.discardStoredSession()
                throw DeviceSignInError.expired
            }
            try await self.persist(value, generation: generation); self.session = value
        }
        refreshTask = task
        do { try await task.value; try Task.checkCancellation(); if epoch == generation { refreshTask = nil } }
        catch { if epoch == generation { refreshTask = nil }; throw error }
    }
    private func form(_ path: String, _ values: [String: String]) async throws -> DeviceAuthResponse {
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let body = values.keys.sorted().map { key in
            key.addingPercentEncoding(withAllowedCharacters: safe)! + "=" + values[key]!.addingPercentEncoding(withAllowedCharacters: safe)!
        }.joined(separator: "&")
        var request = URLRequest(url: URL(string: "https://id.formula1.com/as/" + path)!)
        request.httpMethod = "POST"; request.httpBody = Data(body.utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try Task.checkCancellation()
        let response = try await transport.send(request)
        try Task.checkCancellation(); return response
    }
    private func oauthError(_ data: Data) -> String? {
        struct Response: Decodable { let error: String }
        return (try? JSONDecoder().decode(Response.self, from: data))?.error
    }
    private func verificationURL(_ value: String) -> URL? {
        guard let url = URL(string: value), url.scheme == "https", url.user == nil, url.password == nil,
              let host = url.host?.lowercased(), host == "f1.com" || host.hasSuffix(".f1.com") || host == "formula1.com" || host.hasSuffix(".formula1.com") else { return nil }
        return url
    }
}

/// Both platforms share persistence, refresh rotation and playback authorization.
/// tvOS presents phone/QR pairing; macOS opens the prefilled verification page locally.
public typealias F1OAuthAuthService = F1DeviceAuthService

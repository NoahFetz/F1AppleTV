import SwiftUI
import Security
import WebKit
import F1Core

@MainActor final class MacPreferences: ObservableObject {
    @Published var player: PlayerSettings { didSet { save() } }
    @Published var dynamicRange: PlayerDynamicRange { didSet { defaults.set(dynamicRange.rawValue, forKey: "DesktopDynamicRange.v1") } }
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        dynamicRange = PlayerDynamicRange(rawValue: defaults.string(forKey: "DesktopDynamicRange.v1") ?? "") ?? .automatic
        player = defaults.data(forKey: "DesktopPlayerSettings.v1").flatMap { try? JSONDecoder().decode(PlayerSettings.self, from: $0) } ?? PlayerSettings()
    }
    private func save() {
        do { defaults.set(try JSONEncoder().encode(player), forKey: "DesktopPlayerSettings.v1") }
        catch { recordServiceFailure(error, operation: .credentials) }
    }
}

actor MacSessionStore: SessionCredentialStore {
    private let service = (Bundle.main.bundleIdentifier ?? "ch.fetz-gr.F1A-Mac") + ".credentials"
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "registration"]
    }
    func load() async throws -> DeviceRegistrationResultDto? {
        var query = query; query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = value as? Data else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        return try JSONDecoder().decode(DeviceRegistrationResultDto.self, from: data)
    }
    func save(_ registration: DeviceRegistrationResultDto) async throws {
        let values = [kSecValueData as String: try JSONEncoder().encode(registration)]
        var status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query; insert.merge(values) { _, new in new }
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(insert as CFDictionary, nil)
            if status == errSecDuplicateItem { status = SecItemUpdate(query as CFDictionary, values as CFDictionary) }
        }
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }
    func clear() async throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }
}

actor MacBrowserSessionStore: BrowserSessionCredentialStore {
    private let service = (Bundle.main.bundleIdentifier ?? "ch.fetz-gr.F1A-Mac") + ".credentials"
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "browser-session"]
    }
    func load() async throws -> BrowserAccountSession? {
        var query = query; query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = value as? Data else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        return try JSONDecoder().decode(BrowserAccountSession.self, from: data)
    }
    func save(_ registration: BrowserAccountSession) async throws {
        let values = [kSecValueData as String: try JSONEncoder().encode(registration)]
        var status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query; insert.merge(values) { _, new in new }
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(insert as CFDictionary, nil)
            if status == errSecDuplicateItem { status = SecItemUpdate(query as CFDictionary, values as CFDictionary) }
        }
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }
    func clear() async throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }
}

@MainActor final class MacLoginChallenge: ObservableObject, LoginChallengeProviding {
    let browser: WKWebView
    @Published var needsInteraction = false
    init() {
        let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
        browser = WKWebView(frame: .zero, configuration: config)
    }
    func prepare() async throws -> LoginChallenge {
        needsInteraction = false
        let cookies = browser.configuration.websiteDataStore.httpCookieStore
        for cookie in await cookies.allCookies() where cookie.name == "reese84" { await cookies.deleteCookie(cookie) }
        browser.load(URLRequest(url: URL(string: "https://account.formula1.com/#/login")!))
        defer { browser.stopLoading(); needsInteraction = false }
        for attempt in 0..<60 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try Task.checkCancellation()
            if let cookie = await cookies.allCookies().first(where: { ($0.domain == "formula1.com" || $0.domain.hasSuffix(".formula1.com")) && $0.name == "reese84" && !$0.value.isEmpty }) {
                return LoginChallenge(cookie.value)
            }
            if attempt >= 7 { needsInteraction = true }
        }
        throw APIError.authentication
    }
}

@MainActor final class MacServices {
    let catalog: any CatalogService
    let auth: F1BrowserAuthService
    let playback: any PlaybackService
    let fairPlay: any FairPlayService
    let language: String
    let preferences = MacPreferences()
    init() {
        var endpoints = APIEndpoints()
        endpoints.language = APILanguageType.fromAPIKey(apiKey: "api_endpoing_language_id".localizedString).getAPIKey()
        language = endpoints.language
        let client = APIClient(transport: URLSessionHTTPTransport())
        let fallback = F1AuthService(client: client, endpoints: endpoints, storage: MacSessionStore(), nickname: "Vroom TV macOS", deviceFactory: {
            DeviceRegistrationRequestDeviceDto(deviceTypeCode: 12, deviceId: "\(UUID().uuidString)-macOS", physicalDeviceTypeCode: 1002)
        })
        let auth = F1BrowserAuthService(fallback: fallback, client: client, endpoints: endpoints, store: MacBrowserSessionStore())
        self.auth = auth
        #if DEBUG
        if let directory = ProcessInfo.processInfo.environment["F1_CATALOG_FIXTURES"] {
            catalog = FixtureCatalog(directory: URL(fileURLWithPath: directory))
        } else { catalog = F1CatalogService(client: client, endpoints: endpoints) }
        #else
        catalog = F1CatalogService(client: client, endpoints: endpoints)
        #endif
        playback = F1PlaybackService(endpoints: endpoints, auth: auth)
        fairPlay = F1FairPlayService(client: client, endpoints: endpoints, auth: auth)
    }
}

#if DEBUG
struct FixtureCatalog: CatalogService {
    let directory: URL
    func menu() async throws -> [CatalogMenuEntry] {
        let payload = try APIClient.decode(APIEnvelope<CatalogPayloadDTO>.self, from: Data(contentsOf: directory.appendingPathComponent("menu.json")))
        guard let payload = payload.resultObj else { throw APIError.invalidResponse }
        return CatalogMapper.menu(payload)
    }
    func page(_ destination: CatalogDestination) async throws -> CatalogDocument {
        let name: String
        if destination.uri.contains("395") { name = "home" }
        else if destination.uri.contains("12343") { name = "season" }
        else if destination.href.contains("archive") || destination.uri.contains("493") { name = "archive" }
        else { name = "australia" }
        let url = directory.appendingPathComponent(name + ".json")
        let fallback = directory.appendingPathComponent("azerbaijan.json")
        let payload = try APIClient.decode(APIEnvelope<CatalogPayloadDTO>.self, from: Data(contentsOf: FileManager.default.fileExists(atPath: url.path) ? url : fallback))
        guard let payload = payload.resultObj else { throw APIError.invalidResponse }
        return CatalogDocument(sections: CatalogMapper.sections(payload))
    }
}
#endif

import AppKit
import SwiftUI
import WebKit
import F1Core

// Only presentation decoration is replaced. Authentication, browser lifecycle,
// verification JavaScript and Keychain storage come from the production files.
struct LoadingStatus: View { let title: String; var body: some View { Text(title) } }
private actor MemoryOAuthStore: DeviceSessionCredentialStore {
    var value: DeviceAccountSession?
    func load() async throws -> DeviceAccountSession? { value }
    func save(_ value: DeviceAccountSession) async throws { self.value = value }
    func clear() async throws { value = nil }
}
private actor EmptyLegacyStore: SessionCredentialStore {
    func load() async throws -> DeviceRegistrationResultDto? { nil }
    func save(_ value: DeviceRegistrationResultDto) async throws {}
    func clear() async throws {}
}
private struct NoAPI: HTTPTransport {
    func send(_ request: URLRequest) async throws -> Data { throw APIError.invalidResponse }
}
private actor PendingOAuth: DeviceAuthTransport {
    var requests = 0
    var rejectsTokens = false
    func rejectTokens() { rejectsTokens = true }
    func send(_ request: URLRequest) async throws -> DeviceAuthResponse {
        requests += 1
        if request.url?.lastPathComponent == "device_authorization" {
            return DeviceAuthResponse(status: 200, data: Data(#"{"device_code":"fixture-device","user_code":"ABCD-EFGH","verification_uri":"https://f1.com/pair","verification_uri_complete":"https://f1.com/pair?user_code=ABCD-EFGH","expires_in":600,"interval":1}"#.utf8))
        }
        if rejectsTokens { throw DeviceSignInError.rejected }
        try await Task.sleep(nanoseconds: 30_000_000_000)
        throw CancellationError()
    }
}
@main struct MacOAuthTests {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        precondition(Bundle.main.bundleIdentifier == "ch.fetz-gr.F1A-Mac.OAuthTests", "Tests must never use the production Keychain service")
        var count = 0
        func check(_ passed: Bool, _ name: String) {
            precondition(passed, name); count += 1; print("PASS: \(name)")
        }
        func wait(_ condition: @escaping @MainActor () async throws -> Bool) async throws {
            for _ in 0..<200 { if try await condition() { return }; try await Task.sleep(nanoseconds: 25_000_000) }
            throw URLError(.timedOut)
        }
        func fixture(host: String = "account.formula1.com", route: String = "/en/tv-account-sync", code: String = "ABCDEFGH", completionMessage: String = "oauth_login_completing".localizedString) async throws -> WKWebView {
            let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
            let web = WKWebView(frame: .zero, configuration: config)
            let fields = code.map { "<input class='otp-input' value='\($0)'>" }.joined()
            web.loadHTMLString("<html><body><div class='tv-account-sync-wrapper'>\(fields)<div class='error-container'></div><button class='tv-account-sync' onclick='window.confirmations=(window.confirmations||0)+1'>Confirm</button></div></body></html>", baseURL: URL(string: "https://\(host)/#\(route)"))
            try await wait { (try? await web.evaluateJavaScript("document.querySelectorAll('.otp-input').length")) as? Int == 8 }
            let script = try MacBrowserLogin.verificationScript(for: "ABCD-EFGH", completionMessage: completionMessage)
            _ = try await web.evaluateJavaScript(script + "; true")
            return web
        }
        let valid = try await fixture()
        let confirmed = try await valid.evaluateJavaScript("window.confirmations || 0") as? Int
        check(confirmed == 1, "Matching prefilled verification completes without a second user click")
        _ = try await valid.evaluateJavaScript("document.body.appendChild(document.createElement('span')); true")
        try await Task.sleep(nanoseconds: 350_000_000)
        let repeated = try await valid.evaluateJavaScript("window.confirmations || 0") as? Int
        check(repeated == 1, "DOM changes and timers cannot approve the same attempt twice")
        for (host, route, code) in [("attacker.invalid", "/en/tv-account-sync", "ABCDEFGH"), ("account.formula1.com", "/en/login", "ABCDEFGH"), ("account.formula1.com", "/en/tv-account-sync", "WRONGKEY")] {
            let web = try await fixture(host: host, route: route, code: code)
            let confirmations = try await web.evaluateJavaScript("window.confirmations || 0") as? Int
            check(confirmations == 0, "Verification rejects a mismatched host, route or attempt: \(host) \(route) \(code)")
        }
        let catalogURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("F1Core/Sources/F1Core/Resources/Localizable.xcstrings")
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as! [String:Any]
        let strings = catalog["strings"] as! [String:[String:Any]]
        let completing = strings["oauth_login_completing"]!["localizations"] as! [String:[String:Any]]
        for language in ["en", "de", "es", "fr", "nl", "pt-PT"] {
            let message = (completing[language]!["stringUnit"] as! [String:Any])["value"] as! String
            let web = try await fixture(completionMessage: message)
            let displayed = try await web.evaluateJavaScript("document.querySelector('[role=status]').textContent") as? String
            check(displayed == message, "Browser sign-in status renders its \(language) translation")
        }
        let quoted = "Connexion d’F1 : \"test\" \\ chemin\nTerminé…"
        let quotedWeb = try await fixture(completionMessage: quoted)
        let quotedDisplay = try await quotedWeb.evaluateJavaScript("document.querySelector('[role=status]').textContent") as? String
        check(quotedDisplay == quoted, "Quotes, backslashes and newlines in translations cannot break injected JavaScript")
        for language in ["en", "de", "es", "fr", "nl", "pt-PT"] {
            let web = try await fixture(code: "XXXXXXXX")
            let preference = try MacBrowserLogin.websiteLanguageScript(locale: Locale(identifier: language))
            _ = try await web.evaluateJavaScript(preference + "; true")
            let stored = try await web.evaluateJavaScript("localStorage.getItem('user-language')") as? String
            let expected = String(language.prefix(2))
            check(stored == "\"\(expected)\"", "F1 page receives the app's \(language) language preference")
        }
        let otherSite = try await fixture(host: "attacker.invalid", code: "XXXXXXXX")
        _ = try await otherSite.evaluateJavaScript(try MacBrowserLogin.websiteLanguageScript(locale: Locale(identifier: "de")) + "; true")
        let otherPreference = try await otherSite.evaluateJavaScript("localStorage.getItem('user-language')")
        check(otherPreference is NSNull, "F1 language preference is never written on other origins")
        let delayed = try await fixture(code: "XXXXXXXX")
        _ = try await delayed.evaluateJavaScript("document.querySelectorAll('.otp-input').forEach((field,index)=>field.value='ABCDEFGH'[index]); true")
        try await wait { (try? await delayed.evaluateJavaScript("window.confirmations || 0")) as? Int == 1 }
        check(true, "Asynchronous F1 code prefill is recognized")
        _ = try await delayed.evaluateJavaScript("document.querySelector('.error-container').textContent='Fixture error'; true")
        try await wait { (try? await delayed.evaluateJavaScript("document.querySelector('.tv-account-sync-wrapper').style.visibility")) as? String == "" }
        check(true, "F1 verification errors remain visible for recovery")

        for value in ["https://account.formula1.com/#/en/tv-account-welcome", "https://account.formula1.com/#//tv-account-welcome?source=mac"] {
            check(MacBrowserLogin.isCompletionURL(URL(string: value)!), "F1 completion route is recognized: \(value)")
        }
        for value in ["http://account.formula1.com/#/en/tv-account-welcome", "https://account.formula1.com.attacker.invalid/#/en/tv-account-welcome",
                      "https://user@account.formula1.com/#/en/tv-account-welcome", "https://account.formula1.com:8443/#/en/tv-account-welcome",
                      "https://account.formula1.com/other#/en/tv-account-welcome", "https://account.formula1.com/#/en/tv-account-sync",
                      "https://account.formula1.com/#/en/tv-account-welcome-attacker"] {
            check(!MacBrowserLogin.isCompletionURL(URL(string: value)!), "Untrusted or incomplete navigation cannot finish browser sign-in: \(value)")
        }
        let oauth = PendingOAuth(), store = MemoryOAuthStore(), client = APIClient(transport: NoAPI())
        let auth = F1OAuthAuthService(client: client, fallback: F1AuthService(client: client, endpoints: APIEndpoints(), storage: EmptyLegacyStore()), store: store, transport: oauth, wait: { _ in try Task.checkCancellation() })
        let browser = MacBrowserLogin()
        let first = Task { try await browser.signIn(using: auth) }
        try await wait { await oauth.requests >= 1 && browser.browser.configuration.userContentController.userScripts.count == 2 }
        let old = browser.browser, oldStore = old.configuration.websiteDataStore
        check(!oldStore.isPersistent, "Sign-in uses an ephemeral browser")
        check(old.configuration.userContentController.userScripts.first?.isForMainFrameOnly == true, "Automatic verification never runs in embedded frames")
        check(await oauth.requests == 1, "The Mac defers token polling until browser completion")
        old.loadHTMLString("<html><body>Approval fixture</body></html>", baseURL: URL(string: "https://account.formula1.com/#/en/tv-account-sync"))
        try await wait { (try? await old.evaluateJavaScript("document.body.textContent")) as? String == "Approval fixture" }
        // F1 changes its hash route in place, without loading a new document.
        _ = try await old.evaluateJavaScript("location.hash='/en/tv-account-welcome'; true")
        try await wait { await oauth.requests >= 2 }
        check(browser.finishing, "Completion navigation hides the finished website while tokens are saved")
        check(try await auth.account() == nil, "A completion page alone never publishes a signed-in account")
        first.cancel()
        let second = Task { try await browser.signIn(using: auth) }
        try await wait { await oauth.requests >= 3 && browser.browser !== old }
        check(browser.browser.configuration.websiteDataStore !== oldStore, "Retry isolates cookies and callbacks in a new browser")
        do { _ = try await first.value; preconditionFailure("Canceled sign-in completed") } catch { check(error is CancellationError, "A superseded attempt is canceled") }
        check(browser.browser.navigationDelegate != nil && !browser.finishing, "Late cancellation preserves the new attempt")
        old.loadHTMLString("<html>Stale completion</html>", baseURL: URL(string: "https://account.formula1.com/#/en/tv-account-welcome"))
        try await Task.sleep(nanoseconds: 100_000_000)
        check(await oauth.requests == 3 && !browser.finishing, "A previous browser's completion cannot authorize the next attempt")
        second.cancel(); browser.clear()
        do { _ = try await second.value; preconditionFailure("Canceled sign-in completed") } catch { check(error is CancellationError, "Closing sign-in cancels the browser-completion wait") }
        let fallback = Task { try await browser.signIn(using: auth, completionFallbackDelay: 0) }
        try await wait { await oauth.requests >= 5 }
        check(!browser.finishing, "Polling remains available if the completion URL is not observed")
        fallback.cancel(); browser.clear()
        do { _ = try await fallback.value; preconditionFailure("Canceled fallback completed") } catch { check(error is CancellationError, "Closing sign-in cancels fallback polling") }
        await oauth.rejectTokens()
        let rejected = Task { try await browser.signIn(using: auth) }
        try await wait { await oauth.requests >= 6 && browser.browser.configuration.userContentController.userScripts.count == 2 }
        browser.browser.loadHTMLString("<html>Completed</html>", baseURL: URL(string: "https://account.formula1.com/#/en/tv-account-welcome"))
        do { _ = try await rejected.value; preconditionFailure("Rejected exchange completed") }
        catch { check(error as? DeviceSignInError == .rejected && !browser.finishing && browser.browser.navigationDelegate == nil,
                      "A failed exchange clears the finishing indicator and preserves retry") }
        check(try await store.load() == nil, "Canceled sign-in cannot persist credentials")

        let keychain = MacOAuthSessionStore()
        try await keychain.clear()
        let profile: [String:Any] = ["firstName":"Fixture","lastName":"Account","email":"fixture@example.invalid","country":"CH","subscriberID":42,"subscriptionStatus":"active"]
        let payload: [String:Any] = ["refreshToken":"fixture-refresh","expiresAt":123,"playback":["sessionID":"fixture-session","subscriptionToken":"fixture-playback","profile":profile]]
        let stored = try JSONDecoder().decode(DeviceAccountSession.self, from: JSONSerialization.data(withJSONObject: payload))
        try await keychain.save(stored)
        let restored = try await MacOAuthSessionStore().load()
        let restoredJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(restored)) as? [String:Any]
        check(restoredJSON?["refreshToken"] as? String == "fixture-refresh" &&
              (restoredJSON?["playback"] as? [String:Any])?["subscriptionToken"] as? String == "fixture-playback",
              "OAuth credentials restore from the isolated Mac Keychain")
        try await keychain.clear()
        check(try await keychain.load() == nil, "Mac OAuth Keychain record clears on sign-out")
        print("\(count) Mac OAuth checks passed")
    }
}

import SwiftUI
import WebKit
import F1Core

@MainActor final class MacBrowserLogin: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published private(set) var browser: WKWebView
    @Published var loading = false
    @Published var error: String?
    @Published private(set) var finishing = false
    private var generation = UUID()
    private var completionObservation: NSKeyValueObservation?
    private var approval: CheckedContinuation<Void, Error>?
    private var approvalTimer: Task<Void, Never>?
    override init() {
        browser = Self.makeBrowser()
        super.init()
    }
    private static func makeBrowser() -> WKWebView {
        let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
        return WKWebView(frame: .zero, configuration: config)
    }
    /// F1's web OAuth client omits refresh tokens. Its device grant supplies them;
    /// opening verification_uri_complete locally avoids phone/code-entry steps.
    func signIn(using auth: F1OAuthAuthService, completionFallbackDelay: TimeInterval = 60) async throws -> AccountProfile {
        clear()
        let identity = generation
        browser = Self.makeBrowser()
        browser.navigationDelegate = self; browser.uiDelegate = self
        completionObservation = browser.observe(\.url, options: [.new]) { [weak self] webView, _ in
            Task { @MainActor in self?.checkCompletion(in: webView) }
        }
        error = nil; loading = true
        return try await withTaskCancellationHandler {
            do {
                let authorization = try await auth.beginSignIn()
                try Task.checkCancellation()
                guard generation == identity else { throw CancellationError() }
                let url = authorization.qrCodeURL
                let parameters = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                // Do not fall back to asking the Mac user to copy a code.
                guard parameters.contains(where: { $0.name == "user_code" && $0.value == authorization.userCode }) else {
                    throw DeviceSignInError.unavailable
                }
                let script = try Self.verificationScript(for: authorization.userCode)
                let languageScript = try Self.websiteLanguageScript()
                browser.configuration.userContentController.addUserScript(WKUserScript(source: languageScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
                browser.configuration.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
                browser.load(URLRequest(url: url))
                // A fallback preserves sign-in if F1 changes its completion URL.
                // Usually the browser signals success before any polling starts.
                try await waitForApproval(until: authorization.expiresAt, fallbackDelay: completionFallbackDelay)
                try Task.checkCancellation()
                guard generation == identity else { throw CancellationError() }
                let profile = try await auth.completeBrowserSignIn(authorization)
                try Task.checkCancellation()
                guard generation == identity else { throw CancellationError() }
                loading = false
                return profile
            } catch {
                if generation == identity {
                    loading = false; finishing = false; completionObservation = nil
                    browser.stopLoading(); browser.navigationDelegate = nil; browser.uiDelegate = nil
                }
                throw error
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self, self.generation == identity else { return }
                self.clear()
            }
        }
    }
    static func isCompletionURL(_ url: URL) -> Bool {
        guard url.scheme == "https", url.host == "account.formula1.com",
              url.port == nil || url.port == 443, url.user == nil, url.password == nil,
              url.path == "/" || url.path.isEmpty, let fragment = url.fragment else { return false }
        return fragment.range(of: #"^/(?:[a-z]{2})?/tv-account-welcome(?:\?.*)?$"#, options: .regularExpression) != nil
    }
    private func checkCompletion(in webView: WKWebView) {
        guard webView === browser, browser.navigationDelegate != nil,
              let url = webView.url, Self.isCompletionURL(url) else { return }
        finishing = true; loading = false
        finishApproval(.success(()))
    }
    private func waitForApproval(until expiry: Date, fallbackDelay: TimeInterval) async throws {
        if finishing { return }
        try Task.checkCancellation()
        let identity = generation
        try await withCheckedThrowingContinuation { continuation in
            approval = continuation
            let delay = min(max(0, fallbackDelay), max(0, expiry.timeIntervalSinceNow))
            approvalTimer = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) } catch { return }
                guard let self, self.generation == identity else { return }
                self.finishApproval(expiry > Date() ? .success(()) : .failure(DeviceSignInError.expired))
            }
        }
    }
    private func finishApproval(_ result: Result<Void, Error>) {
        let continuation = approval; approval = nil
        approvalTimer?.cancel(); approvalTimer = nil
        continuation?.resume(with: result)
    }
    static func websiteLanguageScript(locale: Locale = CoreLocalization.locale) throws -> String {
        let language = locale.language.languageCode?.identifier ?? "en"
        let supported = ["en", "de", "es", "fr", "nl", "pt"]
        let encoded = String(data: try JSONSerialization.data(withJSONObject: [supported.contains(language) ? language : "en"]), encoding: .utf8)!
        // F1 reads this JSON preference before initializing its account routes.
        // The preference exists only in this attempt's ephemeral website store.
        return """
        (() => {
          if (location.protocol !== 'https:' || location.hostname !== 'account.formula1.com') return;
          try { localStorage.setItem('user-language', JSON.stringify(\(encoded)[0])); } catch (_) {}
        })();
        """
    }
    /// Complete only the prefilled verification belonging to this sign-in. F1
    /// still owns credential entry and authorization; no passwords or website
    /// tokens are read. Its web client cannot issue refresh credentials itself.
    static func verificationScript(for code: String, completionMessage: String = "oauth_login_completing".localizedString) throws -> String {
        let encoded = String(data: try JSONSerialization.data(withJSONObject: [code, completionMessage]), encoding: .utf8)!
        return """
        (() => {
          if (location.protocol !== 'https:' || location.hostname !== 'account.formula1.com') return;
          const values = \(encoded);
          const expected = values[0].replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
          let attempted = false;
          const attempt = () => {
            if (attempted || !/^#\\/(?:[a-z]{2})?\\/tv-account-sync(?:[?/]|$)/.test(location.hash)) return;
            const form = document.querySelector('.tv-account-sync-wrapper');
            const fields = form && Array.from(form.querySelectorAll('.otp-input'));
            const button = form && form.querySelector('.tv-account-sync');
            if (!fields || fields.length !== 8 || fields.map(field => field.value).join('').toUpperCase() !== expected ||
                !button || button.disabled || button.getAttribute('aria-disabled') === 'true') return;
            attempted = true;
            button.click();
            const status = document.createElement('p');
            status.textContent = values[1];
            status.setAttribute('role', 'status');
            status.style.visibility = 'visible';
            form.style.visibility = 'hidden';
            form.appendChild(status);
            const restore = () => { form.style.visibility = ''; status.remove(); };
            const errors = new MutationObserver(() => {
              const error = form.querySelector('.error-container');
              if (error && error.textContent.trim()) { restore(); errors.disconnect(); }
            });
            errors.observe(form, { childList: true, subtree: true, characterData: true });
            setTimeout(() => { restore(); errors.disconnect(); }, 15000);
          };
          const observer = new MutationObserver(attempt);
          observer.observe(document.documentElement, { childList: true, subtree: true });
          addEventListener('hashchange', attempt);
          const timer = setInterval(attempt, 250);
          setTimeout(() => { clearInterval(timer); observer.disconnect(); removeEventListener('hashchange', attempt); }, 600000);
          attempt();
        })();
        """
    }
    func clear() {
        generation = UUID(); loading = false; finishing = false
        completionObservation = nil; finishApproval(.failure(CancellationError()))
        browser.stopLoading(); browser.navigationDelegate = nil; browser.uiDelegate = nil
        browser.loadHTMLString("", baseURL: nil)
        // Each attempt gets a new nonpersistent data store. A late cancellation
        // or website-data cleanup cannot alter the next attempt's browser.
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard webView === browser else { return }; loading = true; error = nil
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === browser else { return }; loading = false; checkCompletion(in: webView)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(webView, error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(webView, error) }
    private func failed(_ webView: WKWebView, _ failure: Error) {
        guard webView === browser, (failure as NSError).code != NSURLErrorCancelled else { return }
        loading = false; error = "oauth_login_page_failed".localizedString
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard webView === browser, let url = action.request.url else { decisionHandler(.cancel); return }
        decisionHandler(url.scheme == "https" || url.scheme == "about" ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if webView === browser, action.targetFrame == nil, action.request.url?.scheme == "https" { webView.load(action.request) }
        return nil
    }
}

struct LoginBrowserSurface: NSViewRepresentable {
    let browser: WKWebView
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        guard view.subviews.first !== browser else { return }
        view.subviews.forEach { $0.removeFromSuperview() }
        browser.frame = view.bounds; browser.autoresizingMask = [.width, .height]
        view.addSubview(browser)
    }
}
struct BrowserSignInSheet: View {
    @ObservedObject var provider: MacBrowserLogin
    let cancel: () -> Void
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("oauth_login_button".localizedString).font(.headline)
                    Text(provider.browser.url?.host ?? "account.formula1.com").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("action_reload".localizedString, systemImage: "arrow.clockwise") { retry() }.labelStyle(.iconOnly)
                Button("action_cancel".localizedString, action: cancel).keyboardShortcut(.cancelAction)
            }.padding(16)
            if let error = provider.error {
                HStack { Text(error).font(.callout); Spacer(); Button("action_retry".localizedString) { retry() } }.padding(12).background(.thinMaterial)
            }
            if provider.finishing {
                LoadingStatus(title: "oauth_login_finishing".localizedString).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LoginBrowserSurface(browser: provider.browser).overlay(alignment: .top) {
                    if provider.loading { LoadingStatus(title: "oauth_login_loading".localizedString).padding(16) }
                }
            }
        }.frame(width: 720, height: 680)
    }
}

import SwiftUI
import WebKit
import F1Core

@MainActor final class MacBrowserLogin: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let browser: WKWebView
    @Published var loading = false
    @Published var error: String?
    private static let loginURL = URL(string: "https://account.formula1.com/#/login")!
    override init() {
        let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
        browser = WKWebView(frame: .zero, configuration: config)
        super.init(); browser.navigationDelegate = self; browser.uiDelegate = self
    }
    func reload() { error = nil; browser.load(URLRequest(url: Self.loginURL)) }
    func signIn() async throws -> BrowserAccountSession {
        reload()
        defer { browser.stopLoading() }
        for _ in 0..<600 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try Task.checkCancellation()
            // Only consume the provider's completed session in its own main origin.
            // Password fields, cookies and network requests are never intercepted.
            guard browser.url?.scheme == "https", browser.url?.host == "account.formula1.com" else { continue }
            if let json = try? await browser.evaluateJavaScript("localStorage.getItem('ascSessionInfo')") as? String,
               let data = json.data(using: .utf8), let session = try? BrowserAccountSession.decode(data) {
                try Task.checkCancellation(); return session
            }
        }
        error = "Sign-in timed out. Retry to start again."
        throw URLError(.timedOut)
    }
    func clear() {
        browser.stopLoading()
        let store = browser.configuration.websiteDataStore
        store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {}
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { loading = true; error = nil }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loading = false }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }
    private func failed(_ failure: Error) {
        loading = false
        guard (failure as NSError).code != NSURLErrorCancelled else { return }
        error = "The sign-in page could not load. Check your connection and retry."
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = action.request.url?.scheme
        decisionHandler(scheme == "https" || scheme == "about" ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.targetFrame == nil, action.request.url?.scheme == "https" { webView.load(action.request) }
        return nil
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
                    Text("Sign In with F1").font(.headline)
                    Text(provider.browser.url?.host ?? "account.formula1.com").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Reload", systemImage: "arrow.clockwise") { retry() }.labelStyle(.iconOnly)
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
            }.padding(16)
            if let error = provider.error {
                HStack { Text(error).font(.callout); Spacer(); Button("Retry") { retry() } }.padding(12).background(.thinMaterial)
            }
            LoginBrowserSurface(browser: provider.browser).overlay(alignment: .top) {
                if provider.loading { LoadingStatus(title: "Loading sign-in…").padding(16) }
            }
        }.frame(width: 720, height: 680)
    }
}

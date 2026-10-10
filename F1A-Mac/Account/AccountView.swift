import SwiftUI
import WebKit
import F1Core

struct LoginBrowserSurface: NSViewRepresentable {
    let browser: WKWebView
    func makeNSView(context: Context) -> WKWebView { browser }
    func updateNSView(_ view: WKWebView, context: Context) {}
}
struct AccountView: View {
    let services: MacServices
    @ObservedObject var session: DesktopSession
    @StateObject private var provider = MacLoginChallenge()
    @StateObject private var browserLogin = MacBrowserLogin()
    @State private var showingBrowser = false
    @State private var profile: AccountProfile?
    @State private var email = ""
    @State private var password = ""
    @State private var challenge: LoginChallenge?
    @State private var status = ""
    @State private var working = false
    @State private var task: Task<Void, Never>?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Account").font(.largeTitle.bold())
                if let profile {
                    Text([profile.firstName, profile.lastName].joined(separator: " ")).font(.title2)
                    Text(profile.email)
                    LabeledContent("Subscription", value: profile.subscriptionStatus.isEmpty ? "Unknown" : profile.subscriptionStatus)
                    LabeledContent("Country", value: Locale.current.localizedString(forRegionCode: profile.country) ?? profile.country)
                    LabeledContent("Account ID", value: String(profile.subscriberID))
                    Button("Sign Out") {
                        working = true; session.closeAll()
                        task = Task { @MainActor in
                            do { try await services.auth.signOut(); self.profile = nil; challenge = nil; status = "Signed out." }
                            catch { recordServiceFailure(error, operation: .logout); status = "Could not complete sign-out. Please retry." }
                            working = false
                        }
                    }.disabled(working)
                } else {
                    Text("Use your F1 TV account to sign in.").foregroundStyle(.secondary)
                    Button("Sign In with F1", systemImage: "globe") { signInWithBrowser() }
                        .buttonStyle(.glassProminent).tint(.red).disabled(working)
                    Text("Sign in on the official F1 account page in a browser sheet.").font(.callout).foregroundStyle(.secondary)
                    DisclosureGroup("Use email and password instead") {
                        VStack(alignment: .leading, spacing: 14) {
                            TextField("Email", text: $email).textContentType(.username).textFieldStyle(.roundedBorder)
                            SecureField("Password", text: $password).textContentType(.password).textFieldStyle(.roundedBorder)
                            HStack {
                                Button("Sign In") { signIn() }.disabled(working || challenge == nil || email.isEmpty || password.isEmpty).buttonStyle(.glassProminent).tint(.red)
                                Button(challenge == nil ? "Prepare Sign-In" : "Retry Preparation") { prepare() }.disabled(working)
                            }
                            if provider.needsInteraction {
                                Text("Complete the browser check below, then return to Sign In.").font(.callout)
                                LoginBrowserSurface(browser: provider.browser).frame(height: 440).clipShape(.rect(cornerRadius: 12))
                            }
                        }.padding(.top, 12)
                    }
                }
                if working && !showingBrowser { LoadingStatus(title: "Updating account…") }
                if !status.isEmpty { Text(status).foregroundStyle(.secondary).textSelection(.enabled) }
                Text("disclaimer".localizedString).font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: 650, alignment: .leading).padding(32).frame(maxWidth: .infinity, alignment: .leading)
        }.task { await refresh() }
        .sheet(isPresented: $showingBrowser, onDismiss: cancelBrowser) {
            BrowserSignInSheet(provider: browserLogin, cancel: cancelBrowser, retry: signInWithBrowser)
        }
        .onDisappear { browserLogin.clear(); task?.cancel(); task = nil; working = false; password = ""; challenge = nil; provider.browser.stopLoading() }
    }
    private func cancelBrowser() {
        if showingBrowser || working { task?.cancel(); task = nil; working = false }
        showingBrowser = false; browserLogin.clear()
    }
    private func signInWithBrowser() {
        task?.cancel(); working = true; showingBrowser = true; status = ""
        task = Task { @MainActor in
            do {
                let value = try await browserLogin.signIn()
                try Task.checkCancellation()
                profile = try await services.auth.accept(value)
                working = false; showingBrowser = false; password = ""; challenge = nil; status = "Signed in."
            } catch {
                guard !Task.isCancelled else { return }
                recordServiceFailure(error, operation: .login)
                working = false; status = "Could not complete browser sign-in. Retry or use the email and password option."
                browserLogin.error = status
            }
        }
    }
    private func refresh() async {
        do { profile = try await services.auth.account(); if let profile { email = profile.email } }
        catch { recordServiceFailure(error, operation: .credentials); status = "Could not read account storage. Retry after checking Keychain access." }
    }
    private func prepare() {
        task?.cancel(); challenge = nil; status = "Preparing sign-in…"
        task = Task { @MainActor in
            do { let value = try await services.auth.prepareLogin(using: provider); try Task.checkCancellation(); challenge = value; status = "Ready to sign in." }
            catch { guard !Task.isCancelled else { return }; recordServiceFailure(error, operation: .login); status = "Could not prepare sign-in. Please retry." }
        }
    }
    private func signIn() {
        guard let challenge else { return }
        task?.cancel(); working = true; status = "Signing in…"
        let submittedPassword = password
        task = Task { @MainActor in
            do { profile = try await services.auth.signIn(email: email, password: submittedPassword, challenge: challenge); try Task.checkCancellation(); password = ""; status = "Signed in."; self.challenge = nil }
            catch { guard !Task.isCancelled else { return }; recordServiceFailure(error, operation: .login); status = "Could not sign in. Check your details and retry preparation."; self.challenge = nil }
            working = false
        }
    }
}

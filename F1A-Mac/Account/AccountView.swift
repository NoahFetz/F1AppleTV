import SwiftUI
import F1Core

struct AccountView: View {
    let services: MacServices
    @ObservedObject var session: DesktopSession
    @StateObject private var browserLogin = MacBrowserLogin()
    @State private var showingBrowser = false
    @State private var profile: AccountProfile?
    @State private var hasOAuthSession = false
    @State private var status = ""
    @State private var working = false
    @State private var task: Task<Void, Never>?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("account_title".localizedString).font(.largeTitle.bold())
                if let profile {
                    Text([profile.firstName, profile.lastName].joined(separator: " ")).font(.title2)
                    if !profile.email.isEmpty { Text(profile.email) }
                    LabeledContent("account_subscription_title".localizedString, value: profile.localizedSubscriptionStatus)
                    if !profile.country.isEmpty { LabeledContent("account_country_title".localizedString, value: CoreLocalization.locale.localizedString(forRegionCode: profile.country) ?? profile.country) }
                    LabeledContent("account_id_title".localizedString, value: String(profile.subscriberID))
                    if !hasOAuthSession {
                        Text("account_renewal_sign_in_prompt".localizedString).font(.callout).foregroundStyle(.secondary)
                        Button("oauth_login_button".localizedString, systemImage: "globe") { signInWithBrowser() }
                            .buttonStyle(.glassProminent).tint(.red).disabled(working)
                    }
                    Button("logout_button_title".localizedString) {
                        working = true; session.closeAll()
                        task = Task { @MainActor in
                            do { try await services.auth.signOut(); self.profile = nil; hasOAuthSession = false; status = "account_signed_out".localizedString }
                            catch { recordServiceFailure(error, operation: .logout); status = "account_sign_out_failed".localizedString }
                            working = false
                        }
                    }.disabled(working)
                } else {
                    Text("account_sign_in_prompt".localizedString).foregroundStyle(.secondary)
                    Button("oauth_login_button".localizedString, systemImage: "globe") { signInWithBrowser() }
                        .buttonStyle(.glassProminent).tint(.red).disabled(working)
                    Text("account_browser_sign_in_explanation".localizedString).font(.callout).foregroundStyle(.secondary)
                }
                if working && !showingBrowser { LoadingStatus(title: "account_updating".localizedString) }
                if !status.isEmpty { Text(status).foregroundStyle(.secondary).textSelection(.enabled) }
                Text("disclaimer".localizedString).font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: 650, alignment: .leading).padding(32).frame(maxWidth: .infinity, alignment: .leading)
        }.task { await refresh() }
        .sheet(isPresented: $showingBrowser, onDismiss: cancelBrowser) {
            BrowserSignInSheet(provider: browserLogin, cancel: cancelBrowser, retry: signInWithBrowser)
        }
        .onDisappear { task?.cancel(); task = nil; browserLogin.clear(); working = false }
    }
    private func cancelBrowser() {
        if showingBrowser || working { task?.cancel(); task = nil; working = false }
        showingBrowser = false; browserLogin.clear()
    }
    private func signInWithBrowser() {
        task?.cancel(); working = true; showingBrowser = true; status = ""
        task = Task { @MainActor in
            do {
                profile = try await browserLogin.signIn(using: services.auth)
                try Task.checkCancellation()
                hasOAuthSession = true; working = false; showingBrowser = false; status = "device_login_success".localizedString
            } catch {
                guard !Task.isCancelled else { return }
                recordServiceFailure(error, operation: .login)
                working = false; status = "oauth_login_failed".localizedString
                browserLogin.error = status
            }
        }
    }
    private func refresh() async {
        do { profile = try await services.auth.account(); hasOAuthSession = try await services.auth.hasOAuthSession() }
        catch { recordServiceFailure(error, operation: .credentials); status = "account_storage_failed".localizedString }
    }
}

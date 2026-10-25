#if canImport(F1Core)
import F1Core
#endif
import UIKit

final class AccountOverviewViewController: UIViewController {
    private var stack: UIStackView!
    private var status: UILabel!
    private var action: TVActionButton!
    private var isWorking = false
    private var loadFailed = false
    var services: AppServices!
    private var profile: AccountProfile?
    private var accountTask: Task<Void, Never>?
    override func viewDidLoad() {
        super.viewDidLoad()
        stack = TVDesign.stack(in: view, title: "account_title".localizedString)
        render()
    }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); if stack != nil { refreshAccount() } }
    private func render() {
        while stack.arrangedSubviews.count > 1 { stack.arrangedSubviews.last?.removeFromSuperview() }
        let signedIn = profile != nil
        if signedIn {
            let info = profile!
            stack.addArrangedSubview(TVDesign.label(info.firstName + " " + info.lastName, size: 36, bold: true))
            if !info.email.isEmpty { stack.addArrangedSubview(TVDesign.label(info.email)) }
            stack.addArrangedSubview(TVDesign.label("account_subscription_title".localizedString + " · " + info.localizedSubscriptionStatus))
            if !info.country.isEmpty { stack.addArrangedSubview(TVDesign.label("account_country_title".localizedString + " · " + (CoreLocalization.locale.localizedString(forRegionCode: info.country) ?? info.country))) }
            stack.addArrangedSubview(TVDesign.label("account_id_title".localizedString + " · " + String(info.subscriberID), size: 23))
        } else { stack.addArrangedSubview(TVDesign.label("account_subscription_sign_in_prompt".localizedString)) }
        status = TVDesign.label("", size: 24)
        stack.addArrangedSubview(status)
        action = TVDesign.button((loadFailed ? "action_retry" : signedIn ? "logout_button_title" : "login_button_title").localizedString) { [weak self] in
            guard let self, !self.isWorking else { return }
            if self.loadFailed { self.refreshAccount() }
            else if signedIn { self.logoutPressed() }
            else { self.presentFullscreen(viewController: self.services.loginController()) }
        }
        stack.addArrangedSubview(action)
        if loadFailed {
            stack.addArrangedSubview(TVDesign.button("login_button_title".localizedString) { [weak self] in
                guard let self else { return }; self.presentFullscreen(viewController: self.services.loginController())
            })
        }
    }
    private func refreshAccount() {
        accountTask?.cancel(); let auth = services.auth
        accountTask = Task { [weak self] in
            do { let profile = try await auth.account(); try Task.checkCancellation(); self?.profile = profile; self?.loadFailed = false; self?.render() }
            catch { guard !Task.isCancelled, !(error is CancellationError) else { return }; recordServiceFailure(error, operation: .credentials); self?.loadFailed = true; self?.render(); self?.status.text = "account_load_failed".localizedString }
        }
    }
    private func logoutPressed() {
        isWorking = true; action.isEnabled = false; status.text = "account_signing_out".localizedString
        accountTask?.cancel(); let auth = services.auth
        accountTask = Task { [weak self] in
            do {
                try await auth.signOut(); try Task.checkCancellation()
                self?.profile = nil; self?.isWorking = false; self?.render()
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                recordServiceFailure(error, operation: .logout)
                self?.isWorking = false; self?.action.isEnabled = true
                self?.status.text = "account_sign_out_failed".localizedString
            }
        }
    }
    deinit { accountTask?.cancel() }
}

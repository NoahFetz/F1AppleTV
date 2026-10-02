//
//  LoginViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit

/// Keep tvOS's native field surface without an additional rectangle behind its bezel.
private final class LoginTextField: UITextField {
    override init(frame: CGRect) {
        super.init(frame: frame)
        borderStyle = .none
        background = nil; disabledBackground = nil
        backgroundColor = .clear
        font = .systemFont(ofSize: 32)
        updateAppearance()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func textRect(forBounds bounds: CGRect) -> CGRect { bounds.insetBy(dx: 24, dy: 14) }
    override func editingRect(forBounds bounds: CGRect) -> CGRect { textRect(forBounds: bounds) }
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect { textRect(forBounds: bounds) }
    func updateAppearance() {
        textColor = isFocused ? .black : .white
        tintColor = textColor
        attributedPlaceholder = NSAttributedString(string: placeholder ?? "", attributes: [
            .foregroundColor: (isFocused ? UIColor.black : UIColor.white).withAlphaComponent(0.55)
        ])
    }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations { self.updateAppearance() }
    }
}

class LoginViewController: BaseViewController {
    private let emailTextField = LoginTextField()
    private let passwordTextField = LoginTextField()
    private var loginButton: TVActionButton!
    private var status: UILabel!
    var services: AppServices!
    private var preparationTask: Task<Void, Never>?
    private var loginTask: Task<Void, Never>?
    private var challenge: LoginChallenge?
    private var working = false

    override var preferredFocusEnvironments: [UIFocusEnvironment] { [emailTextField] }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ConstantsUtil.brandingBackgroundColor
        let stack = TVDesign.stack(in: view, title: "login_title".localizedString)
        stack.addArrangedSubview(TVDesign.label("Use your F1 TV account to sign in."))
        for (title, field) in [("login_email_title", emailTextField), ("login_password_title", passwordTextField)] {
            stack.addArrangedSubview(TVDesign.label(title.localizedString, size: 24))
            field.accessibilityLabel = title.localizedString
            field.placeholder = title.localizedString
            field.updateAppearance()
            field.heightAnchor.constraint(equalToConstant: 80).isActive = true
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            stack.addArrangedSubview(field)
        }
        emailTextField.keyboardType = .emailAddress
        emailTextField.textContentType = .username
        let auth = services.auth
        Task { [weak self] in
            do { let profile = try await auth.account(); if self?.emailTextField.text?.isEmpty != false { self?.emailTextField.text = profile?.email } }
            catch { recordServiceFailure(error, operation: .credentials) }
        }
        passwordTextField.isSecureTextEntry = true
        passwordTextField.textContentType = .password
        status = TVDesign.label("Preparing sign-in…", size: 24)
        stack.addArrangedSubview(status)
        loginButton = TVDesign.button("login_button_title".localizedString) { [weak self] in self?.loginButtonPressed() }
        loginButton.isEnabled = false
        stack.addArrangedSubview(loginButton)
        stack.addArrangedSubview(TVDesign.button("Retry sign-in preparation") { [weak self] in self?.fetchCookieFromBrowserWindow() })
        stack.addArrangedSubview(TVDesign.button("Cancel") { [weak self] in self?.dismiss(animated: true) })
        fetchCookieFromBrowserWindow()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        preparationTask?.cancel(); loginTask?.cancel(); challenge = nil; passwordTextField.text = ""
    }
    func fetchCookieFromBrowserWindow() {
        guard !working else { return }
        preparationTask?.cancel(); challenge = nil
        loginButton.isEnabled = false; status.text = "Preparing sign-in…"
        let provider = BrowserLoginChallengeProvider(host: view), auth = services.auth
        preparationTask = Task { [weak self] in
            do {
                let value = try await auth.prepareLogin(using: provider)
                try Task.checkCancellation()
                self?.challenge = value; self?.status.text = "Ready to sign in"; self?.loginButton.isEnabled = true
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                recordServiceFailure(error, operation: .login)
                self?.status.text = "Could not prepare sign-in. Please retry."
            }
        }
    }
    @objc func loginButtonPressed() {
        guard !working else { return }
        guard let challenge else { status.text = "Sign-in is still being prepared. Please retry."; return }
        let email = emailTextField.text ?? "", password = passwordTextField.text ?? ""
        guard !email.isEmpty, !password.isEmpty else { status.text = "Enter your email and password."; return }
        working = true; loginButton.isEnabled = false; status.text = "Signing in…"
        let auth = services.auth
        loginTask = Task { [weak self] in
            do {
                _ = try await auth.signIn(email: email, password: password, challenge: challenge)
                try Task.checkCancellation()
                self?.working = false; self?.dismiss(animated: true)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                recordServiceFailure(error, operation: .login)
                self?.working = false; self?.loginButton.isEnabled = true
                self?.status.text = "Could not sign in. Check your details and try again."
            }
        }
    }
    deinit { preparationTask?.cancel(); loginTask?.cancel() }
}

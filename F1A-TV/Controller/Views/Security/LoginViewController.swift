#if canImport(F1Core)
import F1Core
#endif
import UIKit
import CoreImage

final class LoginViewController: BaseViewController {
    var services: AppServices!
    private var signInTask: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var generation = UUID()
    private var authorization: DeviceAuthorization?
    private var status: UILabel!
    private var code: UILabel!
    private var address: UILabel!
    private var expiry: UILabel!
    private var qrImage: UIImageView!
    private var retryButton: TVActionButton!
    private var cancelButton: TVActionButton!

    override var preferredFocusEnvironments: [UIFocusEnvironment] { [cancelButton].compactMap { $0 } }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ConstantsUtil.brandingBackgroundColor
        let stack = TVDesign.stack(in: view, title: "login_title".localizedString)
        stack.addArrangedSubview(TVDesign.label("device_login_instructions".localizedString))

        let row = UIStackView(); row.axis = .horizontal; row.spacing = 48; row.alignment = .center
        let qrBackground = UIView(); qrBackground.backgroundColor = .white; qrBackground.layer.cornerRadius = 16
        qrImage = UIImageView(); qrImage.translatesAutoresizingMaskIntoConstraints = false
        qrImage.contentMode = .scaleAspectFit; qrImage.layer.magnificationFilter = .nearest
        qrImage.isAccessibilityElement = false
        qrBackground.addSubview(qrImage)
        NSLayoutConstraint.activate([
            qrBackground.widthAnchor.constraint(equalToConstant: 320), qrBackground.heightAnchor.constraint(equalToConstant: 320),
            qrImage.leadingAnchor.constraint(equalTo: qrBackground.leadingAnchor, constant: 24),
            qrImage.trailingAnchor.constraint(equalTo: qrBackground.trailingAnchor, constant: -24),
            qrImage.topAnchor.constraint(equalTo: qrBackground.topAnchor, constant: 24),
            qrImage.bottomAnchor.constraint(equalTo: qrBackground.bottomAnchor, constant: -24)
        ])
        row.addArrangedSubview(qrBackground)
        let details = UIStackView(); details.axis = .vertical; details.spacing = 18
        address = TVDesign.label("", size: 34, bold: true)
        code = TVDesign.label("", size: 60, bold: true)
        code.font = .monospacedSystemFont(ofSize: 60, weight: .semibold)
        code.accessibilityIdentifier = "device-login-code"
        expiry = TVDesign.label("", size: 24)
        [address!, code!, expiry!].forEach { details.addArrangedSubview($0) }
        row.addArrangedSubview(details); stack.addArrangedSubview(row)
        status = TVDesign.label("", size: 24); status.accessibilityIdentifier = "device-login-status"
        stack.addArrangedSubview(status)
        retryButton = TVDesign.button("device_login_new_code".localizedString) { [weak self] in self?.startSignIn() }
        cancelButton = TVDesign.button("action_cancel".localizedString) { [weak self] in self?.cancelSignIn(); self?.dismiss(animated: true) }
        stack.addArrangedSubview(retryButton); stack.addArrangedSubview(cancelButton)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if signInTask == nil { startSignIn() }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelSignIn()
    }
    private func cancelSignIn() {
        generation = UUID()
        signInTask?.cancel(); signInTask = nil
        expiryTask?.cancel(); expiryTask = nil
        authorization = nil; qrImage?.image = nil; code?.text = ""; address?.text = ""; expiry?.text = ""
    }
    private func startSignIn() {
        cancelSignIn()
        let identity = generation
        status.text = "device_login_preparing".localizedString
        retryButton.isEnabled = false
        guard let provider = services.auth as? any DeviceSignInService else {
            showFailure(DeviceSignInError.unavailable); return
        }
        signInTask = Task { [weak self] in
            do {
                let value = try await provider.beginSignIn()
                try Task.checkCancellation()
                guard let self, self.generation == identity else { return }
                self.authorization = value
                self.address.text = value.verificationURL.absoluteString
                self.code.text = value.userCode
                self.code.accessibilityLabel = value.userCode.map(String.init).joined(separator: " ")
                self.qrImage.image = self.makeQRCode(value.qrCodeURL)
                self.status.text = "device_login_waiting".localizedString
                self.retryButton.isEnabled = true
                self.startExpiryTimer(value.expiresAt, identity: identity)
                _ = try await provider.completeSignIn(value)
                try Task.checkCancellation()
                guard self.generation == identity else { return }
                self.expiryTask?.cancel(); self.expiryTask = nil
                self.status.text = "device_login_success".localizedString
                self.dismiss(animated: true)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError), self?.generation == identity else { return }
                self?.showFailure(error)
            }
        }
    }
    private func showFailure(_ error: Error) {
        recordServiceFailure(error, operation: .login)
        expiryTask?.cancel(); expiryTask = nil; authorization = nil
        qrImage.image = nil; code.text = ""; address.text = ""; expiry.text = ""
        switch error as? DeviceSignInError {
        case .expired: status.text = "device_login_expired".localizedString
        case .denied: status.text = "device_login_denied".localizedString
        default: status.text = "device_login_failed".localizedString
        }
        retryButton.isEnabled = true
        setNeedsFocusUpdate(); updateFocusIfNeeded()
    }
    private func startExpiryTimer(_ deadline: Date, identity: UUID) {
        expiryTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.generation == identity else { return }
                let remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
                self.expiry.text = String(format: "device_login_expires".localizedString, String(format: "%d:%02d", remaining / 60, remaining % 60))
                if remaining == 0 { return }
                do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
            }
        }
    }
    private func makeQRCode(_ url: URL) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(url.absoluteString.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let image = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let bitmap = CIContext().createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: bitmap)
    }
    deinit { signInTask?.cancel(); expiryTask?.cancel() }
}

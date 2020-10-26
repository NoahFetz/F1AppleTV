//
//  LoginViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit

class LoginViewController: UIViewController {

    @IBOutlet weak var loginTitleLabel: UILabel!
    @IBOutlet weak var emailTitleLabel: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTitleLabel: UILabel!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupView()
    }
    
    func setupView() {
        self.loginTitleLabel.text = NSLocalizedString("login_title", comment: "")
        self.emailTitleLabel.text = NSLocalizedString("login_email_title", comment: "")
        self.passwordTitleLabel.text = NSLocalizedString("login_password_title", comment: "")
        self.loginButton.setTitle(NSLocalizedString("login_button_title", comment: ""), for: .normal)
        self.loginButton.addTarget(self, action: #selector(self.loginButtonPressed), for: .primaryActionTriggered)
        
        self.emailTextField.text = CredentialHelper.getUserInfo().subscriber.email
        self.passwordTextField.text = CredentialHelper.getPassword()
    }
    
    @objc func loginButtonPressed() {
        let authObject = AuthRequestDto(login: self.emailTextField.text ?? "", password: self.passwordTextField.text ?? "")
        print("Login pressed with: " + authObject.login + " and " + authObject.password)
        
        self.performAuthRequest(authRequest: authObject)
    }
    
    func performAuthRequest(authRequest: AuthRequestDto) {
        NetworkRouter.instance.authRequest(authRequest: authRequest, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                    self.showAlert(title: NSLocalizedString("error", comment: ""), message: NSLocalizedString("login_failed", comment: ""))
                case .success(let requestResult):
                    let tokenRequest = TokenRequestDto(accessToken: requestResult.authData.subscriptionToken, identityProviderUrl: ConstantsUtil.identityProvider)
                    CredentialHelper.setUserInfo(userInfo: requestResult)
                    CredentialHelper.setPassword(password: authRequest.password)
                    self.performTokenRequest(tokenRequest: tokenRequest)
                }
            }
        })
    }
    
    func performTokenRequest(tokenRequest: TokenRequestDto) {
        NetworkRouter.instance.tokenRequest(tokenRequest: tokenRequest, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                    self.showAlert(title: NSLocalizedString("error", comment: ""), message: NSLocalizedString("login_failed", comment: ""))
                case .success(let requestResult):
                    print(requestResult.token)
                    CredentialHelper.setJWTToken(jwtToken: requestResult.token)
                    self.presentFullscreen(viewIdentifier: ConstantsUtil.mainNavigationController)
                }
            }
        })
    }
    
    func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("close", comment: ""), style: .cancel, handler: { (UIAlertAction) in
            print("Cancelled")
        }))
        
        self.present(alertController, animated: true)
    }
}

//
//  LoginViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit

class LoginViewController: BaseViewController, AuthDataLoadedProtocol {
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
        self.loginTitleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 100)
        self.emailTitleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 40)
        self.passwordTitleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 40)
        self.emailTextField.font = UIFont(name: "Titillium-Regular", size: 38)
        self.passwordTextField.font = UIFont(name: "Titillium-Regular", size: 38)
        
        self.loginTitleLabel.text = NSLocalizedString("login_title", comment: "")
        self.emailTitleLabel.text = NSLocalizedString("login_email_title", comment: "")
        self.passwordTitleLabel.text = NSLocalizedString("login_password_title", comment: "")
        self.loginButton.setTitle(NSLocalizedString("login_button_title", comment: ""), for: .normal)
        self.loginButton.addTarget(self, action: #selector(self.loginButtonPressed), for: .primaryActionTriggered)
        
        self.emailTextField.text = CredentialHelper.instance.getUserInfo().subscriber.email
        self.passwordTextField.text = CredentialHelper.instance.getPassword()
    }
    
    @objc func loginButtonPressed() {
        let authObject = AuthRequestDto(login: self.emailTextField.text ?? "", password: self.passwordTextField.text ?? "")
        print("Login pressed with: " + authObject.login + " and " + authObject.password)
        
        DataManager.instance.loadAuthData(authRequest: authObject, authDataLoadedProtocol: self)
    }
    
    func didLoadAuthData(authResult: AuthResultDto) {
        let tokenRequest = TokenRequestDto(accessToken: authResult.authData.subscriptionToken, identityProviderUrl: ConstantsUtil.identityProvider)
        CredentialHelper.instance.setUserInfo(userInfo: authResult)
        CredentialHelper.instance.setPassword(password: self.passwordTextField.text ?? "")
        
        DataManager.instance.loadTokenRequest(tokenRequest: tokenRequest, authDataLoadedProtocol: self)
    }
    
    func didLoadToken(tokenResult: TokenResultDto) {
        CredentialHelper.instance.setJWTToken(jwtToken: tokenResult.token)
        self.dismiss(animated: true)
    }
}

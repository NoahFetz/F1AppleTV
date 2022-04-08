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
        
        self.loginTitleLabel.text = "login_title".localizedString
        self.emailTitleLabel.text = "login_email_title".localizedString
        self.passwordTitleLabel.text = "login_password_title".localizedString
        self.loginButton.setTitle("login_button_title".localizedString, for: .normal)
        self.loginButton.addTarget(self, action: #selector(self.loginButtonPressed), for: .primaryActionTriggered)
        
        self.emailTextField.text = CredentialHelper.instance.getUserInfo().subscriber.email
        self.passwordTextField.text = CredentialHelper.instance.getPassword()
        
        DataManager.instance.solveLoginChallenge()
    }
    
    @objc func loginButtonPressed() {
        let authObject = AuthRequestDto(login: self.emailTextField.text ?? "", password: self.passwordTextField.text ?? "")
        //print("Login pressed with: " + authObject.login + " and " + authObject.password)
        
        DataManager.instance.loadAuthData(authRequest: authObject, authDataLoadedProtocol: self)
    }
    
    func didLoadAuthData(authResult: AuthResultDto) {
        CredentialHelper.instance.setUserInfo(userInfo: authResult)
        CredentialHelper.instance.setPassword(password: self.passwordTextField.text ?? "")
        self.dismiss(animated: true)
    }
}

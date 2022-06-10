//
//  LoginViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit

class LoginViewController: BaseViewController, AuthDataLoadedProtocol, DeviceRegistrationLoadedProtocol {
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
        
        self.emailTextField.text = CredentialHelper.instance.getDeviceRegistration().sessionSummary.email
        self.passwordTextField.text = ""
        
        //DataManager.instance.solveLoginChallenge()
        self.fetchCookieFromBrowserWindow()
    }
    
    func fetchCookieFromBrowserWindow() {
        let webViewClassType : AnyObject.Type = NSClassFromString("UIWebView")!
        let webViewObject : NSObject.Type = webViewClassType as! NSObject.Type
        let tempWebview: AnyObject = webViewObject.init()
        let url = URL(string: "https://account.formula1.com/#/login")
        let request = URLRequest(url: url!)
        tempWebview.loadRequest(request)
        let uiview = tempWebview as! UIView
        uiview.frame = CGRectMake(0, 0, self.view.frame.width, self.view.frame.height)
        uiview.alpha = 0
        self.view.addSubview(uiview)
        
        let seconds = 5.0
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            uiview.removeFromSuperview()
            guard let cookies = HTTPCookieStorage.shared.cookies else {
                return
            }
            
            for cookie in cookies {
                if(cookie.name != "reese84") {
                    continue
                }
                
                DataManager.instance.challengeToken = cookie.value
                print("New reese84 token: \(DataManager.instance.challengeToken)")
            }
        }
    }
    
    @objc func loginButtonPressed() {
        var deviceRegistration = DeviceRegistrationRequestDto()
        deviceRegistration.login = self.emailTextField.text ?? ""
        deviceRegistration.password = self.passwordTextField.text ?? ""
        
        DataManager.instance.performDeviceRegistration(deviceRegistrationRequest: deviceRegistration, deviceRegistrationLoadedProtocol: self)
        
        //let authObject = AuthRequestDto(login: self.emailTextField.text ?? "", password: self.passwordTextField.text ?? "")
        //print("Login pressed with: " + authObject.login + " and " + authObject.password)
        
        //DataManager.instance.loadAuthData(authRequest: authObject, authDataLoadedProtocol: self)
    }
    
    func didPerformDeviceRegistration(deviceRegistration: DeviceRegistrationResultDto) {
        CredentialHelper.instance.setDeviceRegistration(deviceRegistration: deviceRegistration)
        self.dismiss(animated: true)
    }
    
    /**
     Replaced with device registration
     */
    func didLoadAuthData(authResult: AuthResultDto) {
        //CredentialHelper.instance.setUserInfo(userInfo: authResult)
        CredentialHelper.instance.setPassword(password: self.passwordTextField.text ?? "")
        self.dismiss(animated: true)
    }
    
    func didPerformDeviceUnregistration() {
    }
}

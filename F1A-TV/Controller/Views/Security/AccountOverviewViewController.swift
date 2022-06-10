//
//  AccountOverviewViewController.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 08.03.21.
//

import UIKit

class AccountOverviewViewController: BaseViewController, DeviceRegistrationLoadedProtocol {
    @IBOutlet weak var accountTitleLabel: UILabel!
    @IBOutlet weak var idTitleLabel: UILabel!
    @IBOutlet weak var idValueLabel: UILabel!
    @IBOutlet weak var nameTitleLabel: UILabel!
    @IBOutlet weak var nameValueLabel: UILabel!
    @IBOutlet weak var emailTitleLabel: UILabel!
    @IBOutlet weak var emailValueLabel: UILabel!
    @IBOutlet weak var countryTitleLabel: UILabel!
    @IBOutlet weak var countryValueLabel: UILabel!
    @IBOutlet weak var subscriptionTitleLabel: UILabel!
    @IBOutlet weak var subscriptionValueLabel: UILabel!
    @IBOutlet weak var logoutButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.setupView()
    }
    
    func setupView() {
        self.accountTitleLabel.text = "account_title".localizedString
        self.idTitleLabel.text = "account_id_title".localizedString
        self.nameTitleLabel.text = "account_name_title".localizedString
        self.emailTitleLabel.text = "account_email_title".localizedString
        self.countryTitleLabel.text = "account_country_title".localizedString
        self.subscriptionTitleLabel.text = "account_subscription_title".localizedString
        
        self.logoutButton.removeTarget(nil, action: nil, for: .allEvents)
        
        if(CredentialHelper.instance.isLoginInformationCached()) {
            self.logoutButton.setTitle("logout_button_title".localizedString, for: .normal)
            self.logoutButton.addTarget(self, action: #selector(self.logoutPressed), for: .primaryActionTriggered)
            
            let deviceRegistration = CredentialHelper.instance.getDeviceRegistration()
            self.idValueLabel.text = String(deviceRegistration.sessionSummary.subscriberId)
            self.nameValueLabel.text = deviceRegistration.sessionSummary.firstName + " " + deviceRegistration.sessionSummary.lastName
            self.emailValueLabel.text = deviceRegistration.sessionSummary.email
            self.countryValueLabel.text = (IsoCountryCodes.find(key: deviceRegistration.sessionSummary.homeCountry)?.flag ?? "") + (IsoCountryCodes.find(key: deviceRegistration.sessionSummary.homeCountry)?.name ?? "")
            self.subscriptionValueLabel.text = deviceRegistration.data.subscriptionStatus
        }else{
            self.logoutButton.setTitle("login_button_title".localizedString, for: .normal)
            self.logoutButton.addTarget(self, action: #selector(self.loginPressed), for: .primaryActionTriggered)
            self.idValueLabel.text = "-"
            self.nameValueLabel.text = "-"
            self.emailValueLabel.text = "-"
            self.countryValueLabel.text = "-"
            self.subscriptionValueLabel.text = "-"
        }
    }
    
    @objc func logoutPressed() {
        DataManager.instance.performDeviceUnregistration(deviceRegistrationLoadedProtocol: self)
        
        //CredentialHelper.instance.setUserInfo(userInfo: AuthResultDto())
        //CredentialHelper.instance.setPassword(password: "")
        
        //self.setupView()
    }
    
    @objc func loginPressed() {
        self.presentFullscreen(viewIdentifier: ConstantsUtil.loginViewController)
    }
    
    func didPerformDeviceRegistration(deviceRegistration: DeviceRegistrationResultDto) {
    }
    
    func didPerformDeviceUnregistration() {
        CredentialHelper.instance.setDeviceRegistration(deviceRegistration: DeviceRegistrationResultDto())
        self.setupView()
    }
}

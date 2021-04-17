//
//  AccountOverviewViewController.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 08.03.21.
//

import UIKit

class AccountOverviewViewController: BaseViewController {
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
        self.accountTitleLabel.text = NSLocalizedString("account_title", comment: "")
        self.idTitleLabel.text = NSLocalizedString("account_id_title", comment: "")
        self.nameTitleLabel.text = NSLocalizedString("account_name_title", comment: "")
        self.emailTitleLabel.text = NSLocalizedString("account_email_title", comment: "")
        self.countryTitleLabel.text = NSLocalizedString("account_country_title", comment: "")
        self.subscriptionTitleLabel.text = NSLocalizedString("account_subscription_title", comment: "")
        
        self.logoutButton.removeTarget(nil, action: nil, for: .allEvents)
        
        if(CredentialHelper.instance.isLoginInformationCached()) {
            self.logoutButton.setTitle(NSLocalizedString("logout_button_title", comment: ""), for: .normal)
            self.logoutButton.addTarget(self, action: #selector(self.logoutPressed), for: .primaryActionTriggered)
            
            let userInfo = CredentialHelper.instance.getUserInfo()
            self.idValueLabel.text = String(userInfo.subscriber.id)
            self.nameValueLabel.text = userInfo.subscriber.firstName + " " + userInfo.subscriber.lastName
            self.emailValueLabel.text = userInfo.subscriber.email
            self.countryValueLabel.text = (IsoCountryCodes.find(key: userInfo.country)?.flag ?? "") + (IsoCountryCodes.find(key: userInfo.country)?.name ?? "")
            self.subscriptionValueLabel.text = userInfo.authData.subscriptionStatus
        }else{
            self.logoutButton.setTitle(NSLocalizedString("login_button_title", comment: ""), for: .normal)
            self.logoutButton.addTarget(self, action: #selector(self.loginPressed), for: .primaryActionTriggered)
            self.idValueLabel.text = "-"
            self.nameValueLabel.text = "-"
            self.emailValueLabel.text = "-"
            self.countryValueLabel.text = "-"
            self.subscriptionValueLabel.text = "-"
        }
    }
    
    @objc func logoutPressed() {
        CredentialHelper.instance.setUserInfo(userInfo: AuthResultDto())
        CredentialHelper.instance.setPassword(password: "")
        
        self.setupView()
    }
    
    @objc func loginPressed() {
        self.presentFullscreen(viewIdentifier: ConstantsUtil.loginViewController)
    }
}

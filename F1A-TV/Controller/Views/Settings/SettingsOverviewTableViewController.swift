//
//  SettingsOverviewTableViewController.swift
//  SettingsOverviewTableViewController
//
//  Created by Noah Fetz on 05.09.21.
//

import UIKit

class SettingsOverviewTableViewController: BaseTableViewController {
    var playerSettings = CredentialHelper.getPlayerSettings()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.playerSettings = CredentialHelper.getPlayerSettings()
    }
    
    func setupTableView() {
        
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return APIStreamType.allCases.count
            
        default:
            return 0
            
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.templateTableViewCell, for: indexPath) as! TemplateTableViewCell
            
            cell.contentStackView.arrangedSubviews.forEach({$0.removeFromSuperview()})
            
            cell.unselectedBackgroundColor = .clear
            cell.userInterfaceStyleChanged()
            
            let currentType = APIStreamType.init(rawValue: indexPath.row)
            
            let titleLabel = UILabel()
            titleLabel.font = UIFont(name: "Formula1-Display-Regular", size: 28)
            titleLabel.textColor = .white
            titleLabel.text = currentType?.getProviderDisplayName()
            
            if(currentType == self.playerSettings.preferredCdn) {
                let selectedImage = UIImageView()
                selectedImage.image = UIImage(systemName: "checkmark.circle.fill")
                selectedImage.tintColor = .systemBlue
                selectedImage.contentMode = .scaleAspectFit
                
                cell.addViewsToStackView(views: [titleLabel, selectedImage])
            }else{
                cell.addViewsToStackView(views: [titleLabel])
            }
            
            return cell
            
        default:
            return self.getDefaultNoContentTableViewCell(tableView, cellForRowAt: indexPath)
            
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            let selectedType = APIStreamType.init(rawValue: indexPath.row) ?? APIStreamType()
            self.playerSettings.preferredCdn = selectedType
            
            CredentialHelper.setPlayerSettings(playerSettings: self.playerSettings)
            DataManager.instance.apiStreamType = selectedType
            
            self.tableView.reloadData()
            
        default:
            print("No action")
            
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "settings_cdn_header".localizedString
            
        default:
            return nil
            
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return "settings_cdn_footer".localizedString
            
        default:
            return nil
            
        }
    }
}

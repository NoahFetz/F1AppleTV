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
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
            
        case 1:
            return DriverChannelSortType.allCases.count
            
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
            
            let titleLabel = UILabel()
            titleLabel.font = UIFont(name: "Formula1-Display-Regular", size: 18)
            titleLabel.textColor = .white
            titleLabel.text = "settings_show_fun_names_title".localizedString
            titleLabel.minimumScaleFactor = 0.5
            titleLabel.adjustsFontSizeToFitWidth = true
            titleLabel.allowsDefaultTighteningForTruncation = true
            
            if(self.playerSettings.showFunNames) {
                let selectedImage = UIImageView()
                selectedImage.image = UIImage(systemName: "checkmark.circle.fill")
                selectedImage.tintColor = .systemBlue
                selectedImage.contentMode = .scaleAspectFit
                
                cell.addViewsToStackView(views: [titleLabel, selectedImage])
            }else{
                cell.addViewsToStackView(views: [titleLabel])
            }
            
            return cell
            
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.templateTableViewCell, for: indexPath) as! TemplateTableViewCell
            
            cell.contentStackView.arrangedSubviews.forEach({$0.removeFromSuperview()})
            
            cell.unselectedBackgroundColor = .clear
            cell.userInterfaceStyleChanged()
            
            let currentType = DriverChannelSortType.init(rawValue: indexPath.row)
            
            let titleLabel = UILabel()
            titleLabel.font = UIFont(name: "Formula1-Display-Regular", size: 28)
            titleLabel.textColor = .white
            titleLabel.text = currentType?.getDisplayName()
            
            if(currentType == self.playerSettings.driverChannelSorting) {
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
            self.playerSettings.showFunNames = !self.playerSettings.showFunNames
            
            CredentialHelper.setPlayerSettings(playerSettings: self.playerSettings)
            self.tableView.reloadDataWithDissolve()
            
        case 1:
            let selectedType = DriverChannelSortType.init(rawValue: indexPath.row) ?? DriverChannelSortType()
            self.playerSettings.driverChannelSorting = selectedType
            
            CredentialHelper.setPlayerSettings(playerSettings: self.playerSettings)
            self.tableView.reloadDataWithDissolve()
            
        default:
            print("No action")
            
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "settings_fun_header".localizedString
            
        case 1:
            return "settings_driver_channel_sorting_title".localizedString
            
        default:
            return nil
            
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        default:
            return nil
            
        }
    }
}

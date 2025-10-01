//
//  MenuSelectorTableViewController.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 08.03.21.
//

import UIKit

class MenuSelectorTableViewController: BaseTableViewController {
    var featuredViewController: PageOverviewCollectionViewController?
    var currentSeasonViewController: PageOverviewCollectionViewController?
    var archiveViewController: PageOverviewCollectionViewController?
    var showsViewController: PageOverviewCollectionViewController?
    var docsViewController: PageOverviewCollectionViewController?
    var accountViewController: AccountOverviewViewController?
    var settingsViewController: SettingsOverviewTableViewController?
    
    var menuSwitchTimer: Timer!
    var selectedMenuItem = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if(self.traitCollection.userInterfaceStyle == .dark){
            ConstantsUtil.darkStyle = true
        }else{
            ConstantsUtil.darkStyle = false
        }
        
        self.registerForTraitCollectionChange()
        
        self.setupTableView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.tableView.selectRow(at: IndexPath(row: self.selectedMenuItem, section: 0), animated: false, scrollPosition: .none)
    }
    
    func setupTableView() {
        self.featuredViewController = self.createPageViewController(pageUri: self.buildPageUri(pageId: MenuPageType.Home.getPageId()))
        self.splitViewController?.showDetailViewController(self.featuredViewController ?? UIViewController(), sender: self)
        
        let backgroundImageView = UIImageView(frame: self.tableView.bounds)
        self.tableView.backgroundView = backgroundImageView
        
        let maskLayer = CAGradientLayer()
        let tbackgroundFrame = CGRect(x: 0, y: 0, width: backgroundImageView.bounds.width/3, height: backgroundImageView.bounds.height)
        maskLayer.frame = tbackgroundFrame
        maskLayer.shadowRadius = 40
        maskLayer.shadowPath = CGPath(roundedRect: tbackgroundFrame.insetBy(dx: 100, dy: 100), cornerWidth: 50, cornerHeight: 50, transform: nil)
        maskLayer.shadowOpacity = 1
        maskLayer.shadowOffset = CGSize.zero
        maskLayer.shadowColor = UIColor.white.cgColor
        backgroundImageView.layer.mask = maskLayer
        backgroundImageView.contentMode = .scaleAspectFill
        
        backgroundImageView.image = UIImage(named: "thumb_placeholder")
    }
    
    func registerForTraitCollectionChange() {
        self.registerForTraitChanges([UITraitUserInterfaceStyle.self], handler: { (self: Self, previousTraitCollection: UITraitCollection) in
            if (self.traitCollection.userInterfaceStyle == .dark) {
                ConstantsUtil.darkStyle = true
            } else {
                ConstantsUtil.darkStyle = false
            }
            NotificationCenter.default.post(name: .userInterfaceStyleChanged, object: nil)
        })
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 7
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.templateTableViewCell, for: indexPath) as! TemplateTableViewCell
        
        cell.contentStackView.arrangedSubviews.forEach({$0.removeFromSuperview()})
        
        cell.unselectedBackgroundColor = .clear
        cell.userInterfaceStyleChanged()
        
        let menuTitleLabel = UILabel()
        menuTitleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 38)
        menuTitleLabel.textColor = .white
        
        switch indexPath.row {
        case 0:
            menuTitleLabel.text = "featured_title".localizedString
            
        case 1:
            menuTitleLabel.text = Date().getYear() + " " + "race_seasons_header".localizedString
            
        case 2:
            menuTitleLabel.text = "archive_title".localizedString
            
        case 3:
            menuTitleLabel.text = "shows_title".localizedString
            
        case 4:
            menuTitleLabel.text = "docs_title".localizedString
            
        case 5:
            menuTitleLabel.text = "account_title".localizedString
            
        case 6:
            menuTitleLabel.text = "settings_title".localizedString
            
        default:
            menuTitleLabel.text = ""
        }
        
        cell.addViewsToStackView(views: [menuTitleLabel])
        
        cell.selectionStyle = .default
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if(context.nextFocusedIndexPath == nil) {
            //Not on tableView
            return
        }
        
        tableView.selectRow(at: context.nextFocusedIndexPath, animated: true, scrollPosition: .none)
        
        if(self.menuSwitchTimer != nil){
            self.menuSwitchTimer.invalidate()
            self.menuSwitchTimer = nil
        }
        
        if(context.nextFocusedIndexPath?.row == self.selectedMenuItem) {
            return
        }
        self.selectedMenuItem = context.nextFocusedIndexPath?.row ?? 0
        
        self.menuSwitchTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false, block: {timer in
            switch context.nextFocusedIndexPath?.row {
            case 0:
                self.featuredViewController = self.createPageViewController(pageUri: self.buildPageUri(pageId: MenuPageType.Home.getPageId()))
                self.splitViewController?.showDetailViewController(self.featuredViewController ?? UIViewController(), sender: self)
                
            case 1:
                self.currentSeasonViewController = self.createPageViewController(pageUri: self.buildPageUri(pageId: MenuPageType.CurrentSeason.getPageId()))
                self.splitViewController?.showDetailViewController(self.currentSeasonViewController ?? UIViewController(), sender: self)
                
            case 2:
                self.archiveViewController = self.createPageViewController(pageUri: self.buildPageUri(pageId: MenuPageType.Archive.getPageId()))
                self.splitViewController?.showDetailViewController(self.archiveViewController ?? UIViewController(), sender: self)
                
            case 3:
                self.showsViewController = self.createPageViewController(pageUri: self.buildPageUri(pageId: MenuPageType.Shows.getPageId()))
                self.splitViewController?.showDetailViewController(self.showsViewController ?? UIViewController(), sender: self)
                
            case 4:
                self.docsViewController = self.createPageViewController(pageUri: self.buildPageUri(pageId: MenuPageType.Docs.getPageId()))
                self.splitViewController?.showDetailViewController(self.docsViewController ?? UIViewController(), sender: self)
                
            case 5:
                self.accountViewController = self.getViewControllerWith(viewIdentifier: ConstantsUtil.accountOverviewViewController) as? AccountOverviewViewController
                self.splitViewController?.showDetailViewController(self.accountViewController ?? UIViewController(), sender: self)
                
            case 6:
                self.settingsViewController = SettingsOverviewTableViewController()
                self.splitViewController?.showDetailViewController(self.settingsViewController ?? UIViewController(), sender: self)
                
            default:
                print("No action")
            }
        })
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerStackView = UIStackView()
        footerStackView.axis = .vertical
        
        let disclaimerLabel = FontAdjustedUILabel()
        disclaimerLabel.font = UIFont(name: "Formula1-Display-Regular", size: 12)
        disclaimerLabel.text = "disclaimer".localizedString
        disclaimerLabel.numberOfLines = 0
        disclaimerLabel.textAlignment = .center
        disclaimerLabel.backgroundShadow()
        footerStackView.addArrangedSubview(disclaimerLabel)
        
        return footerStackView
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 300
    }
    
    func buildPageUri(pageId: String) -> String {
        return "/\(APIVersionType.V2.getVersionType())/R/\(DataManager.instance.apiLanguage.getAPIKey())/\(DataManager.instance.apiStreamType.getAPIKey())/ALL/PAGE/\(pageId)/F1_TV_Pro_Annual/14"
    }
    
    func createPageViewController(pageUri: String) -> PageOverviewCollectionViewController {
        let viewController = self.getViewControllerWith(viewIdentifier: ConstantsUtil.pageOverviewCollectionViewController) as? PageOverviewCollectionViewController
        viewController?.initialize(pageUri: pageUri)
        
        return viewController ?? PageOverviewCollectionViewController()
    }
}

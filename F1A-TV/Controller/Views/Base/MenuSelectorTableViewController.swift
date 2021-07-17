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
    
    var menuSwitchTimer: Timer!
    var selectedMenuItem = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if(self.traitCollection.userInterfaceStyle == .dark){
            ConstantsUtil.darkStyle = true
        }else{
            ConstantsUtil.darkStyle = false
        }
        
        self.setupTableView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.tableView.selectRow(at: IndexPath(row: self.selectedMenuItem, section: 0), animated: false, scrollPosition: .none)
    }
    
    func setupTableView() {
        self.featuredViewController = self.getViewControllerWith(viewIdentifier: ConstantsUtil.pageOverviewCollectionViewController) as? PageOverviewCollectionViewController
        self.featuredViewController?.initialize(pageUri: "/2.0/R/" + NSLocalizedString("api_endpoing_language_id", comment: "") + "/BIG_SCREEN_HLS/ALL/PAGE/395/F1_TV_Pro_Annual/2") //Home Uri
        
        self.currentSeasonViewController = self.getViewControllerWith(viewIdentifier: ConstantsUtil.pageOverviewCollectionViewController) as? PageOverviewCollectionViewController
        self.currentSeasonViewController?.initialize(pageUri: "/2.0/R/" + NSLocalizedString("api_endpoing_language_id", comment: "") + "/BIG_SCREEN_HLS/ALL/PAGE/1510/F1_TV_Pro_Annual/2") //2021 Uri
        
        self.archiveViewController = self.getViewControllerWith(viewIdentifier: ConstantsUtil.pageOverviewCollectionViewController) as? PageOverviewCollectionViewController
        self.archiveViewController?.initialize(pageUri: "/2.0/R/" + NSLocalizedString("api_endpoing_language_id", comment: "") + "/BIG_SCREEN_HLS/ALL/PAGE/493/F1_TV_Pro_Annual/2") //Archive Uri
        
        self.showsViewController = self.getViewControllerWith(viewIdentifier: ConstantsUtil.pageOverviewCollectionViewController) as? PageOverviewCollectionViewController
        self.showsViewController?.initialize(pageUri: "/2.0/R/" + NSLocalizedString("api_endpoing_language_id", comment: "") + "/BIG_SCREEN_HLS/ALL/PAGE/410/F1_TV_Pro_Annual/2") //Shows Uri
        
        self.docsViewController = self.getViewControllerWith(viewIdentifier: ConstantsUtil.pageOverviewCollectionViewController) as? PageOverviewCollectionViewController
        self.docsViewController?.initialize(pageUri: "/2.0/R/" + NSLocalizedString("api_endpoing_language_id", comment: "") + "/BIG_SCREEN_HLS/ALL/PAGE/413/F1_TV_Pro_Annual/2") //Docs Uri
        
        self.accountViewController = self.getViewControllerWith(viewIdentifier: ConstantsUtil.accountOverviewViewController) as? AccountOverviewViewController
        
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

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #available(iOS 13.0, *) {
            let hasUserInterfaceStyleChanged = previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) ?? false
            if(hasUserInterfaceStyleChanged){
                if(traitCollection.userInterfaceStyle == .dark){
                    ConstantsUtil.darkStyle = true
                }else{
                    ConstantsUtil.darkStyle = false
                }
                NotificationCenter.default.post(name: .userInterfaceStyleChanged, object: nil)
            }
        }
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 6
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
            menuTitleLabel.text = NSLocalizedString("featured_title", comment: "")
            
        case 1:
            menuTitleLabel.text = Date().getYear() + " " + NSLocalizedString("race_seasons_header", comment: "")
            
        case 2:
            menuTitleLabel.text = NSLocalizedString("archive_title", comment: "")
            
        case 3:
            menuTitleLabel.text = NSLocalizedString("shows_title", comment: "")
            
        case 4:
            menuTitleLabel.text = NSLocalizedString("docs_title", comment: "")
            
        case 5:
            menuTitleLabel.text = NSLocalizedString("account_title", comment: "")
            
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
        self.selectedMenuItem = context.nextFocusedIndexPath?.row ?? 0
        
        if(self.menuSwitchTimer != nil){
            self.menuSwitchTimer.invalidate()
            self.menuSwitchTimer = nil
        }
        self.menuSwitchTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false, block: {timer in
            
            switch context.nextFocusedIndexPath?.row {
            case 0:
                self.splitViewController?.showDetailViewController(self.featuredViewController ?? UIViewController(), sender: self)
                
            case 1:
                self.splitViewController?.showDetailViewController(self.currentSeasonViewController ?? UIViewController(), sender: self)
                
            case 2:
                self.splitViewController?.showDetailViewController(self.archiveViewController ?? UIViewController(), sender: self)
                
            case 3:
                self.splitViewController?.showDetailViewController(self.showsViewController ?? UIViewController(), sender: self)
                
            case 4:
                self.splitViewController?.showDetailViewController(self.docsViewController ?? UIViewController(), sender: self)
                
            case 5:
                self.splitViewController?.showDetailViewController(self.accountViewController ?? UIViewController(), sender: self)
                
            default:
                print("No action")
            }
        })
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let disclaimerLabel = FontAdjustedUILabel()
        disclaimerLabel.font = UIFont(name: "Formula1-Display-Regular", size: 12)
        disclaimerLabel.text = NSLocalizedString("disclaimer", comment: "")
        disclaimerLabel.numberOfLines = 0
        disclaimerLabel.textAlignment = .center
        disclaimerLabel.backgroundShadow()
        
        return disclaimerLabel
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 600
    }
}

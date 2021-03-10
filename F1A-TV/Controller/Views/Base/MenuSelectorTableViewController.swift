//
//  MenuSelectorTableViewController.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 08.03.21.
//

import UIKit

class MenuSelectorTableViewController: BaseTableViewController {
    var liveViewController: LiveOverviewCollectionViewController?
    var seasonViewController: SeasonOverviewCollectionViewController?
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
        self.liveViewController = self.getViewControllerWith(viewIdentifier: ConstantsUtil.liveOverviewCollectionViewController) as? LiveOverviewCollectionViewController
        self.seasonViewController = self.getViewControllerWith(viewIdentifier: ConstantsUtil.seasonOverviewCollectionViewController) as? SeasonOverviewCollectionViewController
        self.accountViewController = self.getViewControllerWith(viewIdentifier: ConstantsUtil.accountOverviewViewController) as? AccountOverviewViewController
        
        self.splitViewController?.showDetailViewController(self.liveViewController ?? UIViewController(), sender: self)
        
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
        return 3
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.rightDetailTableViewCell, for: indexPath)
        
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = NSLocalizedString("live_title", comment: "")
            
        case 1:
            cell.textLabel?.text = NSLocalizedString("seasons_title", comment: "")
            
        case 2:
            cell.textLabel?.text = NSLocalizedString("account_title", comment: "")
            
        default:
            cell.textLabel?.text = ""
        }
        
        cell.textLabel?.font = UIFont(name: "Formula1-Display-Bold", size: 38)
        cell.detailTextLabel?.text = ""
        
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
                self.splitViewController?.showDetailViewController(self.liveViewController ?? UIViewController(), sender: self)
                
            case 1:
                self.splitViewController?.showDetailViewController(self.seasonViewController ?? UIViewController(), sender: self)
                
            case 2:
                self.splitViewController?.showDetailViewController(self.accountViewController ?? UIViewController(), sender: self)
                
            default:
                print("No action")
            }
        })
    }
}

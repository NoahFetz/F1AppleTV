//
//  SeasonOverviewTableViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit

class SeasonOverviewTableViewController: BaseTableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTableView()
    }
    
    func setupTableView() {
        DataManager.instance.loadSeasonLookup()
        NotificationCenter.default.addObserver(self, selector: #selector(self.seasonsChanged), name: .seasonsChanged, object: nil)
    }
    
    @objc func seasonsChanged() {
        self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(DataManager.instance.seasons.isEmpty) {
            return 3
        }
        
        return DataManager.instance.seasons.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.thumbnailTitleTableViewCell, for: indexPath) as! ThumbnailTitleTableViewCell

        cell.titleLabel.hideSkeletonAnimation()
        cell.thumbnailImageView.hideSkeletonAnimation()
        
        if(DataManager.instance.seasons.isEmpty) {
            cell.titleLabel.linesCornerRadius = 5
            cell.titleLabel.showSkeletonAnimation()
            
            cell.thumbnailImageView.showSkeletonAnimation()
            
            cell.setAccessoryIcon(accessoryIcon: AccessoryIconType.None)
        }else{
            let currentItem = DataManager.instance.seasons[indexPath.row]
            
            cell.titleLabel.text = currentItem.name
            cell.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
            
            cell.setAccessoryIcon(accessoryIcon: AccessoryIconType.Disclosure)
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(DataManager.instance.seasons.isEmpty) {
            return
        }
        
        let currentItem = DataManager.instance.seasons[indexPath.row]
        
        let vc = self.getViewControllerWith(viewIdentifier: ConstantsUtil.eventOverviewTableViewController) as! EventOverviewTableViewController
        vc.initialize(season: currentItem)
        self.presentFullscreenInNavigationController(viewController: vc)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("race_seasons_header", comment: "")
    }
}

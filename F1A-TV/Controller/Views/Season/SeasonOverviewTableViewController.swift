//
//  SeasonOverviewTableViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit

class SeasonOverviewTableViewController: BaseTableViewController, SeasonsLoadedProtocol {
    var seasons: [SeasonDto]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTableView()
    }
    
    func setupTableView() {
        DataManager.instance.loadSeasonLookup(returnInterface: self)
    }
    
    func didLoadSeasons(seasons: [SeasonDto]) {
        self.seasons = seasons
        self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(self.seasons == nil) {
            return 3
        }
        
        if((self.seasons?.isEmpty) ?? false) {
            return 1
        }
        
        return self.seasons?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if((self.seasons?.isEmpty) ?? false) {
            let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.noContentTableViewCell, for: indexPath) as! NoContentTableViewCell
            
            cell.centerLabel.text = NSLocalizedString("no_content_press_to_refresh", comment: "")
            
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.thumbnailTitleTableViewCell, for: indexPath) as! ThumbnailTitleTableViewCell

        cell.titleLabel.hideSkeletonAnimation()
        cell.thumbnailImageView.hideSkeletonAnimation()
        
        if(self.seasons == nil) {
            cell.titleLabel.text = ""
            cell.titleLabel.linesCornerRadius = 5
            cell.titleLabel.showSkeletonAnimation()
            
            cell.thumbnailImageView.showSkeletonAnimation()
            
            cell.setAccessoryIcon(accessoryIcon: AccessoryIconType.None)
        }else{
            let currentItem = self.seasons?[indexPath.row] ?? SeasonDto()
            
            cell.titleLabel.text = currentItem.name
            cell.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
            
            cell.setAccessoryIcon(accessoryIcon: AccessoryIconType.Disclosure)
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(self.seasons == nil) {
            DataManager.instance.loadSeasonLookup(returnInterface: self)
            return
        }
        
        if((self.seasons?.isEmpty) ?? false) {
            DataManager.instance.loadSeasonLookup(returnInterface: self)
            return
        }
        
        let currentItem = self.seasons?[indexPath.row] ?? SeasonDto()
        
        let vc = self.getViewControllerWith(viewIdentifier: ConstantsUtil.eventOverviewCollectionViewController) as! EventOverviewCollectionViewController
        vc.initialize(season: currentItem)
        self.presentFullscreenInNavigationController(viewController: vc)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("race_seasons_header", comment: "")
    }
}

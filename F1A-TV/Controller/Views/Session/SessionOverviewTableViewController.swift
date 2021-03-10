//
//  SessionOverviewTableViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import UIKit

class SessionOverviewTableViewController: BaseTableViewController, SessionLoadedProtocol {
    var event = EventDto()
    var sessions: [SessionDto]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTableView()
    }
    
    func setupTableView() {
        self.loadData()
    }
    
    func loadData() {
        self.sessions = nil
        for sessionUrl in self.event.sessionOccurrenceUrls {
            DataManager.instance.loadSession(sessionUrl: sessionUrl, sessionProtocol: self)
        }
    }
    
    func didLoadSession(session: SessionDto) {
        if(self.sessions == nil) {
            self.sessions = [SessionDto]()
        }
        
        self.sessions?.append(session)
        
        if(self.sessions?.count == self.event.sessionOccurrenceUrls.count) {
            self.sessions?.sort(by: {$0.startTime < $1.endTime})
            self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
        }
    }
    
    func initialize(event: EventDto) {
        self.event = event
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(self.sessions == nil) {
            return 3
        }
        
        if((self.sessions?.isEmpty) ?? false) {
            return 1
        }
        
        return self.sessions?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if((self.sessions?.isEmpty) ?? false) {
            let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.noContentTableViewCell, for: indexPath) as! NoContentTableViewCell
            
            cell.centerLabel.text = NSLocalizedString("no_content_press_to_refresh", comment: "")
            
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.thumbnailTitleSubtitleTableViewCell, for: indexPath) as! ThumbnailTitleSubtitleTableViewCell

        cell.titleLabel.hideSkeletonAnimation()
        cell.subtitleLabel.hideSkeletonAnimation()
        cell.thumbnailImageView.hideSkeletonAnimation()
        
        if(self.sessions == nil) {
            cell.titleLabel.text = ""
            cell.titleLabel.linesCornerRadius = 5
            cell.titleLabel.showSkeletonAnimation()
            
            cell.subtitleLabel.text = ""
            cell.subtitleLabel.linesCornerRadius = 5
            cell.subtitleLabel.showSkeletonAnimation()
            
            cell.thumbnailImageView.showSkeletonAnimation()
            
            cell.setAccessoryIcon(accessoryIcon: AccessoryIconType.None)
        }else{
            let currentItem = self.sessions?[indexPath.row] ?? SessionDto()
            
            cell.titleLabel.text = currentItem.name
            cell.subtitleLabel.text = currentItem.startTime.getDateAsStringWithWeekdayAndTime() + " - " + currentItem.endTime.getTimeAsString()
        
            if(currentItem.imageUrls.isEmpty) {
                cell.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
            }else{
                cell.loadImage(imageUrl: currentItem.imageUrls.first ?? "")
            }
            
            if(currentItem.availableForUser) {
                cell.setAccessoryIcon(accessoryIcon: AccessoryIconType.Disclosure)
            }else{
                cell.setAccessoryIcon(accessoryIcon: AccessoryIconType.None)
            }
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(self.sessions == nil) {
            self.loadData()
            return
        }
        
        if((self.sessions?.isEmpty) ?? false) {
            self.loadData()
            return
        }
        
        let selectedSession = self.sessions?[indexPath.row] ?? SessionDto()
        if(!selectedSession.availableForUser) {
            return
        }
        
        let vc = self.getViewControllerWith(viewIdentifier: ConstantsUtil.channelAndEpisodeCollectionViewController) as! ChannelAndEpisodeCollectionViewController
        vc.initialize(session: selectedSession)
        self.presentFullscreenInNavigationController(viewController: vc)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.event.officialName
    }
}

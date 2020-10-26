//
//  SessionOverviewTableViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import UIKit

class SessionOverviewTableViewController: BaseTableViewController, SessionLoadedProtocol {
    var event = EventDto()
    var sessions = [SessionDto]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTableView()
    }
    
    func setupTableView() {
        for sessionUrl in self.event.sessionOccurrenceUrls {
            DataManager.instance.loadSession(sessionUrl: sessionUrl, sessionProtocol: self)
        }
    }
    
    func didLoadSession(session: SessionDto) {
        self.sessions.append(session)
        
        if(session.imageUrls.count != 0) {
            DataManager.instance.loadImage(imageUrl: session.imageUrls.first ?? "")
        }
        
        if(self.sessions.count == self.event.sessionOccurrenceUrls.count) {
            self.sessions.sort(by: {$0.startTime < $1.endTime})
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
        if(self.sessions.count == 0) {
            return 3
        }
        
        return self.sessions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.thumbnailTitleSubtitleTableViewCell, for: indexPath) as! ThumbnailTitleSubtitleTableViewCell

        cell.titleLabel.hideSkeletonAnimation()
        cell.subtitleLabel.hideSkeletonAnimation()
        cell.thumbnailImageView.hideSkeletonAnimation()
        
        if(self.sessions.count == 0) {
            cell.titleLabel.linesCornerRadius = 5
            cell.titleLabel.showSkeletonAnimation()
            cell.subtitleLabel.linesCornerRadius = 5
            cell.subtitleLabel.showSkeletonAnimation()
            
            cell.thumbnailImageView.showSkeletonAnimation()
            
            cell.setAccessoryIcon(accessoryIcon: AccessoryIconType.None)
        }else{
            let currentItem = self.sessions[indexPath.row]
            
            cell.titleLabel.text = currentItem.name
            cell.subtitleLabel.text = currentItem.startTime.getDateAsStringWithWeekdayAndTime() + " - " + currentItem.endTime.getTimeAsString()
        
            if(currentItem.imageUrls.count != 0) {
                cell.imageIsLoaded = false
                cell.loadImage(imageUrl: currentItem.imageUrls.first ?? "")
            }else{
                cell.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
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
        if(self.sessions.count == 0) {
            return
        }
        
        let selectedSession = self.sessions[indexPath.row]
        if(!selectedSession.availableForUser) {
            return
        }
        
        let vc = self.getViewControllerWith(viewIdentifier: ConstantsUtil.channelEpisodeTabBarController) as! ChannelEpisodeTabBarController
        vc.initialize(session: selectedSession)
        self.presentFullscreenInNavigationController(viewController: vc)
        
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.event.officialName
    }
}

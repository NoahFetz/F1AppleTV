//
//  LiveOverviewTableViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import UIKit

class LiveOverviewTableViewController: BaseTableViewController, EventLoadedProtocol, SessionLoadedProtocol {
    var sessions = [SessionDto]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTableView()
    }
    
    func setupTableView() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.seasonsChanged), name: .seasonsChanged, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        DataManager.instance.loadSeasonLookup()
    }
    
    @objc func seasonsChanged() {
        self.sessions = [SessionDto]()
        for season in DataManager.instance.seasons {
            if(String(season.year) == Date().getYear()) {
                for event in season.eventOccurrenceUrls {
                    DataManager.instance.loadEvent(eventUrl: event, eventProtocol: self)
                }
            }
        }
    }
    
    func didLoadEvent(event: EventDto) {
        if(Date().isBetween(event.startDate, and: Calendar.current.date(byAdding: .day, value: 1, to: event.endDate) ?? Date())) {
            for session in event.sessionOccurrenceUrls {
                DataManager.instance.loadSession(sessionUrl: session, sessionProtocol: self)
            }
        }
    }
    
    func didLoadSession(session: SessionDto) {
        if(session.status == "live") {
            self.sessions.append(session)
            
            if(session.imageUrls.count != 0) {
                DataManager.instance.loadImage(imageUrl: session.imageUrls.first ?? "")
                self.sessions.sort(by: {$0.startTime < $1.endTime})
                self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
            }
        }
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
        return NSLocalizedString("live_title", comment: "")
    }
}

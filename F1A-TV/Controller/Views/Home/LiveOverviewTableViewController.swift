//
//  LiveOverviewTableViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import UIKit

class LiveOverviewTableViewController: BaseTableViewController, EventLoadedProtocol, SessionLoadedProtocol, SeasonsLoadedProtocol {
    var sessions: [SessionDto]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTableView()
    }
    
    func setupTableView() {
    }
    
    override func viewDidAppear(_ animated: Bool) {
        DataManager.instance.loadSeasonLookup(returnInterface: self)
    }
    
    func didLoadSeasons(seasons: [SeasonDto]) {
        self.sessions = [SessionDto]()
        for season in seasons {
            if(String(season.year) == Date().getYear()) {
                for event in season.eventOccurrenceUrls {
                    DataManager.instance.loadEvent(eventUrl: event, eventProtocol: self)
                }
            }
        }
        self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
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
            self.sessions?.append(session)
            
            self.sessions?.sort(by: {$0.startTime < $1.endTime})
            self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
        }
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
            DataManager.instance.loadSeasonLookup(returnInterface: self)
            return
        }
        
        if((self.sessions?.isEmpty) ?? false) {
            DataManager.instance.loadSeasonLookup(returnInterface: self)
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
        return NSLocalizedString("featured_title", comment: "")
    }
}

//
//  EventOverviewTableViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit

class EventOverviewTableViewController: BaseTableViewController, EventLoadedProtocol {
    var season = SeasonDto()
    var events = [EventDto]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTableView()
    }
    
    func setupTableView() {
        for eventUrl in self.season.eventOccurrenceUrls {
            DataManager.instance.loadEvent(eventUrl: eventUrl, eventProtocol: self)
        }
    }
    
    func didLoadEvent(event: EventDto) {
        self.events.append(event)
        
        if(event.imageUrls.count != 0) {
            DataManager.instance.loadImage(imageUrl: event.imageUrls.first ?? "")
        }
        
        if(self.events.count == self.season.eventOccurrenceUrls.count) {
            self.events.sort(by: {$0.startDate < $1.startDate})
            self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
        }
    }
    
    func initialize(season: SeasonDto) {
        self.season = season
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(self.events.isEmpty) {
            return 3
        }
        
        return self.events.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.thumbnailTitleSubtitleTableViewCell, for: indexPath) as! ThumbnailTitleSubtitleTableViewCell

        cell.titleLabel.hideSkeletonAnimation()
        cell.subtitleLabel.hideSkeletonAnimation()
        cell.thumbnailImageView.hideSkeletonAnimation()
        
        if(self.events.isEmpty) {
            cell.titleLabel.linesCornerRadius = 5
            cell.titleLabel.showSkeletonAnimation()
            cell.subtitleLabel.linesCornerRadius = 5
            cell.subtitleLabel.showSkeletonAnimation()
            
            cell.thumbnailImageView.showSkeletonAnimation()
            
            cell.setAccessoryIcon(accessoryIcon: AccessoryIconType.None)
        }else{
            let currentItem = self.events[indexPath.row]
            
            cell.titleLabel.text = currentItem.name
            cell.subtitleLabel.text = currentItem.startDate.getDateAsStringWithWeekdayAndLongMonthWithYear() + " - " + currentItem.endDate.getDateAsStringWithWeekdayAndLongMonthWithYear()
        
            if(currentItem.imageUrls.count != 0) {
                cell.imageIsLoaded = false
                cell.loadImage(imageUrl: currentItem.imageUrls.first ?? "")
            }else{
                cell.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
            }
            
            cell.setAccessoryIcon(accessoryIcon: AccessoryIconType.Disclosure)
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(self.events.isEmpty) {
            return
        }
        
        let selectedEvent = self.events[indexPath.row]
        
        let vc = self.getViewControllerWith(viewIdentifier: ConstantsUtil.sessionOverviewTableViewController) as! SessionOverviewTableViewController
        vc.initialize(event: selectedEvent)
        self.presentFullscreenInNavigationController(viewController: vc)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.season.name
    }
}

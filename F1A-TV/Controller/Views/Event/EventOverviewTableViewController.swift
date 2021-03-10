//
//  EventOverviewTableViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit

class EventOverviewTableViewController: BaseTableViewController, EventLoadedProtocol {
    var season = SeasonDto()
    var events: [EventDto]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTableView()
    }
    
    func setupTableView() {
        self.loadData()
    }
    
    func loadData() {
        self.events = nil
        for eventUrl in self.season.eventOccurrenceUrls {
            DataManager.instance.loadEvent(eventUrl: eventUrl, eventProtocol: self)
        }
    }
    
    func didLoadEvent(event: EventDto) {
        if(self.events == nil) {
            self.events = [EventDto]()
        }
        
        self.events?.append(event)
        
        if(self.events?.count == self.season.eventOccurrenceUrls.count) {
            self.events?.sort(by: {$0.startDate < $1.startDate})
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
        if(self.events == nil) {
            return 3
        }
        
        if((self.events?.isEmpty) ?? false) {
            return 1
        }
        
        return self.events?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if((self.events?.isEmpty) ?? false) {
            let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.noContentTableViewCell, for: indexPath) as! NoContentTableViewCell
            
            cell.centerLabel.text = NSLocalizedString("no_content_press_to_refresh", comment: "")
            
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.thumbnailTitleSubtitleTableViewCell, for: indexPath) as! ThumbnailTitleSubtitleTableViewCell

        cell.titleLabel.hideSkeletonAnimation()
        cell.subtitleLabel.hideSkeletonAnimation()
        cell.thumbnailImageView.hideSkeletonAnimation()
        
        if(self.events == nil) {
            cell.titleLabel.text = ""
            cell.titleLabel.linesCornerRadius = 5
            cell.titleLabel.showSkeletonAnimation()
            
            cell.subtitleLabel.text = ""
            cell.subtitleLabel.linesCornerRadius = 5
            cell.subtitleLabel.showSkeletonAnimation()
            
            cell.thumbnailImageView.showSkeletonAnimation()
            
            cell.setAccessoryIcon(accessoryIcon: AccessoryIconType.None)
        }else{
            let currentItem = self.events?[indexPath.row] ?? EventDto()
            
            cell.titleLabel.text = currentItem.name
            cell.subtitleLabel.text = currentItem.startDate.getDateAsStringWithWeekdayAndLongMonthWithYear() + " - " + currentItem.endDate.getDateAsStringWithWeekdayAndLongMonthWithYear()
        
            if(currentItem.imageUrls.isEmpty) {
                cell.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
            }else{
                cell.loadImage(imageUrl: currentItem.imageUrls.first ?? "")
            }
            
            cell.setAccessoryIcon(accessoryIcon: AccessoryIconType.Disclosure)
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(self.events == nil) {
            self.loadData()
            return
        }
        
        if((self.events?.isEmpty) ?? false) {
            self.loadData()
            return
        }
        
        let selectedEvent = self.events?[indexPath.row] ?? EventDto()
        
        let vc = self.getViewControllerWith(viewIdentifier: ConstantsUtil.sessionOverviewCollectionViewController) as! SessionOverviewCollectionViewController
        vc.initialize(event: selectedEvent)
        self.presentFullscreen(viewController: vc)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.season.name
    }
}

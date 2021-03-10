//
//  EventOverviewCollectionViewController.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 09.03.21.
//

import UIKit

class EventOverviewCollectionViewController: BaseCollectionViewController, EventLoadedProtocol, UICollectionViewDelegateFlowLayout {
    var season = SeasonDto()
    var events: [EventDto]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupCollectionView()
    }

    func setupCollectionView() {
        self.loadData()
    }
    
    func loadData() {
        self.events = nil
        for eventUrl in self.season.eventOccurrenceUrls {
            DataManager.instance.loadEvent(eventUrl: eventUrl, eventProtocol: self)
        }
        if(self.season.eventOccurrenceUrls.isEmpty) {
            self.events = [EventDto]()
            self.collectionView.reloadSections(IndexSet(arrayLiteral: 0))
        }
    }
    
    func didLoadEvent(event: EventDto) {
        if(self.events == nil) {
            self.events = [EventDto]()
        }
        
        self.events?.append(event)
        
        if(self.events?.count == self.season.eventOccurrenceUrls.count) {
            self.events?.sort(by: {$0.startDate < $1.startDate})
            self.collectionView.reloadSections(IndexSet(arrayLiteral: 0))
        }
    }
    
    func initialize(season: SeasonDto) {
        self.season = season
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if(self.events == nil) {
            return 3
        }
        
        if((self.events?.isEmpty) ?? false) {
            return 1
        }
        
        return self.events?.count ?? 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if((self.events?.isEmpty) ?? false) {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ConstantsUtil.noContentCollectionViewCell, for: indexPath) as! NoContentCollectionViewCell
            
            cell.centerLabel.text = NSLocalizedString("no_content_press_to_refresh", comment: "")
            
            return cell
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ConstantsUtil.thumbnailTitleSubtitleCollectionViewCell, for: indexPath) as! ThumbnailTitleSubtitleCollectionViewCell

        cell.titleLabel.hideSkeletonAnimation()
        cell.subtitleLabel.hideSkeletonAnimation()
        cell.footerLabel.hideSkeletonAnimation()
        cell.accessoryFooterLabel.hideSkeletonAnimation()
        cell.thumbnailImageView.hideSkeletonAnimation()
        
        if(self.events == nil) {
            cell.titleLabel.text = ""
            cell.titleLabel.linesCornerRadius = 5
            cell.titleLabel.showSkeletonAnimation()
            
            cell.subtitleLabel.text = ""
            cell.subtitleLabel.linesCornerRadius = 5
            cell.subtitleLabel.showSkeletonAnimation()
            
            cell.footerLabel.text = ""
            cell.footerLabel.linesCornerRadius = 5
            cell.footerLabel.showSkeletonAnimation()
            
            cell.accessoryFooterLabel.text = ""
            cell.accessoryFooterLabel.linesCornerRadius = 5
            cell.accessoryFooterLabel.showSkeletonAnimation()
            
            cell.thumbnailImageView.showSkeletonAnimation()
        }else{
            let currentItem = self.events?[indexPath.row] ?? EventDto()
            
            cell.subtitleLabel.text = ""
            
            cell.titleLabel.text = currentItem.officialName.uppercased()
            cell.footerLabel.text = currentItem.startDate.getDayWithShortMonth().uppercased() + " - " + currentItem.endDate.getDayWithShortMonth().uppercased()
        
            if(currentItem.imageUrls.isEmpty) {
                cell.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
            }else{
                cell.loadImage(imageUrl: currentItem.imageUrls.first ?? "")
            }
            
            cell.accessoryOverlayImageView.image = nil
            
            if(!currentItem.nationUrl.isEmpty) {
                cell.setNation(nationUrl: currentItem.nationUrl)
            }
        }
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if(self.events == nil) {
            self.loadData()
            return
        }
        
        if((self.events?.isEmpty) ?? false) {
            self.loadData()
            return
        }
        
        let selectedEvent = self.events?[indexPath.item] ?? EventDto()
        
        let sideInfoVc = self.getViewControllerWith(viewIdentifier: ConstantsUtil.sideBarInfoViewController) as! SideBarInfoViewController
        sideInfoVc.initialize(eventInfo: selectedEvent)
        
        let sessiontVc = self.getViewControllerWith(viewIdentifier: ConstantsUtil.sessionOverviewCollectionViewController) as! SessionOverviewCollectionViewController
        sessiontVc.initialize(event: selectedEvent)
        
        let splitVc = UISplitViewController()
        splitVc.viewControllers = [sideInfoVc, sessiontVc]
        
        self.presentFullscreenInNavigationController(viewController: splitVc)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if((self.events?.isEmpty) ?? false) {
            return CGSize(width: collectionView.frame.width-48, height: 150)
        }
        
        //2*24 between cells + 2*24 for left and right
        let width = (collectionView.frame.width-96)/3
        return CGSize(width: width, height: width*ConstantsUtil.thumnailCardHeightMultiplier)
    }
}

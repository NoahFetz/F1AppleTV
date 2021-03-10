//
//  LiveOverviewCollectionViewController.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 08.03.21.
//

import UIKit

class LiveOverviewCollectionViewController: BaseCollectionViewController, EventLoadedProtocol, SessionLoadedProtocol, SeasonsLoadedProtocol, UICollectionViewDelegateFlowLayout {
    var sessions: [SessionDto]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupCollectionView()
    }
    
    func setupCollectionView() {
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
        self.collectionView.reloadSections(IndexSet(arrayLiteral: 0))
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
            self.collectionView.reloadSections(IndexSet(arrayLiteral: 0))
        }
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if(self.sessions == nil) {
            return 3
        }
        
        if((self.sessions?.isEmpty) ?? false) {
            return 1
        }
        
        return self.sessions?.count ?? 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if((self.sessions?.isEmpty) ?? false) {
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
        
        if(self.sessions == nil) {
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
            let currentItem = self.sessions?[indexPath.row] ?? SessionDto()
            
            cell.titleLabel.text = currentItem.sessionName
            cell.titleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 20)
            
            var subtitleString = currentItem.startTime.distance(to: currentItem.endTime).stringFromTimeInterval()
            subtitleString.append(" | " + currentItem.name)
            if(!(currentItem.nbcStatus?.isEmpty ?? true)){
                subtitleString.append(" | " + (currentItem.nbcStatus ?? "").uppercased())
            }
            cell.subtitleLabel.text = subtitleString
            cell.subtitleLabel.font = UIFont(name: "Titillium-Regular", size: 20)
            
            cell.footerLabel.text = NSLocalizedString("live", comment: "").uppercased()
            cell.footerLabel.textColor = .systemRed
            
            cell.accessoryFooterLabel.text = ""
            if(!currentItem.seriesUrl.isEmpty) {
                cell.setSeries(seriesUrl: currentItem.seriesUrl)
            }
            
            if(currentItem.imageUrls.isEmpty) {
                cell.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
            }else{
                cell.loadImage(imageUrl: currentItem.imageUrls.first ?? "")
            }
        }
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
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
        
        let sideInfoVc = self.getViewControllerWith(viewIdentifier: ConstantsUtil.sideBarInfoViewController) as! SideBarInfoViewController
        sideInfoVc.initialize(sessionInfo: selectedSession)
        
        let channelAndEpisodeVc = self.getViewControllerWith(viewIdentifier: ConstantsUtil.channelAndEpisodeCollectionViewController) as! ChannelAndEpisodeCollectionViewController
        channelAndEpisodeVc.initialize(session: selectedSession)
        
        let splitVc = UISplitViewController()
        splitVc.viewControllers = [sideInfoVc, channelAndEpisodeVc]
        
        self.presentFullscreenInNavigationController(viewController: splitVc)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if((self.sessions?.isEmpty) ?? false) {
            return CGSize(width: collectionView.frame.width-48, height: 150)
        }
        
        //2*24 between cells + 2*24 for left and right
        let width = (collectionView.frame.width-96)/3
        return CGSize(width: width, height: width*ConstantsUtil.thumnailCardHeightMultiplier)
    }
}

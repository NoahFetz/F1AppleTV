//
//  SessionOverviewCollectionViewController.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 09.03.21.
//

import UIKit

class SessionOverviewCollectionViewController: BaseCollectionViewController, SessionLoadedProtocol, UICollectionViewDelegateFlowLayout {
    var event = EventDto()
    var sessions: [SessionDto]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupCollectionView()
    }
    
    func setupCollectionView() {
        self.loadData()
    }
    
    func loadData() {
        self.sessions = nil
        for sessionUrl in self.event.sessionOccurrenceUrls {
            DataManager.instance.loadSession(sessionUrl: sessionUrl, sessionProtocol: self)
        }
        if(self.event.sessionOccurrenceUrls.isEmpty) {
            self.sessions = [SessionDto]()
            self.collectionView.reloadSections(IndexSet(arrayLiteral: 0))
        }
    }
    
    func didLoadSession(session: SessionDto) {
        if(self.sessions == nil) {
            self.sessions = [SessionDto]()
        }
        
        self.sessions?.append(session)
        
        if(self.sessions?.count == self.event.sessionOccurrenceUrls.count) {
            self.sessions?.sort(by: {$0.startTime < $1.endTime})
            self.collectionView.reloadSections(IndexSet(arrayLiteral: 0))
        }
    }
    
    func initialize(event: EventDto) {
        self.event = event
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
            
            cell.footerLabel.text = currentItem.startTime.getDayWithShortMonth().uppercased()
            
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
            self.loadData()
            return
        }
        
        if((self.sessions?.isEmpty) ?? false) {
            self.loadData()
            return
        }
        
        let selectedSession = self.sessions?[indexPath.item] ?? SessionDto()
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

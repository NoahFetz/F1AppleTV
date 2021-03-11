//
//  ChannelAndEpisodeCollectionViewController.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 09.03.21.
//

import UIKit

class ChannelAndEpisodeCollectionViewController: BaseCollectionViewController, EpisodeLoadedProtocol, ChannelLoadedProtocol, DriverLoadedProtocol, ImageLoadedProtocol, UICollectionViewDelegateFlowLayout {
    var session = SessionDto()
    var channels: [ChannelDto]?
    var episodes: [EpisodeDto]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupCollectionView()
    }
    
    func setupCollectionView() {
        self.loadData()
    }
    
    func loadData() {
        self.channels = nil
        self.episodes = nil
        
        for channelUrl in self.session.channelUrls {
            DataManager.instance.loadChannel(channelUrl: channelUrl, channelProtocol: self)
        }
        if(self.session.channelUrls.isEmpty) {
            self.channels = [ChannelDto]()
            self.collectionView.reloadSections(IndexSet(arrayLiteral: 0))
        }
        
        for episodeUrl in self.session.contentUrls {
            DataManager.instance.loadEpisode(episodeUrl: episodeUrl, episodeProtocol: self)
        }
        if(self.session.contentUrls.isEmpty) {
            self.episodes = [EpisodeDto]()
            self.collectionView.reloadSections(IndexSet(arrayLiteral: 1))
        }
    }
    
    func didLoadChannel(channel: ChannelDto) {
        if(self.channels == nil) {
            self.channels = [ChannelDto]()
        }
        
        self.channels?.append(channel)
        
        if(self.channels?.count == self.session.channelUrls.count) {
            self.channels?.sort(by: {$0.slug > $1.slug})
            self.collectionView.reloadSections(IndexSet(arrayLiteral: 0))
            
            for channel in self.channels ?? [ChannelDto]() {
                if(!channel.driverOccurrenceUrls.isEmpty) {
                    
                    if let driver = DataManager.instance.drivers.first(where: {$0.uid == channel.driverOccurrenceUrls.first?.split(separator: "/").last ?? ""}) {
                        didLoadDriver(driver: driver)
                        return
                    }
                    
                    DataManager.instance.loadDriver(driverUrl: channel.driverOccurrenceUrls.first ?? "", driverProtocol: self)
                }
            }
        }
    }
    
    func didLoadDriver(driver: DriverDto) {
        for imageUrl in driver.imageUrls {
            if let image = DataManager.instance.images.first(where: {$0.uid == imageUrl.split(separator: "/").last ?? ""}) {
                self.didLoadImage(image: image)
                return
            }
            
            DataManager.instance.loadImage(imageUrl: imageUrl, imageProtocol: self)
        }
    }
    
    func didLoadImage(image: ImageDto) {
        if let driver = DataManager.instance.drivers.first(where: {$0.imageUrls.contains(where: {($0.split(separator: "/").last ?? "") == image.uid})}) {
            for imageUrl in driver.imageUrls {
                if let image = DataManager.instance.images.first(where: {$0.uid == imageUrl.split(separator: "/").last ?? ""}) {
                    if(image.imageType == "Headshot") {
                        let channel = self.channels?.first(where: {$0.driverOccurrenceUrls.contains(where: {$0.split(separator: "/").last ?? "" == driver.uid})})
                        
                        self.collectionView.reloadItems(at: [IndexPath(row: self.channels?.firstIndex(where: {$0.uid == channel?.uid}) ?? 0, section: 0)])
                    }
                }
            }
        }
    }
    
    func didLoadEpisode(episode: EpisodeDto) {
        if(self.episodes == nil) {
            self.episodes = [EpisodeDto]()
        }
        
        self.episodes?.append(episode)
        
        if(self.episodes?.count == self.session.contentUrls.count) {
            self.episodes?.sort(by: {$0.slug > $1.slug})
            self.collectionView.reloadSections(IndexSet(arrayLiteral: 1))
        }
    }
    
    func initialize(session: SessionDto) {
        self.session = session
    }
    
    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0:
            if(self.channels == nil) {
                return 3
            }
            
            if((self.channels?.isEmpty) ?? false) {
                return 1
            }
            
            return self.channels?.count ?? 0
            
        case 1:
            if(self.episodes == nil) {
                return 3
            }
            
            if((self.episodes?.isEmpty) ?? false) {
                return 1
            }
            
            return self.episodes?.count ?? 0
            
        default:
            return 0
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch indexPath.section {
        case 0:
            if((self.channels?.isEmpty) ?? false) {
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
            
            if(self.channels == nil) {
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
                let currentItem = self.channels?[indexPath.row] ?? ChannelDto()
                
                cell.subtitleLabel.font = UIFont(name: "Titillium-Regular", size: 20)
                cell.titleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 22)
                
                cell.titleLabel.text = currentItem.name
                cell.subtitleLabel.text = ""
            
                cell.thumbnailImageView.image = UIImage(systemName: "video")
                cell.thumbnailImageView.tintColor = UIColor.systemGray
                cell.thumbnailImageView.contentMode = .scaleAspectFit
                
                cell.accessoryFooterLabel.text = ""
                cell.accessoryOverlayImageView.image = nil
                cell.thumbnailImageView.backgroundColor = .clear
                
                if(!currentItem.driverOccurrenceUrls.isEmpty) {
                    if let driver = DataManager.instance.drivers.first(where: {$0.uid == currentItem.driverOccurrenceUrls.first?.split(separator: "/").last ?? ""}) {
                        
                        cell.subtitleLabel.text = String(driver.driverRacingnumber) + " | " + driver.driverTLA
                        
                        if(!driver.teamUrl.isEmpty){
                            cell.setTeam(teamUrl: driver.teamUrl)
                        }
                        
                        for imageUrl in driver.imageUrls {
                            if let image = DataManager.instance.images.first(where: {$0.uid == imageUrl.split(separator: "/").last ?? ""}) {
                                if(image.imageType == "Headshot") {
                                    cell.loadImage(imageUrl: imageUrl)
                                }
                            }
                        }
                    }
                }
            }
            
            return cell
            
        case 1:
            if((self.episodes?.isEmpty) ?? false) {
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
            
            if(self.episodes == nil) {
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
                let currentItem = self.episodes?[indexPath.row] ?? EpisodeDto()
                
                cell.subtitleLabel.font = UIFont(name: "Titillium-Regular", size: 20)
                cell.titleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 22)
                cell.thumbnailImageView.image = nil
                
                cell.titleLabel.text = currentItem.title
                cell.subtitleLabel.text = ""
                
                cell.accessoryFooterLabel.text = ""
                cell.accessoryOverlayImageView.image = nil
                cell.thumbnailImageView.backgroundColor = .clear
                
                if(!currentItem.items.isEmpty) {
                    cell.setAsset(assetUrl: currentItem.items.first ?? "")
                }
                
                if(currentItem.imageUrls.isEmpty) {
                    cell.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
                }else{
                    cell.loadImage(imageUrl: currentItem.imageUrls.first ?? "")
                }
            }
            
            return cell
            
        default:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ConstantsUtil.basicCollectionViewCell, for: indexPath)
            return cell
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            if(self.channels == nil) {
                self.loadData()
                return
            }
            
            if((self.channels?.isEmpty) ?? false) {
                self.loadData()
                return
            }
            
            if(!CredentialHelper.isLoginInformationCached() || CredentialHelper.getUserInfo().authData.subscriptionStatus != "active"){
                UserInteractionHelper.instance.showAlert(title: NSLocalizedString("account_no_subscription_title", comment: ""), message: NSLocalizedString("account_no_subscription_message", comment: ""))
                return
            }
            
            let selectedChannel = self.channels?[indexPath.row] ?? ChannelDto()
            self.openStream(channel: selectedChannel)
            
        case 1:
            if(self.episodes == nil) {
                self.loadData()
                return
            }
            
            if((self.episodes?.isEmpty) ?? false) {
                self.loadData()
                return
            }
            
            if(!CredentialHelper.isLoginInformationCached() || CredentialHelper.getUserInfo().authData.subscriptionStatus != "active"){
                UserInteractionHelper.instance.showAlert(title: NSLocalizedString("account_no_subscription_title", comment: ""), message: NSLocalizedString("account_no_subscription_message", comment: ""))
                return
            }
            
            let selectedEpisode = self.episodes?[indexPath.row] ?? EpisodeDto()
            self.openStream(episode: selectedEpisode)
            
        default:
            print("No action")
        }
    }
    
    func openStream(channel: ChannelDto) {
        let tokenRequest = ChannelStreamTokenRequestDto(channelUrl: "/api/channels/" + channel.uid + "/")
        
        NetworkRouter.instance.channelStreamTokenRequest(streamTokenRequest: tokenRequest, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                    UserInteractionHelper.instance.showAlert(title: NSLocalizedString("error", comment: ""), message: error.localizedDescription)
                case .success(let requestResult):
                    DispatchQueue.main.async {
                        if let url = URL(string: requestResult.tokenisedUrl) {
                            PlayerController.instance.openPlayer(url: url)
                        }
                    }
                }
            }
        })
    }
    
    func openStream(episode: EpisodeDto) {
        let tokenRequest = AssetStreamTokenRequestDto(assetUrl: episode.items.first ?? "")
        
        NetworkRouter.instance.assetStreamTokenRequest(assetTokenRequest: tokenRequest, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                    UserInteractionHelper.instance.showAlert(title: NSLocalizedString("error", comment: ""), message: error.localizedDescription)
                case .success(let requestResult):
                    DispatchQueue.main.async {
                        if let urlString = requestResult.assetStreamTokenObjects.first?.assetStreamToken.tokenisedURL {
                            if let url = URL(string: urlString) {
                                PlayerController.instance.openPlayer(url: url)
                            }
                        }
                    }
                }
            }
        })
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        switch indexPath.section {
        case 0:
            if((self.channels?.isEmpty) ?? false) {
                return CGSize(width: collectionView.frame.width-48, height: 150)
            }
            
            //2*24 between cells + 2*24 for left and right
            let width = (collectionView.frame.width-96)/3
            return CGSize(width: width, height: width*ConstantsUtil.thumnailCardHeightMultiplier)
            
        case 1:
            if((self.episodes?.isEmpty) ?? false) {
                return CGSize(width: collectionView.frame.width-48, height: 150)
            }
            
            //2*24 between cells + 2*24 for left and right
            let width = (collectionView.frame.width-96)/3
            return CGSize(width: width, height: width*ConstantsUtil.thumnailCardHeightMultiplier)
            
        default:
            return CGSize.zero
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let headerView = self.collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: ConstantsUtil.customHeaderCollectionReusableView, for: indexPath)
            
            for subview in headerView.subviews {
                subview.removeFromSuperview()
            }
            
            let titleLabel = UILabel(frame: CGRect(x: 24, y: 80, width: self.view.bounds.width-48, height: 60))
            titleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 34)
            
            switch indexPath.section {
            case 0:
                titleLabel.text = NSLocalizedString("channels_title", comment: "")
            case 1:
                titleLabel.text = NSLocalizedString("episodes_title", comment: "")
            default:
                titleLabel.text = "Not found"
            }
            headerView.addSubview(titleLabel)
            
            return headerView
        default:
            print("No user for kind: " + kind)
            assert(false, "Did not expect a footer view")
        }
        return UICollectionReusableView()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: self.view.frame.width, height: 150)
    }
}

//
//  VodEpisodeCollectionViewController.swift
//  F1A-TV
//
//  Created by Noah Fetz on 11.03.21.
//

import UIKit

class VodEpisodeCollectionViewController: BaseCollectionViewController, UICollectionViewDelegateFlowLayout, EpisodeLoadedProtocol {
    var vod = VodDto()
    var episodes: [EpisodeDto]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupCollectionView()
    }

    func setupCollectionView() {
        self.loadData()
    }
    
    func loadData() {
        self.episodes = nil
        
        for episodeUrl in self.vod.contentUrls {
            DataManager.instance.loadEpisode(episodeUrl: episodeUrl, episodeProtocol: self)
        }
        if(self.vod.contentUrls.isEmpty) {
            self.episodes = [EpisodeDto]()
            self.collectionView.reloadSections(IndexSet(arrayLiteral: 0))
        }
    }
    
    func didLoadEpisode(episode: EpisodeDto) {
        if(self.episodes == nil) {
            self.episodes = [EpisodeDto]()
        }
        
        self.episodes?.append(episode)
        
        if(self.episodes?.count == self.vod.contentUrls.count) {
            self.episodes?.sort(by: {$0.slug > $1.slug})
            self.collectionView.reloadSections(IndexSet(arrayLiteral: 0))
        }
    }
    
    func initialize(vod: VodDto) {
        self.vod = vod
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if(self.episodes == nil) {
            return 3
        }
        
        if((self.episodes?.isEmpty) ?? false) {
            return 1
        }
        
        return self.episodes?.count ?? 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
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
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
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
        if((self.episodes?.isEmpty) ?? false) {
            return CGSize(width: collectionView.frame.width-48, height: 150)
        }
        
        //2*24 between cells + 2*24 for left and right
        let width = (collectionView.frame.width-96)/3
        return CGSize(width: width, height: width*ConstantsUtil.thumnailCardHeightMultiplier)
    }
}

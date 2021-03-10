//
//  EpisodeOverviewTableViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import UIKit
import AVKit

class EpisodeOverviewTableViewController: BaseTableViewController, EpisodeLoadedProtocol {
    var session = SessionDto()
    var episodes: [EpisodeDto]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTableView()
    }
    
    func setupTableView() {
        self.session = (self.tabBarController as! ChannelEpisodeTabBarController).session
        self.loadData()
    }
    
    func loadData() {
        self.episodes = nil
        for episodeUrl in self.session.contentUrls {
            DataManager.instance.loadEpisode(episodeUrl: episodeUrl, episodeProtocol: self)
        }
    }
    
    func didLoadEpisode(episode: EpisodeDto) {
        if(self.episodes == nil) {
            self.episodes = [EpisodeDto]()
        }
        
        self.episodes?.append(episode)
        
        if(self.episodes?.count == self.session.contentUrls.count) {
            self.episodes?.sort(by: {$0.slug > $1.slug})
            self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(self.episodes == nil) {
            return 3
        }
        
        if((self.episodes?.isEmpty) ?? false) {
            return 1
        }
        
        return self.episodes?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if((self.episodes?.isEmpty) ?? false) {
            let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.noContentTableViewCell, for: indexPath) as! NoContentTableViewCell
            
            cell.centerLabel.text = NSLocalizedString("no_content_press_to_refresh", comment: "")
            
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.thumbnailTitleTableViewCell, for: indexPath) as! ThumbnailTitleTableViewCell

        cell.titleLabel.hideSkeletonAnimation()
        cell.thumbnailImageView.hideSkeletonAnimation()
        
        if(self.episodes == nil) {
            cell.titleLabel.linesCornerRadius = 5
            cell.titleLabel.showSkeletonAnimation()
            
            cell.thumbnailImageView.showSkeletonAnimation()
            
            cell.setAccessoryIcon(accessoryIcon: AccessoryIconType.None)
        }else{
            let currentItem = self.episodes?[indexPath.row] ?? EpisodeDto()
            
            cell.titleLabel.text = currentItem.title
            
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

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("episodes_title", comment: "")
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
}

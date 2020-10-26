//
//  EpisodeOverviewTableViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import UIKit
import AVKit

class EpisodeOverviewTableViewController: BaseTableViewController, EpisodeLoadedProtocol, AVPlayerViewControllerDelegate {
    var session = SessionDto()
    var episodes = [EpisodeDto]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTableView()
    }
    
    func setupTableView() {
        self.session = (self.tabBarController as! ChannelEpisodeTabBarController).session
        for episodeUrl in self.session.contentUrls {
            DataManager.instance.loadEpisode(episodeUrl: episodeUrl, episodeProtocol: self)
        }
    }
    
    func didLoadEpisode(episode: EpisodeDto) {
        self.episodes.append(episode)
        
        if(episode.imageUrls.count != 0) {
            DataManager.instance.loadImage(imageUrl: episode.imageUrls.first ?? "")
        }
        
        if(self.episodes.count == self.session.contentUrls.count) {
            self.episodes.sort(by: {$0.slug > $1.slug})
            self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(self.episodes.count == 0) {
            return 3
        }
        
        return self.episodes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.thumbnailTitleTableViewCell, for: indexPath) as! ThumbnailTitleTableViewCell

        cell.titleLabel.hideSkeletonAnimation()
        cell.thumbnailImageView.hideSkeletonAnimation()
        
        if(self.episodes.count == 0) {
            cell.titleLabel.linesCornerRadius = 5
            cell.titleLabel.showSkeletonAnimation()
            
            cell.thumbnailImageView.showSkeletonAnimation()
            
            cell.setAccessoryIcon(accessoryIcon: AccessoryIconType.None)
        }else{
            let currentItem = self.episodes[indexPath.row]
            
            cell.titleLabel.text = currentItem.title
        
            cell.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
            
            if(currentItem.imageUrls.count != 0) {
                cell.loadImage(imageUrl: currentItem.imageUrls.first ?? "")
            }
            
            cell.setAccessoryIcon(accessoryIcon: AccessoryIconType.Disclosure)
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(self.episodes.count == 0) {
            return
        }
        
        let selectedEpisode = self.episodes[indexPath.row]
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
                    self.showAlert(title: NSLocalizedString("error", comment: ""), message: error.localizedDescription)
                case .success(let requestResult):
                    DispatchQueue.main.async {
                        if let urlString = requestResult.assetStreamTokenObjects.first?.assetStreamToken.tokenisedURL {
                            if let url = URL(string: urlString) {
                                self.openPlayer(url: url)
                            }
                        }
                    }
                }
            }
        })
    }
    
    func openPlayer(url: URL) {
        let player = AVPlayer(url: url)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch(let error) {
            print(error.localizedDescription)
        }
        
        playerViewController.delegate = self
        playerViewController.allowsPictureInPicturePlayback = true
        
        self.present(playerViewController, animated: true) {
            playerViewController.player!.play()
        }
    }
    
    func playerViewController(_ playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
            self.present(playerViewController, animated: true)
    }
    
    func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("close", comment: ""), style: .cancel, handler: { (UIAlertAction) in
            print("Cancelled")
        }))
        
        self.present(alertController, animated: true)
    }
}

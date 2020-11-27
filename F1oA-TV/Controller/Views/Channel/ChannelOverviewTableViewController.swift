//
//  ChannelOverviewTableViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import UIKit
import AVKit

class ChannelOverviewTableViewController: BaseTableViewController, ChannelLoadedProtocol, DriverLoadedProtocol, AVPlayerViewControllerDelegate, ImageLoadedProtocol {
    
    var session = SessionDto()
    var channels = [ChannelDto]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTableView()
    }
    
    func setupTableView() {
        self.session = (self.tabBarController as! ChannelEpisodeTabBarController).session
        for channelUrl in self.session.channelUrls {
            DataManager.instance.loadChannel(channelUrl: channelUrl, channelProtocol: self)
        }
    }
    
    func didLoadChannel(channel: ChannelDto) {
        self.channels.append(channel)
        
        if(self.channels.count == self.session.channelUrls.count) {
            self.channels.sort(by: {$0.slug > $1.slug})
            self.tableView.reloadSections(IndexSet(arrayLiteral: 0), with: .automatic)
            
            for channel in self.channels {
                if(channel.driverOccurrenceUrls.count != 0) {
                    
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
                        let channel = self.channels.first(where: {$0.driverOccurrenceUrls.contains(where: {$0.split(separator: "/").last ?? "" == driver.uid})})
                        
                        self.tableView.reloadRows(at: [IndexPath(row: self.channels.firstIndex(where: {$0.uid == channel?.uid}) ?? 0, section: 0)], with: .none)
                    }
                }
            }
            
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(self.channels.isEmpty) {
            return 3
        }
        
        return self.channels.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.thumbnailTitleTableViewCell, for: indexPath) as! ThumbnailTitleTableViewCell

        cell.titleLabel.hideSkeletonAnimation()
        cell.thumbnailImageView.hideSkeletonAnimation()
        
        if(self.channels.isEmpty) {
            cell.titleLabel.linesCornerRadius = 5
            cell.titleLabel.showSkeletonAnimation()
            
            cell.thumbnailImageView.showSkeletonAnimation()
            
            cell.setAccessoryIcon(accessoryIcon: AccessoryIconType.None)
        }else{
            let currentItem = self.channels[indexPath.row]
            
            cell.titleLabel.text = currentItem.name
        
            cell.thumbnailImageView.image = UIImage(systemName: "video")
            cell.thumbnailImageView.tintColor = UIColor.systemGray
            cell.thumbnailImageView.contentMode = .scaleAspectFit
            
            if(currentItem.driverOccurrenceUrls.count != 0) {
                if let driver = DataManager.instance.drivers.first(where: {$0.uid == currentItem.driverOccurrenceUrls.first?.split(separator: "/").last ?? ""}) {
                    for imageUrl in driver.imageUrls {
                        if let image = DataManager.instance.images.first(where: {$0.uid == imageUrl.split(separator: "/").last ?? ""}) {
                            if(image.imageType == "Headshot") {
                                cell.loadImage(imageUrl: imageUrl)
                            }
                        }
                    }
                }
            }
            
            cell.setAccessoryIcon(accessoryIcon: AccessoryIconType.Disclosure)
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(self.channels.isEmpty) {
            return
        }
        
        let selectedChannel = self.channels[indexPath.row]
        self.openStream(channel: selectedChannel)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.session.sessionName
    }
    
    func openStream(channel: ChannelDto) {
        let tokenRequest = ChannelStreamTokenRequestDto(channelUrl: "/api/channels/" + channel.uid + "/")
        
        NetworkRouter.instance.channelStreamTokenRequest(streamTokenRequest: tokenRequest, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                    self.showAlert(title: NSLocalizedString("error", comment: ""), message: error.localizedDescription)
                case .success(let requestResult):
                    DispatchQueue.main.async {
                        if let url = URL(string: requestResult.tokenisedUrl) {
                            self.openPlayer(url: url)
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

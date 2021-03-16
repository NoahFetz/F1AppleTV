//
//  SideBarInfoViewController.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 09.03.21.
//

import UIKit
import Kingfisher

class SideBarInfoViewController: UIViewController {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: FontAdjustedUILabel!
    @IBOutlet weak var subtitleLabel: FontAdjustedUILabel!
    @IBOutlet weak var topAccessoryImageView: UIImageView!
    @IBOutlet weak var headerLabel: FontAdjustedUILabel!
    
    var contentItem: ContentItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupViewController()
    }
    
    func setupViewController() {
        let maskLayer = CAGradientLayer()
        let thumbnailFrame = CGRect(x: 0, y: 0, width: self.thumbnailImageView.bounds.width/3, height: self.thumbnailImageView.bounds.height)
        maskLayer.frame = thumbnailFrame
        maskLayer.shadowRadius = 40
        maskLayer.shadowPath = CGPath(roundedRect: thumbnailFrame.insetBy(dx: 100, dy: 100), cornerWidth: 50, cornerHeight: 50, transform: nil)
        maskLayer.shadowOpacity = 1
        maskLayer.shadowOffset = CGSize.zero
        maskLayer.shadowColor = UIColor.white.cgColor
        self.thumbnailImageView.layer.mask = maskLayer
        
        self.headerLabel.font = UIFont(name: "Formula1-Display-Regular", size: 54)
        self.headerLabel.text = ""
        self.headerLabel.backgroundShadow()
        
        self.titleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 64)
        self.titleLabel.text = ""
        self.titleLabel.backgroundShadow()
        
        self.subtitleLabel.font = UIFont(name: "Formula1-Display-Regular", size: 54)
        self.subtitleLabel.text = ""
        self.subtitleLabel.backgroundShadow()
        
        self.setupContentInfo()
        
        /*switch self.sideBarInfoType {
        case .Season:
            self.setupSeasonInfo()
            
        case .Event:
            self.setupEventInfo()
            
        case .Session:
            self.setupSessionInfo()
            
        case .Vod:
            self.setupVodInfo()
        }*/
    }
    
    func initialize(contentItem: ContentItem) {
        self.contentItem = contentItem
    }
    
    func setupContentInfo() {
        let contentItem = self.contentItem ?? ContentItem()
        
        self.titleLabel.text = contentItem.container.metadata?.title
        
        //Load flags and stuff if bundle seems to be a race session in a country
        if((contentItem.container.metadata?.emfAttributes?.meetingCountryKey?.isEmpty) ?? true) {
            self.headerLabel.text = contentItem.container.metadata?.emfAttributes?.globalMeetingName?.uppercased()
        }else{
            self.headerLabel.text = contentItem.container.metadata?.emfAttributes?.meetingCountryName?.uppercased()
            self.applyImage(countryId: contentItem.container.metadata?.emfAttributes?.meetingCountryKey ?? "", imageView: self.topAccessoryImageView)
            self.subtitleLabel.text = contentItem.container.metadata?.emfAttributes?.meetingDisplayDate ?? ""
        }
        
        if((contentItem.container.metadata?.pictureUrl?.isEmpty) ?? true) {
            self.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
        }else{
            self.applyImage(pictureId: contentItem.container.metadata?.pictureUrl ?? "", imageView: self.thumbnailImageView)
        }
    }
    
    func applyImage(pictureId: String, imageView: UIImageView) {
        var newApiUrlString = "https://ott.formula1.com/image-resizer/image/"
        newApiUrlString.append(pictureId)
        newApiUrlString.append("?w=3840&h=2160&q=HI&o=L")
        
        self.applyImage(imageUrl: newApiUrlString, imageView: imageView)
    }
    
    func applyImage(countryId: String, imageView: UIImageView) {
        let countryUrlString = "https://ott-img.formula1.com/countries/" + countryId + ".png"
        
        imageView.layer.cornerRadius = 5
        self.applyImage(imageUrl: countryUrlString, imageView: imageView)
    }
    
    func applyImage(imageUrl: String, imageView: UIImageView) {
        if let url = URL(string: imageUrl) {
            let processor = DownsamplingImageProcessor(size: imageView.bounds.size)
            imageView.kf.indicatorType = .activity
            imageView.kf.setImage(
                with: url,
                options: [
                    .processor(processor),
                    .scaleFactor(UIScreen.main.scale),
                    .transition(.fade(0.2)),
                    .cacheOriginalImage
                ], completionHandler:
                    {
                        result in
                        switch result {
                        case .success(let value):
                            print("Task done for: \(value.source.url?.absoluteString ?? "")")
                        case .failure(let error):
                            print("Job failed: \(error.localizedDescription)")
                        }
                    })
        }
    }
}

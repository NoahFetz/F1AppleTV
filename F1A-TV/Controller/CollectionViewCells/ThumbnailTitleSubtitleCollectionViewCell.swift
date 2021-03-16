//
//  ThumbnailTitleSubtitleCollectionViewCell.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 08.03.21.
//

import UIKit
import Kingfisher

class ThumbnailTitleSubtitleCollectionViewCell: BaseCollectionViewCell {
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var bottomContainerView: UIView!
    @IBOutlet weak var subtitleLabel: FontAdjustedUILabel!
    @IBOutlet weak var titleLabel: FontAdjustedUILabel!
    @IBOutlet weak var footerLabel: FontAdjustedUILabel!
    @IBOutlet weak var accessoryFooterLabel: FontAdjustedUILabel!
    @IBOutlet weak var accessoryOverlayImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.containerView.layer.cornerRadius = 10
        self.containerView.backgroundColor = ConstantsUtil.brandingItemColor
        self.bottomContainerView.backgroundColor = ConstantsUtil.brandingItemColor
        self.containerView.layer.masksToBounds = true
        
        self.setDefaultConfig()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.userInterfaceStyleChanged), name: .userInterfaceStyleChanged, object: nil)
    }
    
    func setDefaultConfig() {
        self.subtitleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 20)
        self.titleLabel.font = UIFont(name: "Titillium-Regular", size: 22)
        self.footerLabel.font = UIFont(name: "Titillium-Regular", size: 20)
        self.accessoryFooterLabel.font = UIFont(name: "Titillium-Regular", size: 20)
        
        self.subtitleLabel.text = ""
        self.titleLabel.text = ""
        self.footerLabel.text = ""
        self.accessoryFooterLabel.text = ""
        
        self.titleLabel.textAlignment = .natural
        
        self.accessoryOverlayImageView.image = nil
        self.thumbnailImageView.image = nil
    }
    
    func disableSkeleton() {
        self.titleLabel.hideSkeletonAnimation()
        self.subtitleLabel.hideSkeletonAnimation()
        self.footerLabel.hideSkeletonAnimation()
        self.accessoryFooterLabel.hideSkeletonAnimation()
        self.thumbnailImageView.hideSkeletonAnimation()
    }
    
    func configureSkeleton() {
        self.titleLabel.text = ""
        self.titleLabel.linesCornerRadius = 5
        self.titleLabel.showSkeletonAnimation()
        
        self.subtitleLabel.text = ""
        self.subtitleLabel.linesCornerRadius = 5
        self.subtitleLabel.showSkeletonAnimation()
        
        self.footerLabel.text = ""
        self.footerLabel.linesCornerRadius = 5
        self.footerLabel.showSkeletonAnimation()
        
        self.accessoryFooterLabel.text = ""
        self.accessoryFooterLabel.linesCornerRadius = 5
        self.accessoryFooterLabel.showSkeletonAnimation()
        
        self.thumbnailImageView.showSkeletonAnimation()
    }
    
    @objc func userInterfaceStyleChanged() {
        if(self.isFocused) {
            self.containerView.backgroundColor = .white
            self.bottomContainerView.backgroundColor = .white
            self.titleLabel.textColor = .black
            self.subtitleLabel.textColor = .black
            UIView.animate(withDuration: 0.2) {
                self.tableItemShadow()
                self.containerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                self.thumbnailImageView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            }
        }else{
            self.containerView.backgroundColor = ConstantsUtil.brandingItemColor
            self.bottomContainerView.backgroundColor = ConstantsUtil.brandingItemColor
            self.titleLabel.textColor = .white
            self.subtitleLabel.textColor = .white
            UIView.animate(withDuration: 0.2) {
                self.removeShadow()
                self.containerView.transform = .identity
                self.thumbnailImageView.transform = .identity
            }
        }
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        self.userInterfaceStyleChanged()
    }
    
    func applyImage(pictureId: String, imageView: UIImageView) {
        var newApiUrlString = "https://ott.formula1.com/image-resizer/image/"
        newApiUrlString.append(pictureId)
        newApiUrlString.append("?w=1920&h=1080&q=HI&o=L")
        
        self.applyImage(imageUrl: newApiUrlString, imageView: imageView)
    }
    
    func applyImage(countryId: String, imageView: UIImageView) {
        let countryUrlString = "https://ott-img.formula1.com/countries/" + countryId + ".png"
        
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

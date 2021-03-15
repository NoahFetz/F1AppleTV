//
//  ThumbnailTitleSubtitleCollectionViewCell.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 08.03.21.
//

import UIKit
import Kingfisher

class ThumbnailTitleSubtitleCollectionViewCell: BaseCollectionViewCell, ImageLoadedProtocol, NationLoadedProtocol, SeriesLoadedProtocol, TeamLoadedProtocol, AssetLoadedProtocol {
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
    
    func applyImage(imageInfo: ImageDto, imageView: UIImageView) {
        if let url = URL(string: imageInfo.url) {
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
    
    func didLoadImage(image: ImageDto) {
        if(image.url.contains("nation") || image.url.contains("team")){
            self.applyImage(imageInfo: image, imageView: self.accessoryOverlayImageView)
            return
        }
        
        self.applyImage(imageInfo: image, imageView: self.thumbnailImageView)
    }
    
    func loadImage(imageUrl: String) {
        if let imageInfo = DataManager.instance.images.first(where: {$0.uid == imageUrl.split(separator: "/").last ?? ""}) {
            self.didLoadImage(image: imageInfo)
        }else{
            DataManager.instance.loadImage(imageUrl: imageUrl, imageProtocol: self)
        }
    }
    
    func setNation(nationUrl: String) {
        if let nation = DataManager.instance.nations.first(where: {$0.uid == (nationUrl.split(separator: "/").last ?? "")}) {
            didLoadNation(nation: nation)
            return
        }
        
        DataManager.instance.loadNation(nationUrl: nationUrl, nationProtocol: self)
    }
    
    func didLoadNation(nation: NationDto) {
        self.subtitleLabel.text = nation.name.uppercased()
        if(!nation.imageUrls.isEmpty) {
            self.loadImage(imageUrl: nation.imageUrls.first ?? "")
        }
    }
    
    func setSeries(seriesUrl: String) {
        if let series = DataManager.instance.series.first(where: {$0.uid == (seriesUrl.split(separator: "/").last ?? "")}) {
            didLoadSeries(series: series)
            return
        }
        
        DataManager.instance.loadSeries(seriesUrl: seriesUrl, seriesProtocol: self)
    }
    
    func didLoadSeries(series: SeriesDto) {
        self.accessoryFooterLabel.text = series.name.uppercased()
        self.accessoryFooterLabel.textColor = SeriesType.fromIdentifier(identifier: Int(series.dataSourceId) ?? SeriesType().getIdentifier()).getColor()
    }
    
    func setTeam(teamUrl: String) {
        if let team = DataManager.instance.teams.first(where: {$0.uid == (teamUrl.split(separator: "/").last ?? "")}) {
            didLoadTeam(team: team)
            return
        }
        
        DataManager.instance.loadTeam(teamUrl: teamUrl, teamProtocol: self)
    }
    
    func didLoadTeam(team: TeamDto) {
        self.accessoryFooterLabel.text = team.name
        self.accessoryFooterLabel.textColor = team.getColor()
        
        self.thumbnailImageView.backgroundColor = team.getColor()
        
        if(!team.imageUrls.isEmpty) {
            self.loadImage(imageUrl: team.imageUrls.first ?? "")
        }
    }
    
    func setAsset(assetUrl: String) {
        if let asset = DataManager.instance.assets.first(where: {$0.uid == (assetUrl.split(separator: "/").last ?? "")}) {
            didLoadAsset(asset: asset)
            return
        }
        
        DataManager.instance.loadAsset(assetUrl: assetUrl, assetProtocol: self)
    }
    
    func didLoadAsset(asset: AssetDto) {
        self.subtitleLabel.text = TimeInterval(asset.durationInSeconds).stringFromTimeInterval()
    }
}

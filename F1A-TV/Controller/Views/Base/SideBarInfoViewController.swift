//
//  SideBarInfoViewController.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 09.03.21.
//

import UIKit
import Kingfisher

class SideBarInfoViewController: UIViewController, ImageLoadedProtocol, NationLoadedProtocol, SeriesLoadedProtocol {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: FontAdjustedUILabel!
    @IBOutlet weak var subtitleLabel: FontAdjustedUILabel!
    @IBOutlet weak var topAccessoryImageView: UIImageView!
    @IBOutlet weak var headerLabel: FontAdjustedUILabel!
    
    var sideBarInfoType = SideBarInfoType()
    var seasonInfo: SeasonDto?
    var eventInfo: EventDto?
    var sessionInfo: SessionDto?
    var vodInfo: VodDto?
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
    
    func initialize(seasonInfo: SeasonDto) {
        self.sideBarInfoType = .Season
        self.seasonInfo = seasonInfo
    }
    
    func initialize(eventInfo: EventDto) {
        self.sideBarInfoType = .Event
        self.eventInfo = eventInfo
    }
    
    func initialize(sessionInfo: SessionDto) {
        self.sideBarInfoType = .Session
        self.sessionInfo = sessionInfo
    }
    
    func initialize(vodInfo: VodDto) {
        self.sideBarInfoType = .Vod
        self.vodInfo = vodInfo
    }
    
    func setupSeasonInfo() {
        self.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
        self.titleLabel.text = self.seasonInfo?.name
    }
    
    func setupEventInfo() {
        let eventInfo = self.eventInfo ?? EventDto()
        
        if(eventInfo.imageUrls.isEmpty) {
            self.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
        }else{
            self.loadImage(imageUrl: eventInfo.imageUrls.first ?? "")
        }
        
        self.titleLabel.text = eventInfo.officialName.uppercased()
        self.subtitleLabel.text = eventInfo.startDate.getDayWithShortMonth().uppercased() + " - " + eventInfo.endDate.getDayWithShortMonth().uppercased()
        
        if(!eventInfo.nationUrl.isEmpty) {
            self.setNation(nationUrl: eventInfo.nationUrl)
        }
    }
    
    func setupSessionInfo() {
        let sessionInfo = self.sessionInfo ?? SessionDto()
        
        if(sessionInfo.imageUrls.isEmpty) {
            self.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
        }else{
            self.loadImage(imageUrl: sessionInfo.imageUrls.first ?? "")
        }
        
        self.titleLabel.text = sessionInfo.sessionName.uppercased()
        self.subtitleLabel.text = sessionInfo.startTime.distance(to: sessionInfo.endTime).stringFromTimeInterval() + " | " + (sessionInfo.nbcStatus?.uppercased() ?? "")
        
        if(!sessionInfo.seriesUrl.isEmpty) {
            self.setSeries(seriesUrl: sessionInfo.seriesUrl)
        }
    }
    
    func setupVodInfo() {
        self.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
        self.titleLabel.text = self.vodInfo?.name
    }
    
    func applyImage(imageInfo: ImageDto, imageView: UIImageView) {
        let url = URL(string: imageInfo.url)
        
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
    
    func didLoadImage(image: ImageDto) {
        if(image.url.contains("nation")){
            self.applyImage(imageInfo: image, imageView: self.topAccessoryImageView)
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
        self.headerLabel.text = nation.name.uppercased()
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
        self.headerLabel.text = series.name.uppercased()
        self.headerLabel.textColor = SeriesType.fromIdentifier(identifier: Int(series.dataSourceId) ?? SeriesType().getIdentifier()).getColor()
        self.topAccessoryImageView.backgroundColor = SeriesType.fromIdentifier(identifier: Int(series.dataSourceId) ?? SeriesType().getIdentifier()).getColor()
        self.topAccessoryImageView.layer.cornerRadius = 10
    }
}

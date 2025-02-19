//
//  SideBarInfoViewController.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 09.03.21.
//

import UIKit
import Kingfisher

class SideBarInfoViewController: BaseViewController {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: FontAdjustedUILabel!
    @IBOutlet weak var subtitleLabel: FontAdjustedUILabel!
    @IBOutlet weak var topAccessoryImageView: UIImageView!
    @IBOutlet weak var headerLabel: FontAdjustedUILabel!
    @IBOutlet weak var disclaimerLabel: FontAdjustedUILabel!
    @IBOutlet weak var bottomContentStackView: UIStackView!
    
    var contentItem: ContentItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupViewController()
    }
    
    func setupViewController() {
        let maskLayer = CAGradientLayer()
        let thumbnailFrame = CGRect(x: 0, y: 0, width: self.thumbnailImageView.bounds.width*0.33, height: self.thumbnailImageView.bounds.height)
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
        
        self.disclaimerLabel.font = UIFont(name: "Formula1-Display-Regular", size: 12)
        self.disclaimerLabel.text = "disclaimer".localizedString
        self.disclaimerLabel.backgroundShadow()
        
        self.setupContentInfo()
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
    
    func setSchedule(container: ContainerDto) {
        self.bottomContentStackView.arrangedSubviews.forEach({$0.removeFromSuperview()})
        
        for scheduleContainer in container.retrieveItems?.resultObj.containers ?? [ContainerDto]() {
            if(scheduleContainer.eventName != "ALL") {
                continue
            }
            
            for event in scheduleContainer.events?.sorted(by: {$0.metadata?.emfAttributes?.sessionStartDate?.value ?? 0 < $1.metadata?.emfAttributes?.sessionEndDate?.value ?? 0}) ?? [ContainerDto]() {
                
                let startDate = Date(milliseconds: event.metadata?.emfAttributes?.sessionStartDate?.value ?? Date().millisecondsSince1970)
                let endDate = Date(milliseconds: event.metadata?.emfAttributes?.sessionEndDate?.value ?? Date().millisecondsSince1970)
                let series = SeriesType.fromCapitalDisplayName(capitalDisplayName: event.properties?.first?.series ?? SeriesType().getCapitalDisplayName())
                
                let seriesLabel = UILabel()
                seriesLabel.font = UIFont(name: "Titillium-Bold", size: 28)
                seriesLabel.text = series.getShortDisplayName()
                seriesLabel.textColor = series.getColor()
                seriesLabel.backgroundShadow()
                seriesLabel.setContentHuggingPriority(UILayoutPriority(rawValue: 251), for: .horizontal)
                
                let scheduleItemTitleLabel = UILabel()
                scheduleItemTitleLabel.font = UIFont(name: "Titillium-Regular", size: 28)
                scheduleItemTitleLabel.text = event.metadata?.longDescription?.uppercased()
                scheduleItemTitleLabel.textColor = .white
                scheduleItemTitleLabel.backgroundShadow()
                
                let scheduleTimesLabel = UILabel()
                scheduleTimesLabel.font = UIFont(name: "Titillium-Regular", size: 28)
                var timesString = startDate.getShortDay()
                timesString.append(" " + startDate.getTimeAsString())
                timesString.append(" " + endDate.getTimeAsString())
                scheduleTimesLabel.text = timesString
                scheduleTimesLabel.textColor = .white
                scheduleTimesLabel.backgroundShadow()
                
                self.addViewsToStackView(views: [seriesLabel, scheduleItemTitleLabel, scheduleTimesLabel])
            }
        }
        
        //Add a spacer view to the bottom so the content spreads out correctly
        let spacerView = UIView()
        spacerView.backgroundColor = .clear
        spacerView.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 749), for: .horizontal)
        self.bottomContentStackView.addArrangedSubview(spacerView)
    }
    
    func addViewsToStackView(views: [UIView], spacing: CGFloat = 8) {
        let horizontalStack = UIStackView()
        horizontalStack.axis = .horizontal
        horizontalStack.spacing = spacing
        
        for view in views {
            horizontalStack.addArrangedSubview(view)
        }
        
        self.bottomContentStackView.addArrangedSubview(horizontalStack)
    }
    
    func applyImage(pictureId: String, imageView: UIImageView) {
        let width = Int(UIScreen.main.nativeBounds.width)
        let height = Int(UIScreen.main.nativeBounds.height)
        
        let imageUrl = "\(ConstantsUtil.imageResizerUrl)/\(pictureId)?w=\(width)&h=\(height)&q=HI&o=L"
        self.applyImage(imageUrl: imageUrl, imageView: imageView, crop: true)
    }
    
    func applyImage(countryId: String, imageView: UIImageView) {
        let countryUrlString = "https://ott-img.formula1.com/countries/" + countryId + ".png"
        
        imageView.layer.cornerRadius = 5
        self.applyImage(imageUrl: countryUrlString, imageView: imageView, crop: false)
    }
    
    func applyImage(imageUrl: String, imageView: UIImageView, crop: Bool) {
        if let url = URL(string: imageUrl) {
            
            var imageProcessor: ImageProcessor?
            if(crop){
                imageProcessor = CroppingImageProcessor(size: CGSize(width: imageView.bounds.size.width*0.33, height: imageView.bounds.size.height), anchor: CGPoint(x: 0, y: 0))
            }else{
                imageProcessor = DownsamplingImageProcessor(size: imageView.bounds.size)
            }
            
            if let processor = imageProcessor {
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
                            case .success(_):
                                break
    //                            print("Task done for: \(value.source.url?.absoluteString ?? "")")
                                
                            case .failure(let error):
                                print("Job failed: \(error.localizedDescription)")
                            }
                        })
            }
        }
    }
}

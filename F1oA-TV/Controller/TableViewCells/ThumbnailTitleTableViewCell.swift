//
//  ThumbnailTitleTableViewCell.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit
import Kingfisher

class ThumbnailTitleTableViewCell: UITableViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var accessoryImageView: UIImageView!
    
    var imageUrl = ""
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.thumbnailImageView.layer.cornerRadius = 5
        NotificationCenter.default.addObserver(self, selector: #selector(self.userInterfaceStyleChanged), name: .userInterfaceStyleChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.imageLoaded), name: .imageChanged, object: nil)
    }
    
    func didLoadImage(image: ImageDto) {
        if(image.imageType == "Headshot") {
            self.imageUrl = "/api/images/" + image.uid + "/"
            self.imageLoaded()
        }
    }
    
    @objc func imageLoaded() {
        if let imageInfo = DataManager.instance.images.first(where: {$0.uid == self.imageUrl.split(separator: "/").last ?? ""}) {
            
            let url = URL(string: imageInfo.url)
            
            let processor = DownsamplingImageProcessor(size: self.thumbnailImageView.bounds.size)
            self.thumbnailImageView.kf.indicatorType = .activity
            self.thumbnailImageView.kf.setImage(
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
        
    @objc func userInterfaceStyleChanged() {
        if(ConstantsUtil.darkStyle) {
            if(self.isFocused) {
                self.titleLabel.textColor = .black
            }else{
                self.titleLabel.textColor = .white
            }
        }else{
            self.titleLabel.textColor = .black
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        self.userInterfaceStyleChanged()
    }

    func setAccessoryIcon(accessoryIcon: AccessoryIconType) {
        self.accessoryImageView.image = accessoryIcon.getIcon()
    }
    
    func loadImage(imageUrl: String) {
        self.imageUrl = imageUrl
        self.imageLoaded()
    }
}

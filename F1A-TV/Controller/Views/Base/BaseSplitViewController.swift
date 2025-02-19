//
//  BaseSplitViewController.swift
//  F1A-TV
//
//  Created by Noah Fetz on 13.04.21.
//

import UIKit
import Kingfisher

class BaseSplitViewController: UISplitViewController {
    var backgroundImageView: UIImageView?
    
    var backgroundPictureId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.backgroundImageView = UIImageView(frame: self.view.bounds)
        self.backgroundImageView?.image = UIImage(named: "thumb_placeholder")
        self.backgroundImageView?.contentMode = .scaleAspectFill
        self.view.insertSubview(self.backgroundImageView ?? UIView(), at: 0)
        
        let blurEffect = UIBlurEffect(style: .extraDark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.alpha = 0.8
        blurEffectView.frame = self.view.bounds
        self.view.insertSubview(blurEffectView, at: 1)
        
        let maskLayer = CAGradientLayer()
        maskLayer.frame = self.view.bounds
        maskLayer.shadowRadius = 40
        maskLayer.shadowPath = CGPath(roundedRect: self.view.bounds.insetBy(dx: 100, dy: 100), cornerWidth: 50, cornerHeight: 50, transform: nil)
        maskLayer.shadowOpacity = 1
        maskLayer.shadowOffset = CGSize.zero
        maskLayer.shadowColor = UIColor.white.cgColor
        self.backgroundImageView?.layer.mask = maskLayer
        
        self.view.backgroundColor = .clear
        
        if let backgroundImageId = self.backgroundPictureId {
            self.applyImage(pictureId: backgroundImageId, imageView: self.backgroundImageView ?? UIImageView())
        }
    }
    
    func initialize(backgroundPictureId: String) {
        self.backgroundPictureId = backgroundPictureId
    }
    
    func applyImage(pictureId: String, imageView: UIImageView) {
        let width = Int(UIScreen.main.nativeBounds.width)
        let height = Int(UIScreen.main.nativeBounds.height)
        
        let imageUrl = "\(ConstantsUtil.imageResizerUrl)/\(pictureId)?w=\(width)&h=\(height)&q=HI&o=L"
        self.applyImage(imageUrl: imageUrl, imageView: imageView)
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
                        case .success(_):
                            break
//                            print("Task done for: \(value.source.url?.absoluteString ?? "")")
                        case .failure(let error):
                            print("Job failed: \(error.localizedDescription)")
                        }
                    })
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

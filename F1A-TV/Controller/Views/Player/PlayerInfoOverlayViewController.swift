//
//  PlayerInfoOverlayViewController.swift
//  F1A-TV
//
//  Created by Noah Fetz on 06.04.21.
//

import UIKit
import Kingfisher

class PlayerInfoOverlayViewController: BaseViewController {
    @IBOutlet weak var contentStackView: UIStackView!
    var topBarView: UIStackView?
    
    var contentItem: ContentItem?
    
    var backgroundImageView: UIImageView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupViewController()
    }
    
    func initialize(contentItem: ContentItem) {
        self.contentItem = contentItem
    }
    
    func setupViewController() {
        self.view.backgroundColor = .clear
        
        let swipeUpRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeUpRegognized))
        swipeUpRecognizer.direction = .up
        self.view.addGestureRecognizer(swipeUpRecognizer)
        
        self.setupTopBar()
        self.addContentToTopBar()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.applyImage(pictureId: self.contentItem?.container.metadata?.pictureUrl ?? "", imageView: self.backgroundImageView ?? UIImageView())
    }
    
    func setupTopBar() {
        self.contentStackView.arrangedSubviews.forEach({$0.removeFromSuperview()})
        
        self.topBarView = UIStackView()
        self.topBarView?.axis = .vertical
        self.topBarView?.backgroundColor = ConstantsUtil.brandingBackgroundColor
        self.topBarView?.layer.cornerRadius = 20
        NSLayoutConstraint.activate([
            (self.topBarView ?? UIView()).heightAnchor.constraint(equalToConstant: 500)
        ])
        self.topBarView?.backgroundShadow()
        self.contentStackView.addArrangedSubview(self.topBarView ?? UIView())
        
        let spaceTakingView = UIView()
        spaceTakingView.backgroundColor = .clear
        self.contentStackView.addArrangedSubview(spaceTakingView)
    }
    
    func addContentToTopBar() {
        self.topBarView?.arrangedSubviews.forEach({$0.removeFromSuperview()})
        
        self.backgroundImageView = UIImageView()
        self.backgroundImageView?.layer.cornerRadius = 20
        self.backgroundImageView?.contentMode = .scaleAspectFill
        self.topBarView?.addArrangedSubview(self.backgroundImageView ?? UIView())
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
    
    @objc func swipeUpRegognized() {
        self.dismiss(animated: true)
    }
}

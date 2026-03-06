//
//  ChannelPlayerCollectionViewCell.swift
//  F1A-TV
//
//  Created by Noah Fetz on 29.03.21.
//

import UIKit
import AVKit

class ChannelPlayerCollectionViewCell: BaseCollectionViewCell {
    @IBOutlet weak var playerContainerView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    var playerLayer: AVPlayerLayer?
    var loadingSpinner: UIActivityIndicatorView?
    
    var menuDisappearTimer: Timer!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        //self.playerContainerView.layer.cornerRadius = 10
        self.playerContainerView.layer.masksToBounds = true
        self.playerContainerView.backgroundColor = ConstantsUtil.brandingBackgroundColor
        self.userInterfaceStyleChanged()
        
        self.loadingSpinner = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        self.loadingSpinner?.center = self.playerContainerView.center
        self.loadingSpinner?.hidesWhenStopped = true
        self.playerContainerView.addSubview(self.loadingSpinner ?? UIView())
        
        self.titleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 40)
        self.titleLabel.backgroundShadow()
        self.titleLabel.isHidden = true
        self.subtitleLabel.font = UIFont(name: "Titillium-Bold", size: 48)
        self.subtitleLabel.backgroundShadow()
        self.subtitleLabel.isHidden = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.userInterfaceStyleChanged), name: .userInterfaceStyleChanged, object: nil)
    }
    
    func startActivityIndicator() {
        self.loadingSpinner?.center = self.playerContainerView.center
        self.loadingSpinner?.startAnimating()
    }
    
    func stopActivityIndicator() {
        self.loadingSpinner?.center = self.playerContainerView.center
        self.loadingSpinner?.stopAnimating()
    }
    
    func startPlayer(player: AVPlayer) {
        if(self.playerLayer != nil) {
            self.playerLayer?.removeFromSuperlayer()
        }
        
        self.playerLayer = AVPlayerLayer(player: player)
        
        // Force layout update before setting frame
        self.playerContainerView.setNeedsLayout()
        self.playerContainerView.layoutIfNeeded()
        
        self.playerLayer?.frame = self.playerContainerView.bounds
        self.playerLayer?.videoGravity = .resizeAspect
        self.playerContainerView.layer.insertSublayer(self.playerLayer ?? CALayer(), at: 0)
    }

    @objc func userInterfaceStyleChanged() {
        if(self.isFocused) {
            
        }else{
            
        }
    }
    
    //Set the layer's frame when subviews are being resized
    override func layoutSubviews() {
        super.layoutSubviews()
        self.playerLayer?.frame = self.playerContainerView.bounds
        self.loadingSpinner?.center = self.playerContainerView.center
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        self.userInterfaceStyleChanged()
        
        if(self.isFocused) {
            if(self.menuDisappearTimer != nil){
                self.menuDisappearTimer.invalidate()
                self.menuDisappearTimer = nil
            }
            
            self.showOptionsMenu()
            
            self.menuDisappearTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false, block: {timer in
                self.hideOptionsMenu()
            })
        }else{
            if(self.menuDisappearTimer != nil){
                self.menuDisappearTimer.invalidate()
                self.menuDisappearTimer = nil
            }
            
            self.hideOptionsMenu()
        }
    }
    
    func showOptionsMenu() {
        print("Showing options menu")
        
        self.tableItemShadow()
        
        self.playerContainerView.layer.borderColor = ConstantsUtil.brandingRed.cgColor
        
        let width = CABasicAnimation(keyPath: "borderWidth")
        width.fromValue = 0
        width.toValue = 3
        width.duration = 0.2
        width.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.playerContainerView.layer.borderWidth = 3
        
        self.playerContainerView.layer.add(width, forKey: nil)
        
        self.titleLabel.fadeIn()
        self.subtitleLabel.fadeIn()
        
        /*UIView.animate(withDuration: 0.2) {
            self.tableItemShadow()
            self.playerContainerView.transform = CGAffineTransform(scaleX: 1.005, y: 1.005)
        }*/
    }
    
    func hideOptionsMenu() {
        print("Hiding options menu")
        
        self.removeShadow()
        
        let width = CABasicAnimation(keyPath: "borderWidth")
        width.fromValue = 3
        width.toValue = 0
        width.duration = 0.2
        width.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.playerContainerView.layer.borderWidth = 0
        
        self.playerContainerView.layer.add(width, forKey: nil)
        
        self.titleLabel.fadeOut()
        self.subtitleLabel.fadeOut()
        
        /*UIView.animate(withDuration: 0.2) {
            self.removeShadow()
            self.playerContainerView.transform = .identity
        }*/
    }
}

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
    private var focusTimeout: DispatchWorkItem?
    private var selectionBadgeLabel: UILabel?
    var isControlTarget = false {
        didSet {
            self.updateSelectionAppearance()
        }
    }

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

        let selectionBadgeLabel = UILabel()
        selectionBadgeLabel.text = "SELECTED"
        selectionBadgeLabel.textColor = .black
        selectionBadgeLabel.backgroundColor = .white
        selectionBadgeLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        selectionBadgeLabel.textAlignment = .center
        selectionBadgeLabel.layer.cornerRadius = 6
        selectionBadgeLabel.clipsToBounds = true
        selectionBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        selectionBadgeLabel.isHidden = true
        self.playerContainerView.addSubview(selectionBadgeLabel)
        NSLayoutConstraint.activate([
            selectionBadgeLabel.topAnchor.constraint(equalTo: self.playerContainerView.topAnchor, constant: 22),
            selectionBadgeLabel.leadingAnchor.constraint(equalTo: self.playerContainerView.leadingAnchor, constant: 22),
            selectionBadgeLabel.widthAnchor.constraint(equalToConstant: 126),
            selectionBadgeLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
        self.selectionBadgeLabel = selectionBadgeLabel

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

    override func prepareForReuse() { super.prepareForReuse(); focusTimeout?.cancel(); hideOptionsMenu() }
    override func didMoveToWindow() { super.didMoveToWindow(); if window == nil { focusTimeout?.cancel(); hideOptionsMenu() } }
    deinit { focusTimeout?.cancel() }

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
        self.updateSelectionAppearance()
    }

    func updateSelectionAppearance() {
        focusTimeout?.cancel()
        if self.isFocused || self.isControlTarget {
            self.showOptionsMenu()
        } else {
            self.hideOptionsMenu()
        }
    }

    func showOptionsMenu() {
        focusTimeout?.cancel()
        if !isControlTarget {
            let work = DispatchWorkItem { [weak self] in guard let self, !self.isControlTarget else { return }; self.hideOptionsMenu() }
            focusTimeout = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: work)
        }
        self.tableItemShadow()

        let isEditing = self.isControlTarget
        self.playerContainerView.layer.borderColor = (isEditing ? ConstantsUtil.brandingRed : UIColor.white).cgColor

        let width = CABasicAnimation(keyPath: "borderWidth")
        width.fromValue = 0
        width.toValue = isEditing ? 6 : 4
        width.duration = 0.2
        width.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.playerContainerView.layer.borderWidth = isEditing ? 6 : 4

        self.playerContainerView.layer.add(width, forKey: nil)

        self.titleLabel.fadeIn()
        self.subtitleLabel.fadeIn()
        self.selectionBadgeLabel?.text = self.isControlTarget ? "EDITING" : "SELECTED"
        self.selectionBadgeLabel?.backgroundColor = self.isControlTarget ? ConstantsUtil.brandingRed : .white
        self.selectionBadgeLabel?.textColor = self.isControlTarget ? .white : .black
        self.selectionBadgeLabel?.fadeIn()

        /*UIView.animate(withDuration: 0.2) {
            self.tableItemShadow()
            self.playerContainerView.transform = CGAffineTransform(scaleX: 1.005, y: 1.005)
        }*/
    }

    func hideOptionsMenu() {
        focusTimeout?.cancel()
        self.removeShadow()

        let width = CABasicAnimation(keyPath: "borderWidth")
        width.fromValue = self.playerContainerView.layer.borderWidth
        width.toValue = 0
        width.duration = 0.2
        width.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.playerContainerView.layer.borderWidth = 0

        self.playerContainerView.layer.add(width, forKey: nil)

        self.titleLabel.fadeOut()
        self.subtitleLabel.fadeOut()
        self.selectionBadgeLabel?.fadeOut()

        /*UIView.animate(withDuration: 0.2) {
            self.removeShadow()
            self.playerContainerView.transform = .identity
        }*/
    }
}

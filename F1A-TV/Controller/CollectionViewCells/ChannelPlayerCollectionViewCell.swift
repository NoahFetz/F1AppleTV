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
    private enum SelectionAppearance { case hidden, selected, editing }
    private var selectionAppearance = SelectionAppearance.hidden
    var isControlTarget = false {
        didSet {
            if oldValue != isControlTarget { self.updateSelectionAppearance() }
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

    override func prepareForReuse() {
        super.prepareForReuse()
        isControlTarget = false
        hideOptionsMenu(animated: false)
        playerLayer?.player = nil; playerLayer?.removeFromSuperlayer(); playerLayer = nil
        titleLabel.text = nil; subtitleLabel.text = nil
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { hideOptionsMenu(animated: false) }
        else { updateSelectionAppearance() }
    }
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
        setSelectionAppearance(isControlTarget ? .editing : .selected)
    }

    func hideOptionsMenu(animated: Bool = true) {
        focusTimeout?.cancel()
        focusTimeout = nil
        setSelectionAppearance(.hidden, animated: animated)
    }

    private func setSelectionAppearance(_ appearance: SelectionAppearance, animated: Bool = true) {
        // Remote presses and focus updates may arrive for every control movement.
        // Refresh the timeout above, but animate only an actual selection transition.
        guard selectionAppearance != appearance || !animated else { return }
        selectionAppearance = appearance
        let visible = appearance != .hidden
        let editing = appearance == .editing
        let border = playerContainerView.layer
        let oldWidth = border.presentation()?.borderWidth ?? border.borderWidth
        let targetWidth: CGFloat = visible ? (editing ? 6 : 4) : 0
        border.removeAnimation(forKey: "selectionBorder")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        border.borderColor = (editing ? ConstantsUtil.brandingRed : UIColor.white).cgColor
        border.borderWidth = targetWidth
        CATransaction.commit()
        if animated && oldWidth != targetWidth {
            let animation = CABasicAnimation(keyPath: "borderWidth")
            animation.fromValue = oldWidth
            animation.toValue = targetWidth
            animation.duration = 0.2
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            border.add(animation, forKey: "selectionBorder")
        }

        if visible { tableItemShadow() } else { removeShadow() }
        selectionBadgeLabel?.text = editing ? "EDITING" : "SELECTED"
        selectionBadgeLabel?.backgroundColor = editing ? ConstantsUtil.brandingRed : .white
        selectionBadgeLabel?.textColor = editing ? .white : .black
        let labels = [titleLabel, subtitleLabel, selectionBadgeLabel].compactMap { $0 }
        if visible { labels.forEach { $0.isHidden = false } }
        let changes = { labels.forEach { $0.alpha = visible ? 1 : 0 } }
        let completion: (Bool) -> Void = { [weak self] _ in
            guard self?.selectionAppearance == .hidden else { return }
            labels.forEach { $0.isHidden = true }
        }
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: changes, completion: completion)
        } else {
            labels.forEach { $0.layer.removeAllAnimations() }
            changes()
            completion(true)
        }
    }
}

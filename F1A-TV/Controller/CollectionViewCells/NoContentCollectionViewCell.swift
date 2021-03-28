//
//  NoContentCollectionViewCell.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 08.03.21.
//

import UIKit

class NoContentCollectionViewCell: BaseCollectionViewCell {
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var centerLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.containerView.layer.cornerRadius = 10
        self.userInterfaceStyleChanged()
        
        self.centerLabel.font = UIFont(name: "Formula1-Display-Bold", size: 40)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.userInterfaceStyleChanged), name: .userInterfaceStyleChanged, object: nil)
    }

    @objc func userInterfaceStyleChanged() {
        if(self.isFocused) {
            self.containerView.backgroundColor = .white
            self.centerLabel.textColor = .black
            UIView.animate(withDuration: 0.2) {
                self.tableItemShadow()
                self.containerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            }
        }else{
            self.containerView.backgroundColor = ConstantsUtil.brandingItemColor
            self.centerLabel.textColor = .white
            UIView.animate(withDuration: 0.2) {
                self.removeShadow()
                self.containerView.transform = .identity
            }
        }
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        self.userInterfaceStyleChanged()
    }
}

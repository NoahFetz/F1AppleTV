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
        if(ConstantsUtil.darkStyle) {
            if(self.isFocused) {
                self.containerView.backgroundColor = .white
                self.centerLabel.textColor = .black
            }else{
                self.containerView.backgroundColor = ConstantsUtil.brandingBackgroundColor
                self.centerLabel.textColor = .white
            }
        }else{
            self.containerView.backgroundColor = .white
            self.centerLabel.textColor = .black
        }
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        self.userInterfaceStyleChanged()
    }
}

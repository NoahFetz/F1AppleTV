//
//  NoContentTableViewCell.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 07.03.21.
//

import UIKit

class NoContentTableViewCell: BaseTableViewCell {
    @IBOutlet weak var centerLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        NotificationCenter.default.addObserver(self, selector: #selector(self.userInterfaceStyleChanged), name: .userInterfaceStyleChanged, object: nil)
    }

    @objc func userInterfaceStyleChanged() {
        if(ConstantsUtil.darkStyle) {
            if(self.isFocused) {
                self.centerLabel.textColor = .black
            }else{
                self.centerLabel.textColor = .white
            }
        }else{
            self.centerLabel.textColor = .black
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        self.userInterfaceStyleChanged()
    }
}

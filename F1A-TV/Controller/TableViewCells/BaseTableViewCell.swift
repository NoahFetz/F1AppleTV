//
//  BaseTableViewCell.swift
//  F1A-TV
//
//  Created by Noah Fetz on 06.04.21.
//

import UIKit

class BaseTableViewCell: UITableViewCell {

    var transformScale: CGFloat = 0.995
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.accessoryType = .none
        self.selectionStyle = .none
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        self.highlight(down: highlighted)
    }
    
    func pulsate() {
        if(self.layer.animation(forKey: "pulsate") == nil){
            let pulse = CASpringAnimation(keyPath: "transform.scale")
            pulse.duration = 2
            pulse.fromValue = 0.98
            pulse.toValue = 1.0
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.initialVelocity = 0.15
            pulse.damping = 2.5
            self.layer.add(pulse, forKey: "pulsate")
        }
    }
    
    func highlight(down: Bool) {
    }
    
    func shrink(down: Bool) {
        UIView.animate(withDuration: 0.2) {
            if(down){
                self.transform = CGAffineTransform(scaleX: self.transformScale, y: self.transformScale)
            }else{
                self.transform = .identity
            }
        }
    }
}

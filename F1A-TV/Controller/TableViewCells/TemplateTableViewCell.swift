//
//  TemplateTableViewCell.swift
//  F1A-TV
//
//  Created by Noah Fetz on 06.04.21.
//

import UIKit

class TemplateTableViewCell: BaseTableViewCell {
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var contentStackView: UIStackView!
    
    var unselectedBackgroundColor = ConstantsUtil.brandingItemColor
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.containerView.layer.cornerRadius = 10
        self.userInterfaceStyleChanged()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.userInterfaceStyleChanged), name: .userInterfaceStyleChanged, object: nil)
    }
    
    func addViewsToStackView(views: [UIView], spacing: CGFloat = 8) {
        let horizontalStack = UIStackView()
        horizontalStack.axis = .horizontal
        horizontalStack.spacing = spacing
        
        for view in views {
            horizontalStack.addArrangedSubview(view)
        }
        
        self.contentStackView.addArrangedSubview(horizontalStack)
    }
    
    func addTableItemToStackView(title: String, detail: String) {
        let horizontalStack = UIStackView()
        horizontalStack.axis = .horizontal
        horizontalStack.spacing = 8
        
        let titleLabel = UILabel()
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5
        titleLabel.text = title
        titleLabel.font = UIFont(name: "Titillium-Bold", size: 32)
        titleLabel.setContentHuggingPriority(UILayoutPriority(rawValue: 250), for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 750), for: .horizontal)
        horizontalStack.addArrangedSubview(titleLabel)
        
        let detailLabel = UILabel()
        detailLabel.numberOfLines = 0
        detailLabel.textAlignment = .right
        detailLabel.text = detail
        detailLabel.font = UIFont(name: "Titillium-Regular", size: 32)
        detailLabel.setContentHuggingPriority(UILayoutPriority(rawValue: 251), for: .horizontal)
        detailLabel.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 751), for: .horizontal)
        horizontalStack.addArrangedSubview(detailLabel)
        
        self.contentStackView.addArrangedSubview(horizontalStack)
    }
    
    @objc func userInterfaceStyleChanged() {
        if(self.isFocused) {
            self.containerView.backgroundColor = .white
            
            self.setAllSubLabelsTextColorTo(view: self.contentStackView, color: .black)
            
            UIView.animate(withDuration: 0.2) {
                self.tableItemShadow()
            }
        }else{
            self.containerView.backgroundColor = self.unselectedBackgroundColor
            
            self.setAllSubLabelsTextColorTo(view: self.contentStackView, color: .white)
            
            UIView.animate(withDuration: 0.2) {
                self.removeShadow()
            }
        }
    }
    
    func setAllSubLabelsTextColorTo(view: UIStackView, color: UIColor) {
        for subview in view.arrangedSubviews {
            if let label = subview as? UILabel {
                label.textColor = color
                continue
            }
            
            if let subStackView = subview as? UIStackView {
                self.setAllSubLabelsTextColorTo(view: subStackView, color: color)
                continue
            }
        }
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        self.userInterfaceStyleChanged()
    }
}

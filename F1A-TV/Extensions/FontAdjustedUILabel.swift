//
//  FontAdjustedUILabel.swift
//  F1A-TV
//
//  Created by Noah Fetz on 11.03.21.
//

import UIKit

class FontAdjustedUILabel: UILabel {
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        let addedHeight = font.pointSize * 0.3
        return CGSize(width: size.width, height: size.height + addedHeight)
    }
}

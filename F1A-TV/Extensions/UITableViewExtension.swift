//
//  UITableViewExtension.swift
//  F1A-TV
//
//  Created by Noah Fetz on 25.08.22.
//

import UIKit

extension UITableView {
    func reloadDataWithDissolve() {
        UIView.transition(with: self, duration: 0.1, options: .transitionCrossDissolve, animations: {self.reloadData()}, completion: nil)
    }
}

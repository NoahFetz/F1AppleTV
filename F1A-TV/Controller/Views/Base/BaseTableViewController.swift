//
//  BaseTableViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit

class BaseTableViewController: UITableViewController {
    var tableHeaderTextLabels = [Int:UILabel]()
    var tableFooterTextLabels = [Int:UILabel]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.registerTableViewCells()
    }
    
    func registerTableViewCells() {
        self.registerCell(identifier: ConstantsUtil.templateTableViewCell)
        self.registerCell(identifier: ConstantsUtil.noContentTableViewCell)
        self.tableView.register(UINib(nibName: ConstantsUtil.templateTableViewCell, bundle: nil), forCellReuseIdentifier: ConstantsUtil.templateTableViewCell)
        self.tableView.register(UINib(nibName: ConstantsUtil.noContentTableViewCell, bundle: nil), forCellReuseIdentifier: ConstantsUtil.noContentTableViewCell)
    }
    
    func registerCell(identifier: String) {
        self.tableView.register(UINib(nibName: identifier, bundle: nil), forCellReuseIdentifier: identifier)
    }
    
    func setTitle(title: String) {
        self.navigationItem.title = title
    }
    
    func setBackgroundImage(image: UIImage) {
        let backgroundImageView = UIImageView(frame: self.tableView.frame)
        backgroundImageView.image = image
        backgroundImageView.alpha = 0.7
        self.tableView.backgroundView = backgroundImageView
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        
        //Set the title text
        header.textLabel?.font = UIFont.boldSystemFont(ofSize: 54)
        header.textLabel?.textColor = .white
        header.textLabel?.text = self.tableView(self.tableView, titleForHeaderInSection: section)
        self.tableHeaderTextLabels[section] = header.textLabel
    }
    
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard let footer = view as? UITableViewHeaderFooterView else { return }
        
        //Set the title text
        footer.textLabel?.font = UIFont.systemFont(ofSize: 18)
        footer.textLabel?.textColor = .white
        footer.textLabel?.numberOfLines = 0
        footer.textLabel?.text = self.tableView(self.tableView, titleForFooterInSection: section)
        self.tableFooterTextLabels[section] = footer.textLabel
    }
    
    func getRoundedCorners(indexPath: IndexPath) -> UIRectCorner {
        var corners = UIRectCorner()
        
        //Rounding corners of first and last cell
        if(indexPath.row == 0){
            corners.update(with: [.topLeft, .topRight])
        }
        if(indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1){
            corners.update(with: [.bottomLeft, .bottomRight])
        }
        return corners
    }
    
    func getDefaultNoContentTableViewCell(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> NoContentTableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.noContentTableViewCell, for: indexPath) as! NoContentTableViewCell
        cell.centerLabel.text = "No content found"
        return cell
    }
}

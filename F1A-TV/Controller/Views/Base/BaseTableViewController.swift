//
//  BaseTableViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit

class BaseTableViewController: UITableViewController {

    var tableHeaderActivitySpinner = [Int:UIActivityIndicatorView]()
    var tableHeaderTextLabels = [Int:UILabel]()
    var tableFooterTextLabels = [Int:UILabel]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.registerTableViewCells()
    }
    
    func registerTableViewCells() {
        self.tableView.register(UINib(nibName: ConstantsUtil.thumbnailTitleTableViewCell, bundle: nil), forCellReuseIdentifier: ConstantsUtil.thumbnailTitleTableViewCell)
        self.tableView.register(UINib(nibName: ConstantsUtil.thumbnailTitleSubtitleTableViewCell, bundle: nil), forCellReuseIdentifier: ConstantsUtil.thumbnailTitleSubtitleTableViewCell)
        self.tableView.register(UINib(nibName: ConstantsUtil.noContentTableViewCell, bundle: nil), forCellReuseIdentifier: ConstantsUtil.noContentTableViewCell)
        self.tableView.register(UINib(nibName: ConstantsUtil.thumbnailBackgroundTableViewCell, bundle: nil), forCellReuseIdentifier: ConstantsUtil.thumbnailBackgroundTableViewCell)
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
        header.textLabel?.text = self.tableView(self.tableView, titleForHeaderInSection: section)
        self.tableHeaderTextLabels[section] = header.textLabel
        
        //Add a spinner to every section
        let headerSpinner = UIActivityIndicatorView(frame: CGRect(x: (header.textLabel?.intrinsicContentSize.width)! + header.frame.minX + 24, y: 27, width: 20, height: 20))
        
        headerSpinner.style = .medium
        
        headerSpinner.hidesWhenStopped = true
        header.addSubview(headerSpinner)
        self.tableHeaderActivitySpinner[section] = headerSpinner
    }
    
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        
        //Set the title text
        header.textLabel?.font = UIFont.systemFont(ofSize: 54)
        header.textLabel?.text = self.tableView(self.tableView, titleForFooterInSection: section)
        self.tableFooterTextLabels[section] = header.textLabel
    }
    
    func startHeaderSpinner(section: Int) {
        DispatchQueue.main.async {
            self.tableHeaderActivitySpinner[section]?.startAnimating()
        }
    }
    
    func stopHeaderSpinner(section: Int) {
        DispatchQueue.main.async {
            self.tableHeaderActivitySpinner[section]?.stopAnimating()
        }
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
}

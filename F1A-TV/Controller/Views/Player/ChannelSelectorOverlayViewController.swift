//
//  ChannelSelectorOverlayViewController.swift
//  F1A-TV
//
//  Created by Noah Fetz on 06.04.21.
//

import UIKit

class ChannelSelectorOverlayViewController: BaseViewController {
    @IBOutlet weak var contentStackView: UIStackView!
    var sideBarView: UIStackView?
    var channelsTableView: UITableView?
    
    var channelItems = [ContentItem]()
    var selectionReturnProtocol: ChannelSelectionProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupViewController()
    }
    
    func setupViewController() {
        self.view.backgroundColor = .clear
        
        let swipeRightRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeRightRegognized))
        swipeRightRecognizer.direction = .right
        self.view.addGestureRecognizer(swipeRightRecognizer)
        
        // Add menu button gesture to dismiss (useful in simulator)
        let menuGesture = UITapGestureRecognizer(target: self, action: #selector(self.menuPressed))
        menuGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        self.view.addGestureRecognizer(menuGesture)
        
        self.setupSideBar()
        self.addContentToSideBar()
    }
    
    func initialize(channelItems: [ContentItem], selectionReturnProtocol: ChannelSelectionProtocol) {
        self.channelItems = channelItems
        self.selectionReturnProtocol = selectionReturnProtocol
    }
    
    func setupSideBar() {
        self.contentStackView.arrangedSubviews.forEach({$0.removeFromSuperview()})
        
        let spaceTakingView = UIView()
        spaceTakingView.backgroundColor = .clear
        self.contentStackView.addArrangedSubview(spaceTakingView)
        
        let blurBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        blurBackgroundView.layer.cornerRadius = 20
        blurBackgroundView.clipsToBounds = true
        NSLayoutConstraint.activate([
            blurBackgroundView.widthAnchor.constraint(equalToConstant: 500)
        ])
        
        self.sideBarView = UIStackView()
        self.sideBarView?.axis = .vertical
        self.sideBarView?.spacing = 8
        self.sideBarView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.sideBarView?.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        self.sideBarView?.isLayoutMarginsRelativeArrangement = true
        self.sideBarView?.backgroundShadow()
        
        blurBackgroundView.contentView.addSubview(self.sideBarView ?? UIView())
        self.contentStackView.addArrangedSubview(blurBackgroundView)
    }
    
    func addContentToSideBar() {
        self.sideBarView?.arrangedSubviews.forEach({$0.removeFromSuperview()})
        
        let titleLabel = UILabel()
        titleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 40)
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.text = "multiplayer_channel_selector_add_channel_title".localizedString
        titleLabel.textColor = .white
        self.sideBarView?.addArrangedSubview(titleLabel)
        
        self.channelsTableView = UITableView(frame: .zero, style: .plain)
        self.channelsTableView?.delegate = self
        self.channelsTableView?.dataSource = self
        self.channelsTableView?.register(UINib(nibName: ConstantsUtil.templateTableViewCell, bundle: nil), forCellReuseIdentifier: ConstantsUtil.templateTableViewCell)
        self.sideBarView?.addArrangedSubview(self.channelsTableView ?? UIView())
    }
    
    @objc func swipeRightRegognized() {
        self.dismiss(animated: true)
    }
    
    @objc func menuPressed() {
        self.dismiss(animated: true)
    }
}

extension ChannelSelectorOverlayViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.channelItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConstantsUtil.templateTableViewCell, for: indexPath) as! TemplateTableViewCell
        
        cell.contentStackView.arrangedSubviews.forEach({$0.removeFromSuperview()})
        
        cell.unselectedBackgroundColor = .clear
        cell.userInterfaceStyleChanged()
        
        let currentItem = self.channelItems[indexPath.row]
        
        switch currentItem.container.metadata?.channelType {
        case .MainFeed, .AdditionalFeed:
            let feedTitleLabel = UILabel()
            feedTitleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 32)
            feedTitleLabel.textColor = .white
            feedTitleLabel.text = currentItem.container.metadata?.title
            
            cell.addViewsToStackView(views: [feedTitleLabel])
            
        case .OnBoardCamera:
            let onBoardStream = currentItem.container.metadata?.additionalStreams?.first ?? AdditionalStreamDto()
            
            let racingNumberTitleLabel = UILabel()
            racingNumberTitleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 32)
            racingNumberTitleLabel.textColor = .white
            racingNumberTitleLabel.text = String(onBoardStream.racingNumber)
            racingNumberTitleLabel.setContentHuggingPriority(UILayoutPriority(rawValue: 251), for: .horizontal)
            
            let racingColorView = UIView()
            racingColorView.backgroundColor = UIColor(rgb: onBoardStream.hex ?? "#00000000")
            NSLayoutConstraint.activate([
                racingColorView.widthAnchor.constraint(equalToConstant: 16)
            ])
            
            let driverTitleLabel = UILabel()
            driverTitleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 32)
            driverTitleLabel.textColor = .white
            driverTitleLabel.text = String(onBoardStream.title)
            
            cell.addViewsToStackView(views: [racingNumberTitleLabel, racingColorView, driverTitleLabel], spacing: 16)
            
        default:
            print("Shouldn't happen (Hopefully ^^)")
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedItem = self.channelItems[indexPath.row]
        self.selectionReturnProtocol?.didSelectChannel(channelItem: selectedItem)
    }
}

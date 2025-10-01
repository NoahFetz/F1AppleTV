//
//  PageOverviewCollectionViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit

class PageOverviewCollectionViewController: BaseCollectionViewController, UICollectionViewDelegateFlowLayout, ContentPageLoadedProtocol, ContentVideoLoadedProtocol {
    var contentSections: [ContentSection]?
    
    var pageUri: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupCollectionView()
    }
    
    func setupCollectionView() {
    }
    
    func initialize(pageUri: String) {
        self.pageUri = pageUri
    }
    
    func initialize(contentSections: [ContentSection]) {
        self.contentSections = contentSections
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if let pageUri = self.pageUri {
            DataManager.instance.loadContentPage(pageUri: pageUri, contentPageProtocol: self)
        }
    }
    
    func didLoadContentPage(contentPage: ResultObjectDto) {
        var localSections = [ContentSection]()
        for contentContainer in contentPage.containers ?? [ContainerDto]() {
            //Some sub pages don't have sections, so we put them all into one big section
            if(ContainerLayoutType.fromIdentifier(identifier: contentContainer.layout ?? "") == .ContentItem) {
                if(localSections.isEmpty){
                    var section = ContentSection()
                    section.layoutType = ContainerLayoutType.fromIdentifier(identifier: contentContainer.layout ?? "")
                    section.container = contentContainer
                    localSections.append(section)
                }
                
                if var firstSection = localSections.first {
                    localSections.remove(at: 0)
                    firstSection.items.append(self.getContentItem(itemContainer: contentContainer))
                    localSections.insert(firstSection, at: 0)
                }
                
                continue
            }
            
            if let contentSection = self.getContentSection(contentContainer: contentContainer) {
                localSections.append(contentSection)
            }
        }
        
        self.contentSections = localSections
        self.collectionView.reloadData()
    }
    
    func getContentSection(contentContainer: ContainerDto) -> ContentSection? {
        switch ContainerLayoutType.fromIdentifier(identifier: contentContainer.layout ?? "") {
        case .Hero:
            var heroSection = ContentSection()
            
            heroSection.layoutType = ContainerLayoutType.fromIdentifier(identifier: contentContainer.layout ?? "")
            heroSection.container = contentContainer
            heroSection.title = "featured_title".localizedString
            
            for itemContainer in contentContainer.retrieveItems?.resultObj.containers ?? [ContainerDto]() {
                heroSection.items.append(self.getContentItem(itemContainer: itemContainer))
            }
            
            return heroSection
            
        case .HorizontalThumbnail, .VerticalThumbnail, .VerticalSimplePoster:
            var thumbnailSection = ContentSection()
            
            thumbnailSection.layoutType = ContainerLayoutType.fromIdentifier(identifier: contentContainer.layout ?? "")
            thumbnailSection.container = contentContainer
            thumbnailSection.title = contentContainer.metadata?.label ?? ""
            
            for itemContainer in contentContainer.retrieveItems?.resultObj.containers ?? [ContainerDto]() {
                thumbnailSection.items.append(self.getContentItem(itemContainer: itemContainer))
            }
            
            return thumbnailSection
            
        case .Title, .Subtitle:
            if let title = contentContainer.metadata?.label {
                if(!title.isEmpty){
                    var titleSection = ContentSection()
                    
                    titleSection.layoutType = ContainerLayoutType.fromIdentifier(identifier: contentContainer.layout ?? "")
                    titleSection.container = contentContainer
                    titleSection.title = contentContainer.metadata?.label ?? ""
                    
                    return titleSection
                }
            }
            
            return nil
            
        case .Schedule:
            if let sideBarController = self.splitViewController?.viewControllers.first as? SideBarInfoViewController {
                sideBarController.setSchedule(container: contentContainer)
            }
            
            return nil
            
        case .GpBanner:
            //TODO: Do something interesting with this layout in the future...
            return nil
            
        default:
            print("Not recognizing this layout")
            return nil
        }
    }
    
    func getContentItem(itemContainer: ContainerDto) -> ContentItem {
        return ContentItem(objectType: ContentObjectType.fromIdentifier(identifier: itemContainer.metadata?.contentType ?? ContentObjectType().getIdentifier()), container: itemContainer)
    }
    
    // MARK: UICollectionViewDataSource
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.contentSections?.count ?? 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        var additionalItems = 0
        
        if let actionUrl = self.contentSections?[section].container.actions?.first?.uri {
            if(!actionUrl.isEmpty) {
                additionalItems += 1
            }
        }
        
        return (self.contentSections?[section].items.count ?? 12) + additionalItems
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let actionUrl = self.contentSections?[indexPath.section].container.actions?.first?.uri {
            if(!actionUrl.isEmpty && indexPath.row >= (self.contentSections?[indexPath.section].items.count ?? Int.max)) {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ConstantsUtil.noContentCollectionViewCell, for: indexPath) as! NoContentCollectionViewCell
                
                cell.centerLabel.text = "view_all".localizedString
                
                return cell
            }
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ConstantsUtil.thumbnailTitleSubtitleCollectionViewCell, for: indexPath) as! ThumbnailTitleSubtitleCollectionViewCell
        
        cell.setDefaultConfig()
        cell.disableSkeleton()
        
        if(self.contentSections == nil) {
            cell.configureSkeleton()
        }else{
            let currentItem = self.contentSections?[indexPath.section].items[indexPath.row] ?? ContentItem()
            
            switch currentItem.objectType {
            case .Video:
                cell.titleLabel.text = currentItem.container.metadata?.title
                cell.titleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 20)
                var subtitleString = currentItem.container.metadata?.uiDuration
                subtitleString?.append(" | ")
                subtitleString?.append(currentItem.container.metadata?.contentSubtype ?? "")
                cell.subtitleLabel.text = subtitleString
                cell.subtitleLabel.font = UIFont(name: "Titillium-Regular", size: 20)
                
                cell.accessoryFooterLabel.text = ""
                if let property = currentItem.container.properties?.first {
                    let series = SeriesType.fromCapitalDisplayName(capitalDisplayName: property.series)
                    cell.accessoryFooterLabel.text = series.getShortDisplayName()
                    cell.accessoryFooterLabel.textColor = series.getColor()
                }
                
                if((currentItem.container.metadata?.pictureUrl?.isEmpty) ?? true) {
                    cell.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
                }else{
                    cell.applyImage(pictureId: currentItem.container.metadata?.pictureUrl ?? "", imageView: cell.thumbnailImageView)
                }
                
            case .Bundle:
                cell.titleLabel.text = currentItem.container.metadata?.title
                
                //Load flags and stuff if bundle seems to be a race session in a country
                if((currentItem.container.metadata?.emfAttributes?.meetingCountryKey?.isEmpty) ?? true) {
                    cell.subtitleLabel.text = currentItem.container.metadata?.emfAttributes?.globalMeetingName?.uppercased()
                }else{
                    cell.subtitleLabel.text = currentItem.container.metadata?.emfAttributes?.meetingCountryName?.uppercased()
                    cell.applyImage(countryId: currentItem.container.metadata?.emfAttributes?.meetingCountryKey ?? "", imageView: cell.accessoryOverlayImageView)
                    cell.footerLabel.text = currentItem.container.metadata?.emfAttributes?.meetingDisplayDate ?? ""
                }
                
                if((currentItem.container.metadata?.pictureUrl?.isEmpty) ?? true) {
                    cell.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
                }else{
                    cell.applyImage(pictureId: currentItem.container.metadata?.pictureUrl ?? "", imageView: cell.thumbnailImageView)
                }
                
            case .Launcher:
                cell.titleLabel.font = UIFont(name: "Titillium-Bold", size: 32)
                cell.titleLabel.textAlignment = .center
                
                cell.titleLabel.text = currentItem.container.metadata?.longDescription
                
                if((currentItem.container.metadata?.pictureUrl?.isEmpty) ?? true) {
                    cell.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
                }else{
                    cell.applyImage(pictureId: currentItem.container.metadata?.pictureUrl ?? "", imageView: cell.thumbnailImageView)
                }
                
            default:
                print("No content")
            }
        }
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if(self.contentSections == nil) {
            if let pageUri = self.pageUri {
                DataManager.instance.loadContentPage(pageUri: pageUri, contentPageProtocol: self)
            }
            return
        }
        
        //Open view all
        if var currentSection = self.contentSections?[indexPath.section] {
            if let actionUrl = currentSection.container.actions?.first?.uri {
                if(!actionUrl.isEmpty && indexPath.row >= currentSection.items.count) {
                    if let actionUrl = currentSection.container.actions?.first?.uri {
                        let detailContentItem = ContentItem(objectType: .Bundle, container: currentSection.container)
                        
                        let sideInfoVc = self.getViewControllerWith(viewIdentifier: ConstantsUtil.sideBarInfoViewController) as! SideBarInfoViewController
                        currentSection.container.metadata?.title = currentSection.title
                        sideInfoVc.initialize(contentItem: detailContentItem)
                        
                        let subPageVc = self.getViewControllerWith(viewIdentifier: ConstantsUtil.pageOverviewCollectionViewController) as! PageOverviewCollectionViewController
                        subPageVc.initialize(pageUri: actionUrl)
                        
                        let splitVc = BaseSplitViewController()
                        if(!((detailContentItem.container.metadata?.pictureUrl?.isEmpty) ?? true)) {
                            splitVc.initialize(backgroundPictureId: detailContentItem.container.metadata?.pictureUrl ?? "")
                        }
                        splitVc.viewControllers = [sideInfoVc, subPageVc]
                        
                        self.presentFullscreen(viewController: splitVc)
                        
                        return
                    }
                }
            }
        }
        
        let currentItem = self.contentSections?[indexPath.section].items[indexPath.row] ?? ContentItem()
        
        switch currentItem.objectType {
        case .Video:
            if(currentItem.container.metadata?.emfAttributes?.videoType == "meetingSession"){
                DataManager.instance.loadContentVideo(videoId: String(currentItem.container.metadata?.contentId ?? 0), contentVideoProtocol: self)
                
                return
            }
            
            //Play the video
            if(!CredentialHelper.instance.isLoginInformationCached() || CredentialHelper.instance.getDeviceRegistration().data.subscriptionStatus != "active"){
                UserInteractionHelper.instance.showError(title: "account_no_subscription_title".localizedString, message: "account_no_subscription_message".localizedString)
                return
            }
            
            if let id = currentItem.container.metadata?.contentId {
                if let additionalStream = currentItem.container.metadata?.additionalStreams?.first {
                    PlayerController.instance.playStream(contentId: additionalStream.playbackUrl)
                    return
                }
                
                PlayerController.instance.playStream(contentId: String(id))
            }
            
            
        case .Launcher, .Bundle:
            //Open sub-page
            if let action = currentItem.container.actions?.first {
                let sideInfoVc = self.getViewControllerWith(viewIdentifier: ConstantsUtil.sideBarInfoViewController) as! SideBarInfoViewController
                sideInfoVc.initialize(contentItem: currentItem)
                
                let subPageVc = self.getViewControllerWith(viewIdentifier: ConstantsUtil.pageOverviewCollectionViewController) as! PageOverviewCollectionViewController
                subPageVc.initialize(pageUri: action.uri)
                
                let splitVc = BaseSplitViewController()
                if(!((currentItem.container.metadata?.pictureUrl?.isEmpty) ?? true)) {
                    splitVc.initialize(backgroundPictureId: currentItem.container.metadata?.pictureUrl ?? "")
                }
                splitVc.viewControllers = [sideInfoVc, subPageVc]
                
                self.presentFullscreen(viewController: splitVc)
            }
            
        default:
            print("Cannot handle this yet")
        }
    }
    
    func didLoadVideo(contentVideo: ResultObjectDto) {
        if(!CredentialHelper.instance.isLoginInformationCached() || CredentialHelper.instance.getDeviceRegistration().data.subscriptionStatus != "active"){
            UserInteractionHelper.instance.showError(title: "account_no_subscription_title".localizedString, message: "account_no_subscription_message".localizedString)
            return
        }
        
        if let container = contentVideo.containers?.first {
            if(container.metadata?.contentSubtype == "LIVE") {
                print("Is Live")
                
                let alertController = UIAlertController(title: "stream_start_live_or_from_start_title".localizedString, message: "stream_start_live_or_from_start_message".localizedString, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "stream_start_live_or_from_start_live".localizedString, style: .default, handler: { (UIAlertAction) in
                    self.prepareToStartStream(container: container, playFromStart: false)
                }))
                
                alertController.addAction(UIAlertAction(title: "stream_start_live_or_from_start_start".localizedString, style: .default, handler: { (UIAlertAction) in
                    self.prepareToStartStream(container: container, playFromStart: true)
                }))
                
                self.present(alertController, animated: true)
                
                return
            }
            
            print("Is not Live")
            
            prepareToStartStream(container: container)
        }
    }
    
    func prepareToStartStream(container: ContainerDto, playFromStart: Bool? = false) {
        if(container.metadata?.additionalStreams?.isEmpty ?? true) {
            if let id = container.metadata?.contentId {
                PlayerController.instance.playStream(contentId: String(id), playFromStart: playFromStart)
                return
            }
        }
        
        var mainChannelsSection = ContentSection()
        mainChannelsSection.title = "main_channels_title".localizedString
        
        var driverChannelsSection = ContentSection()
        driverChannelsSection.title = "driver_channels_title".localizedString
        
        var channelItems = [ContentItem]()
        
        //Add the main feed manually
        var mainFeedMetadata = container.metadata
        mainFeedMetadata?.title = "international_feed_title".localizedString
        mainFeedMetadata?.emfAttributes?.videoType = ""
        mainFeedMetadata?.additionalStreams = nil
        mainFeedMetadata?.channelType = .MainFeed
        let mainFeedChannel = ContentItem(objectType: .Video, container: ContainerDto(layout: "CONTENT_ITEM", actions: nil, properties: container.properties, metadata: mainFeedMetadata, bundles: nil, categories: nil, platformVariants: container.platformVariants, retrieveItems: nil, contentId: container.metadata?.contentId ?? 0, suggest: container.suggest, platformName: container.platformName, eventName: nil, events: nil, user: container.user))
        channelItems.append(mainFeedChannel)
        
        for additionalChannel in container.metadata?.additionalStreams ?? [AdditionalStreamDto]() {
            var additionalChannelMetadata = container.metadata
            additionalChannelMetadata?.emfAttributes?.videoType = ""
            additionalChannelMetadata?.pictureUrl = nil
            additionalChannelMetadata?.additionalStreams = [additionalChannel]
            
            //Extract the other main channels and give them a better name and prepare the driver channels
            switch additionalChannel.type {
            case "additional":
                switch additionalChannel.title {
                case "TRACKER":
                    additionalChannelMetadata?.title = "tracker_feed_title".localizedString
                    
                case "PIT LANE":
                    additionalChannelMetadata?.title = "pit_lane_feed_title".localizedString
                    
                case "DATA":
                    additionalChannelMetadata?.title = "data_feed_title".localizedString
                    
                case "INTERNATIONAL":
                    //additionalChannelMetadata?.title = "international_feed_title".localizedString
                    continue
                    
                case "F1 LIVE":
                    additionalChannelMetadata?.title = "f1_live_feed_title".localizedString
                    
                default:
                    additionalChannelMetadata?.title = additionalChannel.title
                }
                
                additionalChannelMetadata?.channelType = .AdditionalFeed
                
                let additionalFeedChannel = ContentItem(objectType: .Video, container: ContainerDto(layout: "CONTENT_ITEM", actions: nil, properties: container.properties, metadata: additionalChannelMetadata, bundles: nil, categories: nil, platformVariants: container.platformVariants, retrieveItems: nil, contentId: container.metadata?.contentId ?? 0, suggest: container.suggest, platformName: container.platformName, eventName: nil, events: nil, user: container.user))
                channelItems.append(additionalFeedChannel)
                
            case "obc":
                var driverName = (additionalChannel.driverFirstName ?? "") + " " + (additionalChannel.driverLastName ?? "")
                
                if(CredentialHelper.getPlayerSettings().showFunNames) {
                    let alternateUniverseDriver = AlternateUniverseDrivers.fromOriginalName(originalName: driverName)
                    if(alternateUniverseDriver != .None) {
                        driverName = alternateUniverseDriver.getAlternateName()
                    }
                }
                
                additionalChannelMetadata?.title = driverName
                
                additionalChannelMetadata?.channelType = .OnBoardCamera
                
                let additionalFeedChannel = ContentItem(objectType: .Video, container: ContainerDto(layout: "CONTENT_ITEM", actions: nil, properties: container.properties, metadata: additionalChannelMetadata, bundles: nil, categories: nil, platformVariants: container.platformVariants, retrieveItems: nil, contentId: container.metadata?.contentId ?? 0, suggest: container.suggest, platformName: container.platformName, eventName: nil, events: nil, user: container.user))
                channelItems.append(additionalFeedChannel)
                
            default:
                print("What even is this?")
            }
        }
        
        let playerVc = self.getViewControllerWith(viewIdentifier: ConstantsUtil.playerCollectionViewController) as! PlayerCollectionViewController
        let playerChannelItems = self.sortDriverChannels(channelItems: channelItems).sorted(by: {($0.container.metadata?.channelType ?? ChannelType()).getIdentifier() < ($1.container.metadata?.channelType ?? ChannelType()).getIdentifier()})
        playerVc.initialize(channelItems: playerChannelItems, playFromStart: playFromStart)
        
        self.presentFullscreen(viewController: playerVc)
    }
    
    @objc func viewAllPressed(_ button: UIButton) {
        var currentItem = self.contentSections?[button.tag] ?? ContentSection()
        
        if let actionUrl = currentItem.container.actions?.first?.uri {
            let detailContentItem = ContentItem(objectType: .Bundle, container: currentItem.container)
            
            let sideInfoVc = self.getViewControllerWith(viewIdentifier: ConstantsUtil.sideBarInfoViewController) as! SideBarInfoViewController
            currentItem.container.metadata?.title = currentItem.title
            sideInfoVc.initialize(contentItem: detailContentItem)
            
            let subPageVc = self.getViewControllerWith(viewIdentifier: ConstantsUtil.pageOverviewCollectionViewController) as! PageOverviewCollectionViewController
            subPageVc.initialize(pageUri: actionUrl)
            
            let splitVc = BaseSplitViewController()
            if(!((detailContentItem.container.metadata?.pictureUrl?.isEmpty) ?? true)) {
                splitVc.initialize(backgroundPictureId: detailContentItem.container.metadata?.pictureUrl ?? "")
            }
            splitVc.viewControllers = [sideInfoVc, subPageVc]
            
            self.presentFullscreen(viewController: splitVc)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        //2*24 between cells + 2*24 for left and right
        let width = (collectionView.frame.width-96)/3
        return CGSize(width: width, height: width*ConstantsUtil.thumnailCardHeightMultiplier)
        
        //TODO: Maybe use this in the future
        /*let currentSection = self.contentSections?[indexPath.section]
        
        var itemsPerRow: CGFloat = 3
        if((currentSection?.items.count ?? 3) < 3) {
            itemsPerRow = CGFloat(currentSection?.items.count ?? 3)
        }
        
        var spacingSubtraction: CGFloat = 48
        if(itemsPerRow > 1) {
            spacingSubtraction += CGFloat((itemsPerRow-1) * 24)
        }
        
        //2*24 between cells + 2*24 for left and right
        let width = (collectionView.frame.width-spacingSubtraction)/itemsPerRow
        return CGSize(width: width, height: width*ConstantsUtil.thumnailCardHeightMultiplier)*/
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let headerView = self.collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: ConstantsUtil.customHeaderCollectionReusableView, for: indexPath)
            
            for subview in headerView.subviews {
                subview.removeFromSuperview()
            }
            
            let currentItem = self.contentSections?[indexPath.section]
            if(!((currentItem?.title.isEmpty) ?? false)) {
                let height = self.getSupplementaryHeight(section: indexPath.section, contentSection: currentItem ?? ContentSection())
                
                let holderStackView = UIStackView(frame: CGRect(x: 24, y: height-80, width: self.view.bounds.width-48, height: 60))
                holderStackView.axis = .horizontal
                holderStackView.spacing = 2
                
                switch currentItem?.layoutType {
                case .Title:
                    let titleLabel = FontAdjustedUILabel()
                    titleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 60)
                    titleLabel.text = currentItem?.title
                    titleLabel.textColor = .white
                    
                    titleLabel.setContentHuggingPriority(UILayoutPriority(rawValue: 250), for: .horizontal)
                    titleLabel.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 750), for: .horizontal)
                    
                    holderStackView.addArrangedSubview(titleLabel)
                    
                case .Subtitle:
                    let subtitleLabel = FontAdjustedUILabel()
                    subtitleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 25)
                    subtitleLabel.text = currentItem?.title
                    subtitleLabel.textColor = .white
                    
                    subtitleLabel.setContentHuggingPriority(UILayoutPriority(rawValue: 250), for: .horizontal)
                    subtitleLabel.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 750), for: .horizontal)
                    
                    holderStackView.addArrangedSubview(subtitleLabel)
                    
                default:
                    let titleLabel = FontAdjustedUILabel()
                    titleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 34)
                    titleLabel.text = currentItem?.title
                    titleLabel.textColor = .white
                    
                    holderStackView.addArrangedSubview(titleLabel)
                }
                
                headerView.addSubview(holderStackView)
            }
            
            return headerView
        default:
            print("No user for kind: " + kind)
            assert(false, "Did not expect a footer view")
        }
        return UICollectionReusableView()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        
        let currentItem = self.contentSections?[section]
        
        return CGSize(width: self.view.frame.width, height: self.getSupplementaryHeight(section: section, contentSection: currentItem ?? ContentSection()))
    }
    
    func getSupplementaryHeight(section: Int, contentSection: ContentSection) -> CGFloat {
        var height: CGFloat = 120
        
        if(section == 0) {
            height = 80
        }
        
        switch contentSection.layoutType {
        case .Title:
            height+=60
            
        case .Subtitle:
            height -= 40
            
        default:
            break
        }
        
        if(contentSection.title.isEmpty) {
            height = 50
        }
        
        return height
    }
    
    func sortDriverChannels(channelItems: [ContentItem]) -> [ContentItem] {
        switch CredentialHelper.getPlayerSettings().driverChannelSorting {
        case .DriverNumber:
            return channelItems.sorted(by: {($0.container.metadata?.additionalStreams?.first?.racingNumber ?? 0) < ($1.container.metadata?.additionalStreams?.first?.racingNumber ?? 0)})
            
        case .Alphabetical:
            return channelItems.sorted(by: {($0.container.metadata?.additionalStreams?.first?.title ?? "") < $1.container.metadata?.additionalStreams?.first?.title ?? ""})
        }
    }
}

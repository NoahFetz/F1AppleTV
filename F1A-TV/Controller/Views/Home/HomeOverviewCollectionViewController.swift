//
//  HomeOverviewCollectionViewController.swift
//  F1oA-TV
//
//  Created by Noah Fetz on 08.03.21.
//

import UIKit

class HomeOverviewCollectionViewController: BaseCollectionViewController, UICollectionViewDelegateFlowLayout, ContentPageLoadedProtocol {
    var sectionContainers: [ContainerDto]?
    
    let homePageId = "/2.0/R/ENG/BIG_SCREEN_HLS/ALL/PAGE/395/F1_TV_Pro_Annual/2"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupCollectionView()
    }
    
    func setupCollectionView() {
    }
    
    override func viewDidAppear(_ animated: Bool) {
        DataManager.instance.loadContentPage(pageUri: self.homePageId, contentPageProtocol: self)
    }
    
    func didLoadContentPage(contentPage: ResultObjectDto) {
        self.sectionContainers = contentPage.containers?.filter({$0.layout == "hero" || $0.layout == "horizontal_thumbnail" || $0.layout == "vertical_thumbnail"})
        self.collectionView.reloadData()
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.sectionContainers?.count ?? 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.sectionContainers?[section].retrieveItems?.resultObj.containers?.count ?? 3
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ConstantsUtil.thumbnailTitleSubtitleCollectionViewCell, for: indexPath) as! ThumbnailTitleSubtitleCollectionViewCell

        cell.titleLabel.hideSkeletonAnimation()
        cell.subtitleLabel.hideSkeletonAnimation()
        cell.footerLabel.hideSkeletonAnimation()
        cell.accessoryFooterLabel.hideSkeletonAnimation()
        cell.thumbnailImageView.hideSkeletonAnimation()
        
        if(self.sectionContainers == nil) {
            cell.titleLabel.text = ""
            cell.titleLabel.linesCornerRadius = 5
            cell.titleLabel.showSkeletonAnimation()
            
            cell.subtitleLabel.text = ""
            cell.subtitleLabel.linesCornerRadius = 5
            cell.subtitleLabel.showSkeletonAnimation()
            
            cell.footerLabel.text = ""
            cell.footerLabel.linesCornerRadius = 5
            cell.footerLabel.showSkeletonAnimation()
            
            cell.accessoryFooterLabel.text = ""
            cell.accessoryFooterLabel.linesCornerRadius = 5
            cell.accessoryFooterLabel.showSkeletonAnimation()
            
            cell.thumbnailImageView.showSkeletonAnimation()
        }else{
            let currentItem = self.sectionContainers?[indexPath.section].retrieveItems?.resultObj.containers?[indexPath.row] ?? ContainerDto()
            
            cell.titleLabel.text = currentItem.metadata?.title
            cell.titleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 20)
            
            cell.subtitleLabel.text = (currentItem.metadata?.uiDuration ?? "") + " | " + (currentItem.metadata?.contentSubtype ?? "")
            cell.subtitleLabel.font = UIFont(name: "Titillium-Regular", size: 20)
            
            cell.accessoryFooterLabel.text = ""
            if let property = currentItem.properties?.first {
                let series = SeriesType.fromCapitalDisplayName(capitalDisplayName: property.series)
                cell.accessoryFooterLabel.text = series.getCapitalDisplayName()
                cell.accessoryFooterLabel.textColor = series.getColor()
            }
            
            if((currentItem.metadata?.pictureUrl?.isEmpty) ?? true) {
                cell.thumbnailImageView.image = UIImage(named: "thumb_placeholder")
            }else{
                cell.applyImage(pictureId: currentItem.metadata?.pictureUrl ?? "", imageView: cell.thumbnailImageView)
            }
        }
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if(self.sectionContainers == nil) {
            DataManager.instance.loadContentPage(pageUri: self.homePageId, contentPageProtocol: self)
            return
        }
        
        if(!CredentialHelper.isLoginInformationCached() || CredentialHelper.getUserInfo().authData.subscriptionStatus != "active"){
            UserInteractionHelper.instance.showAlert(title: NSLocalizedString("account_no_subscription_title", comment: ""), message: NSLocalizedString("account_no_subscription_message", comment: ""))
            return
        }
        
        let currentItem = self.sectionContainers?[indexPath.section].retrieveItems?.resultObj.containers?[indexPath.row] ?? ContainerDto()
        if let id = currentItem.contentId {
            PlayerController.instance.playStream(contentId: String(id))
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        //2*24 between cells + 2*24 for left and right
        let width = (collectionView.frame.width-96)/3
        return CGSize(width: width, height: width*ConstantsUtil.thumnailCardHeightMultiplier)
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let headerView = self.collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: ConstantsUtil.customHeaderCollectionReusableView, for: indexPath)
            
            for subview in headerView.subviews {
                subview.removeFromSuperview()
            }
            
            let titleLabel = UILabel(frame: CGRect(x: 24, y: 80, width: self.view.bounds.width-48, height: 60))
            titleLabel.font = UIFont(name: "Formula1-Display-Bold", size: 34)
            
            let currentItem = self.sectionContainers?[indexPath.section]

            titleLabel.text = currentItem?.metadata?.label ?? NSLocalizedString("featured_title", comment: "")
            
            headerView.addSubview(titleLabel)
            
            return headerView
        default:
            print("No user for kind: " + kind)
            assert(false, "Did not expect a footer view")
        }
        return UICollectionReusableView()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: self.view.frame.width, height: 150)
    }
}

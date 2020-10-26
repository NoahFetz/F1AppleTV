//
//  SeasonOverviewCollectionViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit

class SeasonOverviewCollectionViewController: BaseCollectionViewController, UICollectionViewDelegateFlowLayout {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 3
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 5
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ConstantsUtil.thumbnailTitleCollectionViewCell, for: indexPath) as! ThumbnailTitleCollectionViewCell
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSize(width: 400, height: 300)
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let headerView = self.collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: ConstantsUtil.customHeaderCollectionReusableView, for: indexPath)
            
            for subview in headerView.subviews {
                subview.removeFromSuperview()
            }
            
            let titleLabel = UILabel(frame: CGRect(x: 16, y: 14, width: self.view.bounds.width-32, height: 22))
            titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
//            titleLabel.font = UIFont(name: "AvenirNextLTPro-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
//            titleLabel.textColor = ConstantsUtil.tableViewHeaderColor
            
            switch indexPath.section {
            case 0:
                titleLabel.text = NSLocalizedString("dashboard_account", comment: "")
            case 1:
                titleLabel.text = NSLocalizedString("dashboard_functions_header", comment: "")
            default:
                titleLabel.text = "Not found"
            }
            headerView.addSubview(titleLabel)
            
            return headerView
        default:
            print("No user for kind: " + kind)
            assert(false, "Did not expect a footer view")
        }
        return UICollectionReusableView()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: self.view.frame.width, height: 42)
        /*switch section {
        case 0:
            return CGSize(width: self.view.frame.width, height: 42)
        case 1:
            return CGSize(width: self.view.frame.width, height: 42)
        default:
            return CGSize(width: 0, height: 0)
        }*/
    }
    
    /*override func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let pindex  = context.previouslyFocusedIndexPath, let cell = collectionView.cellForItem(at: pindex) {
            cell.contentView.layer.borderWidth = 0.0
            cell.contentView.layer.shadowRadius = 0.0
            cell.contentView.layer.shadowOpacity = 0.0
        }

        if let index  = context.nextFocusedIndexPath, let cell = collectionView.cellForItem(at: index) {
            let verticalMotionEffect = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
            verticalMotionEffect.minimumRelativeValue = -10
            verticalMotionEffect.maximumRelativeValue = 10

            let horizontalMotionEffect = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
            horizontalMotionEffect.minimumRelativeValue = -10
            horizontalMotionEffect.maximumRelativeValue = 10

            let motionEffectGroup = UIMotionEffectGroup()
            motionEffectGroup.motionEffects = [horizontalMotionEffect, verticalMotionEffect]

            cell.addMotionEffect(motionEffectGroup)
        }
    }*/
}

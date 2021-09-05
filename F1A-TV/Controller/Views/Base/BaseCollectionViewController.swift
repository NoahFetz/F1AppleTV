//
//  BaseCollectionViewController.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import UIKit

class BaseCollectionViewController: UICollectionViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.collectionView.register(UINib(nibName: ConstantsUtil.customHeaderCollectionReusableView, bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: ConstantsUtil.customHeaderCollectionReusableView)
        self.registerCell(identifier: ConstantsUtil.basicCollectionViewCell)
        self.registerCell(identifier: ConstantsUtil.thumbnailTitleSubtitleCollectionViewCell)
        self.registerCell(identifier: ConstantsUtil.noContentCollectionViewCell)
        self.registerCell(identifier: ConstantsUtil.channelPlayerCollectionViewCell)
    }
    
    func registerCell(identifier: String) {
        self.collectionView.register(UINib(nibName: identifier, bundle: nil), forCellWithReuseIdentifier: identifier)
    }
    
    func setTitle(title: String) {
        self.navigationItem.title = title
    }
}

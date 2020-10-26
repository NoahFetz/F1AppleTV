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
        self.collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: ConstantsUtil.basicCollectionViewCell)
        self.collectionView.register(UINib(nibName: ConstantsUtil.thumbnailTitleCollectionViewCell, bundle: nil), forCellWithReuseIdentifier: ConstantsUtil.thumbnailTitleCollectionViewCell)
    }
    
    func setTitle(title: String) {
        self.navigationItem.title = title
    }
}

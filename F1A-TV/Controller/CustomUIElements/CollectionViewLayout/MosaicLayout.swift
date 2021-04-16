//
//  MosaicLayout.swift
//  F1A-TV
//
//  Created by Noah Fetz on 01.04.21.
//

import UIKit

final class FMMosaicLayoutCopy: SquareMosaicLayout, SquareMosaicDataSource {
    
    convenience init() {
        self.init(direction: SquareMosaicDirection.vertical)
        self.dataSource = self
    }
    
    func layoutPattern(for section: Int) -> SquareMosaicPattern {
        return FMMosaicLayoutCopyPattern()
    }
}

class FMMosaicLayoutCopyPattern: SquareMosaicPattern {
    
    func patternBlocks() -> [SquareMosaicBlock] {
        return [
            FMMosaicLayoutCopyBlock1()
        ]
    }
}

public class FMMosaicLayoutCopyBlock1: SquareMosaicBlock {
    
    public func blockFrames() -> Int {
        return 13
    }
    
    public func blockFrames(origin: CGFloat, side: CGFloat) -> [CGRect] {
        /*let min = side / 5
        let max = min * 2*/
        
        let bigCellWidth = side / 4 * 2
        let bigCellHeight = bigCellWidth / 16 * 9
        
        let smallCellWidth = side / 4
        let smallCellHeight = smallCellWidth / 16 * 9
        
        var frames = [CGRect]()
        frames.append(CGRect(x: 0, y: origin, width: smallCellWidth, height: smallCellHeight))
        frames.append(CGRect(x: 0, y: origin + smallCellHeight, width: smallCellWidth, height: smallCellHeight))
        frames.append(CGRect(x: 0, y: origin + smallCellHeight * 2, width: smallCellWidth, height: smallCellHeight))
        frames.append(CGRect(x: 0, y: origin + smallCellHeight * 3, width: smallCellWidth, height: smallCellHeight))
        
        frames.append(CGRect(x: smallCellWidth, y: origin, width: smallCellWidth, height: smallCellHeight))
        frames.append(CGRect(x: smallCellWidth, y: origin + smallCellHeight, width: bigCellWidth, height: bigCellHeight))
        frames.append(CGRect(x: smallCellWidth, y: origin + smallCellHeight + bigCellHeight, width: smallCellWidth, height: smallCellHeight))
        
        frames.append(CGRect(x: smallCellWidth * 2, y: origin, width: smallCellWidth, height: smallCellHeight))
        frames.append(CGRect(x: smallCellWidth * 2, y: origin + smallCellHeight + bigCellHeight, width: smallCellWidth, height: smallCellHeight))
        
        frames.append(CGRect(x: smallCellWidth * 3, y: origin, width: smallCellWidth, height: smallCellHeight))
        frames.append(CGRect(x: smallCellWidth * 3, y: origin + smallCellHeight, width: smallCellWidth, height: smallCellHeight))
        frames.append(CGRect(x: smallCellWidth * 3, y: origin + smallCellHeight * 2, width: smallCellWidth, height: smallCellHeight))
        frames.append(CGRect(x: smallCellWidth * 3, y: origin + smallCellHeight * 3, width: smallCellWidth, height: smallCellHeight))
        return frames
    }
}

open class SquareMosaicLayout: UICollectionViewLayout {
    
    fileprivate let collectionViewForcedSize: CGSize?
    fileprivate let direction: SquareMosaicDirection
    fileprivate var object: SquareMosaicObject? = nil
    
    public weak var dataSource: SquareMosaicDataSource?
    public weak var delegate: SquareMosaicDelegate? {
        didSet {
            delegate?.layoutContentSizeChanged(to: collectionViewContentSize)
        }
    }
    
    override open var collectionViewContentSize: CGSize {
        switch direction {
        case .horizontal:
            return collectionViewContentSizeHorizontal
        case .vertical:
            return collectionViewContentSizeVertical
        }
    }
    
    public init(direction: SquareMosaicDirection = .vertical, size collectionViewForcedSize: CGSize? = nil) {
        self.collectionViewForcedSize = collectionViewForcedSize
        self.direction = direction
        super.init()
    }
    
    public convenience required init?(coder aDecoder: NSCoder) {
        self.init()
    }
    
    open override func prepare() {
        let numberOfItemsInSections = collectionView?.numberOfItemsInSections ?? []
        let size = collectionViewContentSize
        object = SquareMosaicObject(numberOfItemsInSections, dataSource, direction, size)
    }

    open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return object?.layoutAttributesForItem(at: indexPath)
    }
    
    open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return object?.layoutAttributesForElements(in: rect)
    }
    
    open override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return object?.layoutAttributesForSupplementaryView(ofKind: elementKind, at: indexPath)
    }
    
    open override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        return collectionView?.contentOffset ?? CGPoint.zero
    }
}

fileprivate extension SquareMosaicLayout {
    
    var collectionViewContentSizeHorizontal: CGSize {
        let width = object?.contentSize ?? 0.0
        let height = collectionViewForcedSize?.height ?? collectionView?.collectionViewVisibleContentHeight ?? 0.0
        return CGSize(width: width, height: height)
    }
    
    var collectionViewContentSizeVertical: CGSize {
        let height = object?.contentSize ?? 0.0
        let width = collectionViewForcedSize?.width ?? collectionView?.collectionViewVisibleContentWidth ?? 0.0
        return CGSize(width: width, height: height)
    }
}

fileprivate extension UICollectionView {
    
    var collectionViewVisibleContentHeight: CGFloat {
        return bounds.height - contentInset.top - contentInset.bottom
    }
    
    var collectionViewVisibleContentWidth: CGFloat {
        return bounds.width - contentInset.left - contentInset.right
    }
}

fileprivate extension UICollectionView {

    var numberOfItemsInSections: [Int] {
        var array = [Int](repeating: 0, count: numberOfSections)
        for section in 0 ..< numberOfSections {
            array[section] = numberOfItems(inSection: section)
        }
        return array
    }
}

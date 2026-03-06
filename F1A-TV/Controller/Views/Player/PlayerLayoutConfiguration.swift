//
//  PlayerLayoutConfiguration.swift
//  F1A-TV
//
//  Created by Noah Fetz on 29.03.21.
//

import UIKit

// MARK: - Layout Manager Types

enum PlayerLayoutMode {
    case single           // 1 player
    case mainWithSidebar  // 2-6 players
    case grid             // 7+ players
    
    static func mode(for playerCount: Int) -> PlayerLayoutMode {
        switch playerCount {
        case 0, 1:
            return .single
        case 2...6:
            return .mainWithSidebar
        default:
            return .grid
        }
    }
}

struct PlayerLayoutConfiguration {
    // Layout constants
    static let mainToSidebarRatio: CGFloat = 0.666  // Main player takes 2/3 width
    static let mainToBottomRatio: CGFloat = 0.666    // Main player takes 2/3 height when bottom row exists
    
    let playerCount: Int
    let mainPlayerIndex: Int
    let bounds: CGRect
    
    var mode: PlayerLayoutMode {
        return PlayerLayoutMode.mode(for: playerCount)
    }
    
    init(playerCount: Int, mainPlayerIndex: Int = 0, bounds: CGRect) {
        self.playerCount = playerCount
        self.mainPlayerIndex = mainPlayerIndex
        self.bounds = bounds
    }
    
    func frame(for index: Int) -> CGRect {
        switch mode {
        case .single:
            return bounds
            
        case .mainWithSidebar:
            return frameMainWithSidebar(for: index)
            
        case .grid:
            return frameGrid(for: index)
        }
    }
    
    private func frameMainWithSidebar(for index: Int) -> CGRect {
        let mainWidth = floor(bounds.width * Self.mainToSidebarRatio)
        let sidebarWidth = bounds.width - mainWidth
        
        let sidebarCount = min(playerCount - 1, 3)
        let bottomCount = max(0, playerCount - 4)
        
        if index == mainPlayerIndex {
            let mainHeight = bottomCount > 0 ? bounds.height * Self.mainToBottomRatio : bounds.height
            return CGRect(x: 0, y: 0, width: mainWidth, height: mainHeight)
        }
        
        let adjustedIndex = index > mainPlayerIndex ? index - 1 : index
        
        if adjustedIndex < sidebarCount {
            let sidebarHeight = bounds.height / CGFloat(sidebarCount)
            let y = sidebarHeight * CGFloat(adjustedIndex)
            return CGRect(x: mainWidth, y: y, width: sidebarWidth, height: sidebarHeight)
        } else {
            let bottomIndex = adjustedIndex - sidebarCount
            let bottomY = bounds.height * Self.mainToBottomRatio
            let bottomHeight = bounds.height * (1.0 - Self.mainToBottomRatio)
            let bottomWidth = mainWidth / CGFloat(bottomCount)
            let x = bottomWidth * CGFloat(bottomIndex)
            return CGRect(x: x, y: bottomY, width: bottomWidth, height: bottomHeight)
        }
    }
    
    private func frameGrid(for index: Int) -> CGRect {
        let gridSize = ceil(sqrt(CGFloat(playerCount)))
        let itemWidth = bounds.width / gridSize
        let itemHeight = itemWidth / 16 * 9
        
        let row = floor(CGFloat(index) / gridSize)
        let col = CGFloat(index).truncatingRemainder(dividingBy: gridSize)
        
        return CGRect(
            x: itemWidth * col,
            y: itemHeight * row,
            width: itemWidth,
            height: itemHeight
        )
    }
    
    var contentSize: CGSize {
        switch mode {
        case .single, .mainWithSidebar:
            return bounds.size
            
        case .grid:
            let gridSize = ceil(sqrt(CGFloat(playerCount)))
            let itemWidth = bounds.width / gridSize
            let itemHeight = itemWidth / 16 * 9
            let rows = ceil(CGFloat(playerCount) / gridSize)
            return CGSize(width: bounds.width, height: rows * itemHeight)
        }
    }
}

enum LayoutUpdateStrategy {
    case reloadAll
    case reloadMainArea
    case reloadSidebarOnly
    case simpleInsert(at: Int)
    case simpleDelete(at: Int)
    
    static func determine(
        oldCount: Int,
        newCount: Int,
        oldMainIndex: Int,
        newMainIndex: Int,
        changedIndex: Int
    ) -> LayoutUpdateStrategy {
        
        let oldMode = PlayerLayoutMode.mode(for: oldCount)
        let newMode = PlayerLayoutMode.mode(for: newCount)
        
        if oldMode != newMode {
            return .reloadAll
        }
        
        if oldMainIndex != newMainIndex {
            return .reloadAll
        }
        
        if newMode == .grid && changedIndex != 0 {
            return newCount > oldCount ? .simpleInsert(at: changedIndex) : .simpleDelete(at: changedIndex)
        }
        
        if newMode == .mainWithSidebar {
            return .reloadAll
        }
        
        return .reloadAll
    }
}

class PlayerLayoutManager {
    private(set) var configuration: PlayerLayoutConfiguration
    
    init(configuration: PlayerLayoutConfiguration) {
        self.configuration = configuration
    }
    
    func layoutAttributes(for indexPath: IndexPath) -> UICollectionViewLayoutAttributes {
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = configuration.frame(for: indexPath.item)
        return attributes
    }
    
    func allLayoutAttributes() -> [UICollectionViewLayoutAttributes] {
        return (0..<configuration.playerCount).map { index in
            layoutAttributes(for: IndexPath(item: index, section: 0))
        }
    }
}

// MARK: - Custom Collection View Layout
class PlayerGridLayout: UICollectionViewLayout {
    private var layoutManager: PlayerLayoutManager?
    var mainPlayerIndex: Int = 0
    
    override func prepare() {
        super.prepare()
        
        guard let collectionView = collectionView else { return }
        
        let itemCount = collectionView.numberOfItems(inSection: 0)
        
        let config = PlayerLayoutConfiguration(
            playerCount: itemCount,
            mainPlayerIndex: mainPlayerIndex,
            bounds: collectionView.bounds
        )
        
        layoutManager = PlayerLayoutManager(configuration: config)
    }
    
    override var collectionViewContentSize: CGSize {
        return layoutManager?.configuration.contentSize ?? .zero
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return layoutManager?.allLayoutAttributes().filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return layoutManager?.layoutAttributes(for: indexPath)
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
}

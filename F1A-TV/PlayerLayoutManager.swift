//
//  PlayerLayoutManager.swift
//  F1A-TV
//
//  Player layout management system
//

import UIKit

// MARK: - Layout Mode
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

// MARK: - Layout Configuration
struct PlayerLayoutConfiguration {
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
    
    /// Calculate frame for a player at the given index
    func frame(for index: Int) -> CGRect {
        switch mode {
        case .single:
            return frameSinglePlayer()
            
        case .mainWithSidebar:
            return frameMainWithSidebar(for: index)
            
        case .grid:
            return frameGrid(for: index)
        }
    }
    
    // MARK: - Single Player Layout
    private func frameSinglePlayer() -> CGRect {
        return bounds
    }
    
    // MARK: - Main + Sidebar Layout (2-6 players)
    private func frameMainWithSidebar(for index: Int) -> CGRect {
        let mainWidth = floor(bounds.width * 0.666)
        let sidebarWidth = bounds.width - mainWidth
        
        // Calculate how many players in each area
        let sidebarCount = min(playerCount - 1, 3)  // Max 3 in sidebar
        let bottomCount = max(0, playerCount - 4)   // Remaining go to bottom
        
        if index == mainPlayerIndex {
            // Main player
            let mainHeight = bottomCount > 0 ? bounds.height * 0.75 : bounds.height
            return CGRect(x: 0, y: 0, width: mainWidth, height: mainHeight)
        }
        
        // Adjust index for sidebar/bottom positioning
        let adjustedIndex = index > mainPlayerIndex ? index - 1 : index
        
        if adjustedIndex < sidebarCount {
            // Sidebar player
            let sidebarHeight = bounds.height / CGFloat(sidebarCount)
            let y = sidebarHeight * CGFloat(adjustedIndex)
            return CGRect(x: mainWidth, y: y, width: sidebarWidth, height: sidebarHeight)
        } else {
            // Bottom player
            let bottomIndex = adjustedIndex - sidebarCount
            let bottomY = bounds.height * 0.75
            let bottomHeight = bounds.height * 0.25
            let bottomWidth = mainWidth / CGFloat(bottomCount)
            let x = bottomWidth * CGFloat(bottomIndex)
            return CGRect(x: x, y: bottomY, width: bottomWidth, height: bottomHeight)
        }
    }
    
    // MARK: - Grid Layout (7+ players)
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

// MARK: - Layout Update Strategy
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
        
        // Mode changed - reload everything
        if oldMode != newMode {
            return .reloadAll
        }
        
        // Main player index changed - reload everything
        if oldMainIndex != newMainIndex {
            return .reloadAll
        }
        
        // Within grid mode - simple operations work
        if newMode == .grid && changedIndex != 0 {
            return newCount > oldCount ? .simpleInsert(at: changedIndex) : .simpleDelete(at: changedIndex)
        }
        
        // Within main+sidebar mode - always reload all for safety
        // (heights/positions change)
        if newMode == .mainWithSidebar {
            return .reloadAll
        }
        
        return .reloadAll
    }
}

// MARK: - Layout Manager
class PlayerLayoutManager {
    private(set) var configuration: PlayerLayoutConfiguration
    
    init(configuration: PlayerLayoutConfiguration) {
        self.configuration = configuration
    }
    
    func updateConfiguration(_ newConfiguration: PlayerLayoutConfiguration) {
        self.configuration = newConfiguration
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

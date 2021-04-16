//
//  MosaicProtocols.swift
//  F1A-TV
//
//  Created by Noah Fetz on 01.04.21.
//

import UIKit

// MARK: - SquareMosaicBlock
typealias Block = SquareMosaicBlock

public protocol SquareMosaicBlock {
    
    func blockFrames() -> Int
    func blockFrames(origin: CGFloat, side: CGFloat) -> [CGRect]
    func blockRepeated() -> Bool
}

public extension SquareMosaicBlock {
    
    func blockRepeated() -> Bool {
        return false
    }
}

// MARK: - SquareMosaicBlockSeparatorPosition
typealias BlockSeparatorPosition = SquareMosaicBlockSeparatorPosition

public enum SquareMosaicBlockSeparatorPosition: Int {
    
    case after, before, between
}

// MARK: - SquareMosaicDataSource
public protocol SquareMosaicDataSource: AnyObject {
    
    func layoutPattern(for section: Int) -> SquareMosaicPattern
    func layoutSeparatorBetweenSections() -> CGFloat
    func layoutSupplementaryBackerRequired(for section: Int) -> Bool
    func layoutSupplementaryFooter(for section: Int) -> SquareMosaicSupplementary?
    func layoutSupplementaryHeader(for section: Int) -> SquareMosaicSupplementary?
}

public extension SquareMosaicDataSource {
    
    func layoutSeparatorBetweenSections() -> CGFloat {
        return 0
    }
    
    func layoutSupplementaryBackerRequired(for section: Int) -> Bool {
        return false
    }
    
    func layoutSupplementaryFooter(for section: Int) -> SquareMosaicSupplementary? {
        return nil
    }
    
    func layoutSupplementaryHeader(for section: Int) -> SquareMosaicSupplementary? {
        return nil
    }
}

// MARK: - SquareMosaicDelegate
typealias Delegate = SquareMosaicDelegate

public protocol SquareMosaicDelegate: AnyObject {
    
    func layoutContentSizeChanged(to size: CGSize) -> Void
}

// MARK: - SquareMosaicDirection
typealias Direction = SquareMosaicDirection

public enum SquareMosaicDirection: Int {
    
    case horizontal, vertical
}

// MARK: - SquareMosaicPattern
typealias Pattern = SquareMosaicPattern

public protocol SquareMosaicPattern {
    
    func patternBlocks() -> [SquareMosaicBlock]
    func patternBlocksSeparator(at position: SquareMosaicBlockSeparatorPosition) -> CGFloat
}

public extension SquareMosaicPattern {
    
    func patternBlocksSeparator(at position: SquareMosaicBlockSeparatorPosition) -> CGFloat {
        return 0
    }
}

// MARK: - SquareMosaicSupplementary
typealias Supplementary = SquareMosaicSupplementary

public protocol SquareMosaicSupplementary {
    
    func supplementaryFrame(for origin: CGFloat, side: CGFloat) -> CGRect
    func supplementaryHiddenForEmptySection() -> Bool
}

public extension SquareMosaicSupplementary {
    
    func supplementaryHiddenForEmptySection() -> Bool {
        return false
    }
}

//
//  MosaicObject.swift
//  F1A-TV
//
//  Created by Noah Fetz on 01.04.21.
//

import UIKit

public let SquareMosaicLayoutSectionBacker = "SquareMosaicLayout.SquareMosaicLayoutSectionBacker"
public let SquareMosaicLayoutSectionFooter = "SquareMosaicLayout.SquareMosaicLayoutSectionFooter"
public let SquareMosaicLayoutSectionHeader = "SquareMosaicLayout.SquareMosaicLayoutSectionHeader"

fileprivate enum SupplementaryKind {
    
    case backer, footer, header
    
    var value: String {
        switch self {
        case .backer:
            return SquareMosaicLayoutSectionBacker
        case .footer:
            return SquareMosaicLayoutSectionFooter
        case .header:
            return SquareMosaicLayoutSectionHeader
        }
    }
}

fileprivate enum SectionsNonEmpty {
    
    case none
    case multiple([Int])
    case single(Int)
}

fileprivate struct Attributes {
    
    let cell: [[UICollectionViewLayoutAttributes]]
    let supplementary: [UICollectionViewLayoutAttributes]
}

final class SquareMosaicObject {
    
    fileprivate let attributes: Attributes
    let contentSize: CGFloat
    
    init?(_ numberOfItemsInSections: [Int], _ dataSource: SquareMosaicDataSource?, _ direction: Direction, _ size: CGSize) {
        guard let dataSource = dataSource else {
            return nil
        }
        let attributesAndContentSize = getAttributesAndContentSize(numberOfItemsInSections, dataSource, direction, size)
        attributes = attributesAndContentSize.attributes
        contentSize = attributesAndContentSize.contentSize
    }
}

// MARK: -
extension SquareMosaicObject {
    
    func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.section < attributes.cell.count else { return  nil }
        guard indexPath.row < attributes.cell[indexPath.section].count else { return nil }
        return attributes.cell[indexPath.section][indexPath.row]
    }
    
    func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return attributes.cell.flatMap({ $0 }).filter({ $0.frame.intersects(rect) }) + attributes.supplementary.filter({ $0.frame.intersects(rect) })
    }
    
    func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return attributes.supplementary.first(where: { $0.indexPath == indexPath && $0.representedElementKind == elementKind })
    }
}

// MARK: - Internal
fileprivate extension Pattern {
    
    func blocks(_ expectedFramesTotalCount: Int) -> [Block] {
        var blocks: [Block] = patternBlocks()
        if let index = blocks.enumerated().first(where: { $0.element.blockRepeated() == true })?.offset {
            let blockToRepeat = blocks[index]
            blocks = Array(blocks[0 ..< index])
            let frames: Int = blocks.map({ $0.blockFrames() }).reduce(0, +)
            let framesToRepeat = blockToRepeat.blockFrames()
            var count: Int = frames
            while (count < expectedFramesTotalCount) {
                blocks.append(blockToRepeat)
                count += framesToRepeat
            }
            return blocks
        } else {
            let frames: Int = blocks.map({ $0.blockFrames() }).reduce(0, +)
            var array = [Block]()
            var count: Int = 0
            repeat {
                array.append(contentsOf: blocks)
                count += frames
            } while (count < expectedFramesTotalCount)
            return array
        }
    }
}

// MARK: -
private func getAttributesAndContentSize(_ numberOfItemsInSections: [Int], _ dataSource: SquareMosaicDataSource, _ direction: Direction, _ size: CGSize) -> (attributes: Attributes, contentSize: CGFloat) {
    var attributesCell = [[UICollectionViewLayoutAttributes]](repeating: [], count: numberOfItemsInSections.count)
    var attributesSupplementary = [UICollectionViewLayoutAttributes]()
    var origin: CGFloat = 0
    let sectionsNonEmpty = getSectionsNonEmpty(dataSource, numberOfItemsInSections)
    for (rows, section) in Array(0 ..< numberOfItemsInSections.count).map({ (numberOfItemsInSections[$0], $0) }) {
        if let separator = getSeparatorBeforeSection(dataSource, section: section, sectionsNonEmpty: sectionsNonEmpty) {
            origin += separator
        }
        let sectionOrigin = origin
        if let (attributes, separator) = getAttributesSupplementary(.header, dataSource, direction, origin, rows: rows, section, size) {
            if let separator = separator {
                origin += separator
            }
            attributesSupplementary.append(attributes)
        }
        let pattern: Pattern = dataSource.layoutPattern(for: section)
        if let separator = getSeparatorBlock(.before, pattern: pattern, rows: rows) {
            origin += separator
        }
        if let (attributes, separator) = getAttributesCells(pattern, direction, origin, rows, section, size) {
            if let separator = separator {
                origin += separator
            }
            attributesCell[section] = attributes
        }
        if let separator = getSeparatorBlock(.after, pattern: pattern, rows: rows) {
            origin += separator
        }
        if let (attributes, separator) = getAttributesSupplementary(.footer, dataSource, direction, origin, rows: rows, section, size) {
            if let separator = separator {
                origin += separator
            }
            attributesSupplementary.append(attributes)
        }
        if let (attributes, _) = getAttributesSupplementary(.backer, dataSource, direction, origin, section, sectionOrigin: sectionOrigin, size) {
            attributesSupplementary.append(attributes)
        }
    }
    return (Attributes(cell: attributesCell, supplementary: attributesSupplementary), origin)
}

private func getAttributesCells(_ pattern: Pattern, _ direction: Direction, _ origin: CGFloat, _ rows: Int, _ section: Int, _ size: CGSize) -> (attributes: [UICollectionViewLayoutAttributes], separator: CGFloat?)? {
    var append: CGFloat = 0
    var attributes = [UICollectionViewLayoutAttributes]()
    var origin = origin
    var row: Int = 0
    let blocks = pattern.blocks(rows)
    for (index, block) in blocks.enumerated() {
        guard row < rows else {
            break
        }
        if let separator = getSeparatorBlock(.between, blocks: blocks.count, index: index, pattern: pattern) {
            append += separator
            origin += separator
        }
        let side = direction == .vertical ? size.width : size.height
        let frames = block.blockFrames(origin: origin, side: side)
        var total: CGFloat = 0
        for x in 0..<block.blockFrames() {
            guard row < rows else { break }
            let indexPath = IndexPath(row: row, section: section)
            let attribute = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attribute.frame = frames[x]
            attribute.zIndex = 0
            switch direction {
            case .vertical:
                let dy = attribute.frame.origin.y + attribute.frame.height - origin
                total = dy > total ? dy : total
            case .horizontal:
                let dx = attribute.frame.origin.x + attribute.frame.width - origin
                total = dx > total ? dx : total
            }
            attributes.append(attribute)
            row += 1
        }
        append += total
        origin += total
    }
    if attributes.count > 0 {
        return (attributes, append > 0 ? append : nil)
    } else {
        return nil
    }
}

private func getAttributesSupplementary(_ kind: SupplementaryKind, _ dataSource: SquareMosaicDataSource, _ direction: Direction, _ origin: CGFloat, rows: Int = 0, _ section: Int, sectionOrigin: CGFloat = 0, _ size: CGSize) -> (attributes: UICollectionViewLayoutAttributes, separator: CGFloat?)? {
    switch kind {
    case .backer:
        guard dataSource.layoutSupplementaryBackerRequired(for: section) == true else {
            return nil
        }
        let side = origin - sectionOrigin
        guard side > 0 else {
            return nil
        }
        let indexPath = IndexPath(item: 0, section: section)
        let attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: kind.value, with: indexPath)
        attributes.zIndex = -1
        switch direction {
        case .vertical:
            attributes.frame = CGRect(
                origin: CGPoint(x: 0.0, y: sectionOrigin),
                size: CGSize(width: size.width, height: side)
            )
        case .horizontal:
            attributes.frame = CGRect(
                origin: CGPoint(x: sectionOrigin, y: 0.0),
                size: CGSize(width: side, height: size.height)
            )
        }
        return (attributes, nil)
    default:
        guard let supplementary = getSupplementary(kind, dataSource: dataSource, section: section) else {
            return nil
        }
        guard rows > 0 || supplementary.supplementaryHiddenForEmptySection() == false else {
            return nil
        }
        let indexPath = IndexPath(item: 0, section: section)
        let attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: kind.value, with: indexPath)
        var separator: CGFloat
        attributes.zIndex = 1
        switch direction {
        case .vertical:
            attributes.frame = supplementary.supplementaryFrame(for: origin, side: size.width)
            separator =  attributes.frame.origin.y + attributes.frame.height - origin
        case .horizontal:
            attributes.frame = supplementary.supplementaryFrame(for: origin, side: size.height)
            separator =  attributes.frame.origin.x + attributes.frame.width - origin
        }
        return (attributes, separator)
    }
}

private func getSectionNonEmpty(_ dataSource: SquareMosaicDataSource, _ rows: Int, _ section: Int) -> Bool {
    if rows > 0 {
        return true
    } else if dataSource.layoutSupplementaryHeader(for: section)?.supplementaryHiddenForEmptySection() == false {
        return true
    } else if dataSource.layoutSupplementaryFooter(for: section)?.supplementaryHiddenForEmptySection() == false {
        return true
    } else {
        return false
    }
}

private func getSectionsNonEmpty(_ dataSource: SquareMosaicDataSource, _ numberOfItemsInSections: [Int]) -> SectionsNonEmpty {
    let sectionsNonEmpty = numberOfItemsInSections
        .enumerated()
        .map({ (rows: $0.element, section: $0.offset) })
        .filter({ object -> Bool in
            return getSectionNonEmpty(dataSource, object.rows, object.section)
        })
    switch sectionsNonEmpty.count {
    case 2...:
        let sections = sectionsNonEmpty.map({ $0.section })
        return SectionsNonEmpty.multiple(sections)
    case 1:
        let section = sectionsNonEmpty[0].section
        return SectionsNonEmpty.single(section)
    default:
        return SectionsNonEmpty.none
    }
}

private func getSeparatorBeforeSection(_ dataSource: SquareMosaicDataSource, section: Int, sectionsNonEmpty: SectionsNonEmpty) -> CGFloat? {
    switch sectionsNonEmpty {
    case .multiple(let sections):
        let separator = dataSource.layoutSeparatorBetweenSections()
        switch separator {
        case ...0:
            return nil
        default:
            switch sections.dropFirst().contains(section) {
            case true:
                return separator
            case false:
                return nil
            }
        }
    default:
        return nil
    }
}

private func getSeparatorBlock(_ position: BlockSeparatorPosition, blocks: Int = 0, index: Int = 0, pattern: Pattern, rows: Int = 0) -> CGFloat? {
    switch (position, rows > 0, index > 0 && index < blocks) {
    case (.before, true, _), (.between, _, true), (.after, true, _):
        return pattern.patternBlocksSeparator(at: position)
    default:
        return nil
    }
}

private func getSupplementary(_ kind: SupplementaryKind, dataSource: SquareMosaicDataSource, section: Int) -> Supplementary? {
    switch kind {
    case .footer:
        return dataSource.layoutSupplementaryFooter(for: section)
    case .header:
        return dataSource.layoutSupplementaryHeader(for: section)
    default:
        return nil
    }
}

import Foundation

enum MultiviewLayout: String, Codable, CaseIterable {
    case auto, single, inset, mainPlusOne, mainPlusTwo, mainPlusThree, grid
    var capacity: Int? {
        switch self { case .auto, .grid: return nil; case .single: return 1; case .inset, .mainPlusOne: return 2; case .mainPlusTwo: return 3; case .mainPlusThree: return 4 }
    }
    func supports(count: Int) -> Bool { capacity.map { count <= $0 } ?? true }
    func afterAdding(count: Int) -> MultiviewLayout { supports(count: count) ? self : .auto }
    func slotCount(players: Int) -> Int { max(1, capacity ?? players) }
    var titleKey: String { "layout_" + rawValue }
}

/// Pure geometry shared by the viewer, selector illustrations, and tests.
struct PlayerLayoutGeometry {
    var layout: MultiviewLayout
    var count: Int
    var bounds: CGRect
    var frames: [CGRect] {
        let choice = layout.supports(count: count) ? layout : .auto
        let slots = choice.slotCount(players: count)
        guard bounds.width > 0, bounds.height > 0 else { return Array(repeating: .zero, count: slots) }
        switch choice {
        case .single: return [bounds]
        case .inset:
            let width = bounds.width * 0.30
            let height = min(bounds.height * 0.40, width * 9 / 16)
            let margin = min(24, bounds.width * 0.02)
            return [bounds, CGRect(x: bounds.maxX - width - margin, y: bounds.maxY - height - margin, width: width, height: height)]
        case .mainPlusOne, .mainPlusTwo, .mainPlusThree:
            return sidebar(slots: slots)
        case .grid: return grid(slots: slots)
        case .auto:
            if count <= 1 { return [bounds] }
            if count <= 4 { return sidebar(slots: count) }
            if count <= 6 {
                let width = bounds.width * 0.666
                let mainHeight = bounds.height * 0.666
                let bottom = count - 4
                return [CGRect(x: bounds.minX, y: bounds.minY, width: width, height: mainHeight)]
                    + (0..<3).map { CGRect(x: bounds.minX + width, y: bounds.minY + CGFloat($0) * bounds.height / 3, width: bounds.width - width, height: bounds.height / 3) }
                    + (0..<bottom).map { CGRect(x: bounds.minX + CGFloat($0) * width / CGFloat(bottom), y: bounds.minY + mainHeight, width: width / CGFloat(bottom), height: bounds.height - mainHeight) }
            }
            return grid(slots: slots)
        }
    }
    private func sidebar(slots: Int) -> [CGRect] {
        let width = bounds.width * 2 / 3
        let height = bounds.height / CGFloat(slots - 1)
        return [CGRect(x: bounds.minX, y: bounds.minY, width: width, height: bounds.height)]
            + (0..<(slots - 1)).map { CGRect(x: bounds.minX + width, y: bounds.minY + CGFloat($0) * height, width: bounds.width - width, height: height) }
    }
    private func grid(slots: Int) -> [CGRect] {
        let columns = Int(ceil(sqrt(Double(slots))))
        let rows = Int(ceil(Double(slots) / Double(columns)))
        let width = min(bounds.width / CGFloat(columns), bounds.height / CGFloat(rows) * 16 / 9)
        let height = width * 9 / 16
        let x = bounds.minX + (bounds.width - width * CGFloat(columns)) / 2
        let y = bounds.minY + (bounds.height - height * CGFloat(rows)) / 2
        return (0..<slots).map { CGRect(x: x + CGFloat($0 % columns) * width, y: y + CGFloat($0 / columns) * height, width: width, height: height) }
    }
}

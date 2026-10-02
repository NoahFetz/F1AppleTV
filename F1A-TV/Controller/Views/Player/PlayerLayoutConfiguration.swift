import UIKit

struct PlayerLayoutConfiguration {
    let playerCount: Int
    var mainPlayerIndex = 0
    let bounds: CGRect
    var choice = MultiviewLayout.auto
    var frames: [CGRect] { PlayerLayoutGeometry(layout: choice, count: playerCount, bounds: bounds).frames }
    func frame(for index: Int) -> CGRect { frames.indices.contains(index) ? frames[index] : .zero }
    var contentSize: CGSize { bounds.size }
}

final class PlayerGridLayout: UICollectionViewLayout {
    var mainPlayerIndex = 0
    var choice = MultiviewLayout.auto
    var playerCount = 0
    private var frames = [CGRect]()
    override func prepare() {
        super.prepare()
        guard let collectionView else { return }
        frames = PlayerLayoutGeometry(layout: choice, count: playerCount, bounds: CGRect(origin: .zero, size: collectionView.bounds.size)).frames
    }
    override var collectionViewContentSize: CGSize { collectionView?.bounds.size ?? .zero }
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        frames.indices.compactMap { index in
            guard frames[index].intersects(rect) else { return nil }
            return layoutAttributesForItem(at: IndexPath(item: index, section: 0))
        }
    }
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard frames.indices.contains(indexPath.item) else { return nil }
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = frames[indexPath.item]
        attributes.zIndex = choice == .inset && indexPath.item > 0 ? 1 : 0
        return attributes
    }
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool { collectionView?.bounds.size != newBounds.size }
}

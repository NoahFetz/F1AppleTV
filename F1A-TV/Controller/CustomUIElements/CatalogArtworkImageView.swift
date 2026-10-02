import UIKit
import Kingfisher

/// Artwork belongs to one item. Cached backgrounds are reserved for fullscreen backdrops.
final class CatalogArtworkImageView: UIImageView {
    private var pictureID: String?
    private var focusScale: CGFloat = 1
    private var request: CatalogArtworkRequest?

    func configure(_ pictureID: String?, focusScale: CGFloat = 1) {
        guard self.pictureID != pictureID || self.focusScale != focusScale else { return }
        reset()
        self.pictureID = pictureID
        self.focusScale = focusScale
        backgroundColor = ConstantsUtil.brandingItemColor
        setNeedsLayout()
    }

    func reset() {
        kf.cancelDownloadTask()
        // Invalidate Kingfisher's source identity even if a canceled disk read finishes later.
        kf.setImage(with: Optional<URL>.none)
        layer.removeAllAnimations()
        pictureID = nil; request = nil; image = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !isHidden, let screen = window?.screen else { return }
        guard let next = CatalogArtworkRequest(pictureID: pictureID, size: bounds.size,
                                               scale: max(screen.scale, screen.nativeScale), focusScale: focusScale,
                                               baseURL: URL(string: ConstantsUtil.imageResizerUrl)!), next != request else { return }
        request = next
        kf.cancelDownloadTask()
        // No fade from a different item, and memory-cache hits are applied immediately.
        kf.setImage(with: next.url, options: [.processor(DownsamplingImageProcessor(size: next.processingSize)),
                                            .scaleFactor(next.scale)])
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setNeedsLayout()
    }
}

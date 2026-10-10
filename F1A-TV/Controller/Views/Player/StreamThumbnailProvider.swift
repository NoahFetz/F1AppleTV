import F1Core
import UIKit
import AVFoundation
import Combine

@MainActor final class StreamThumbnailProvider {
    private let provider: PlaybackThumbnailProvider
    private var observation: AnyCancellable?
    var onNativeState: ((PlaybackNativePreviewState) -> Void)?
    init(player: FairPlayer, refreshEntitlement: @escaping () async throws -> PlaybackEntitlement) {
        provider = PlaybackThumbnailProvider(player: player, allowUnprotectedVideoFallback: true, refreshEntitlement: refreshEntitlement)
        observation = provider.$nativePreviewState.sink { [weak self] state in self?.onNativeState?(state) }
    }
    func cancel() { provider.cancel() }
    func suspend() { provider.suspend() }
    func reset() { provider.reset() }
    func request(at time: Double, completion: @escaping (PlaybackScrubPreview?) -> Void) {
        provider.requestPreview(at: time, completion: completion)
    }
}

final class ScrubVideoPreviewView: UIView {
    private var videoLayer: AVPlayerLayer?
    func install(_ layer: AVPlayerLayer?) {
        if videoLayer !== layer {
            videoLayer?.removeFromSuperlayer(); videoLayer = layer
            if let layer { self.layer.addSublayer(layer) }
        }
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        videoLayer?.frame = bounds
        CATransaction.commit()
    }
}

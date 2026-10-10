import Combine
#if canImport(F1Core)
import F1Core
#endif

@MainActor final class ScrubPreviewModel: ObservableObject {
    @Published private(set) var preview: PlaybackScrubPreview?
    @Published private(set) var loading = false
    private let provider: PlaybackThumbnailProvider
    private var nativeSurfaceObservation: AnyCancellable?
    private var presented = false

    init(provider: PlaybackThumbnailProvider) {
        self.provider = provider
        nativeSurfaceObservation = provider.$nativePreviewState.sink { [weak self] state in
            switch state {
            case .loading(let layer): self?.preview = .video(layer); self?.loading = true
            case .ready(let layer): self?.preview = .video(layer); self?.loading = false
            case .unavailable: self?.preview = nil; self?.loading = false
            case .idle: break
            }
        }
    }

    func request(_ seconds: Double) {
        // A new hover session may retry a failed preview. Continuous movement
        // over a rejected asset must not restart authentication on every pixel.
        if !presented, case .unavailable = provider.nativePreviewState { provider.suspend() }
        presented = true
        if preview == nil { loading = true }
        provider.requestPreview(at: seconds) { [weak self] preview in
            self?.preview = preview; self?.loading = false
        }
    }

    func hide() {
        // Hovering off the narrow slider is a presentation change. Let an
        // in-flight key exchange/first frame finish and retain its paused layer.
        presented = false
    }

    func reset() {
        presented = false
        provider.reset(); preview = nil; loading = false
    }
}

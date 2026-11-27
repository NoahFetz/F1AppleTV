import AVFoundation
import F1Core
import MetalKit

struct TVCompositeTile {
    let renderer: CompositeTileRenderer
    let rect: CGRect
}

@MainActor final class TVCompositePreviewCoordinator {
    private var loadTask: Task<Void, Never>?
    private var player: CompositePreviewPlayer?
    private var bundle: PreviewFeedBundle?
    private var syncTimer: Timer?
    var onChanged: (() -> Void)?
    var onFrame: (() -> Void)?
    var isLoading: Bool { loadTask != nil }

    func start(items: [ContentItem], loader: PreviewFeedLoader, reference: @escaping () -> AVPlayer?) {
        stop()
        guard let channel = items.first(where: { $0.contentSubtype == "REPLAY" && $0.channel != nil })?.channel else { return }
        loadTask = Task { [weak self] in
            let bundle = await loader.bundle(for: channel.contentID)
            guard let self, !Task.isCancelled else { return }
            guard let bundle, let source = bundle.composite,
                  let candidate = CompositePreviewPlayer(source: source) else {
                finishLoading()
                return
            }
            defer { if player !== candidate { candidate.stop() } }
            do {
                try await candidate.start(at: reference()?.currentTime().seconds ?? 0)
                try Task.checkCancellation()
                candidate.renderer.onFrame = { [weak self] in self?.onFrame?() }
                self.bundle = bundle
                player = candidate
                let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.synchronize(reference: reference()) }
                }
                syncTimer = timer
                RunLoop.main.add(timer, forMode: .common)
                synchronize(reference: reference())
            } catch {
                guard !Task.isCancelled else { return }
            }
            finishLoading()
        }
    }

    func tile(for item: ContentItem) -> TVCompositeTile? {
        guard let channel = item.channel, let id = bundle?.channelID(for: channel), let player,
              let rect = player.source.videoRects[id] else { return nil }
        return TVCompositeTile(renderer: player.renderer, rect: rect)
    }

    private func finishLoading() {
        loadTask = nil
        onChanged?()
    }

    private func synchronize(reference: AVPlayer?) {
        guard let player, let reference else { return }
        if !player.sync(to: reference.currentTime().seconds, rate: reference.rate) {
            stop()
            onChanged?()
        }
    }

    func stop() {
        loadTask?.cancel(); loadTask = nil
        syncTimer?.invalidate(); syncTimer = nil
        player?.stop(); player = nil
        bundle = nil
    }

    deinit { loadTask?.cancel(); syncTimer?.invalidate() }
}

@MainActor final class TVCompositeTileView: MTKView, MTKViewDelegate {
    private(set) weak var renderer: CompositeTileRenderer?
    private(set) var rect = CGRect.zero
    private var drawing = false
    private var redrawPending = false

    init(tile: TVCompositeTile) {
        super.init(frame: .zero, device: tile.renderer.device)
        renderer = tile.renderer
        rect = tile.rect
        colorPixelFormat = .bgra8Unorm
        enableSetNeedsDisplay = true
        isPaused = true
        isUserInteractionEnabled = false
        delegate = self
        setNeedsDisplay()
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { setNeedsDisplay() }

    func draw(in view: MTKView) {
        if drawing { redrawPending = true; return }
        guard let renderer, renderer.hasFrame, let descriptor = currentRenderPassDescriptor,
              let drawable = currentDrawable, let command = renderer.queue.makeCommandBuffer(),
              renderer.encode(rect: rect, descriptor: descriptor, into: command) else { return }
        drawing = true
        command.present(drawable)
        command.addCompletedHandler { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.drawing = false
                if self.redrawPending {
                    self.redrawPending = false
                    self.setNeedsDisplay()
                }
            }
        }
        command.commit()
    }
}

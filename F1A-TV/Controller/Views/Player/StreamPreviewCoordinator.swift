import AVFoundation

@MainActor
protocol PreviewPlaybackSession: AnyObject {
    var player: FairPlayer? { get }
    func start(item: ContentItem, referencePlayer: AVPlayer?, maximumHeight: Int, completion: @escaping (FairPlayer?) -> Void)
    func synchronize(reference: AVPlayer?, visible: Bool)
    func stop()
}

/// Owns only the visible previews and their immediate neighbours.
@MainActor
final class StreamPreviewCoordinator {
    private var sessions = [String: PreviewPlaybackSession]()
    private var ready = Set<String>()
    private var visible = Set<String>()
    private var items = [ContentItem]()
    private weak var reference: AVPlayer?
    private var timer: Timer?
    private var maximumHeight = 360
    private let makeSession: () -> PreviewPlaybackSession
    private var referenceProvider: (() -> AVPlayer?)?
    init(makeSession: @escaping () -> PreviewPlaybackSession) { self.makeSession = makeSession }
    var onReady: ((String, FairPlayer?) -> Void)?

    func configure(items: [ContentItem], reference: AVPlayer?, maximumHeight: Int, referenceProvider: (() -> AVPlayer?)? = nil) {
        stop()
        self.items = items; self.reference = reference; self.maximumHeight = maximumHeight; self.referenceProvider = referenceProvider
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in Task { @MainActor in self?.synchronize() } }
    }
    func update(visibleIndices: Set<Int>) {
        visible = Set(visibleIndices.filter { items.indices.contains($0) }.map { items[$0].previewIdentity })
        let window = PreviewWindow.indices(visible: visibleIndices, count: items.count)
        let wanted = Set(window.map { items[$0].previewIdentity })
        for key in Array(sessions.keys) where !wanted.contains(key) {
            sessions.removeValue(forKey: key)?.stop(); ready.remove(key)
            onReady?(key, nil)
        }
        for index in window.sorted() {
            let item = items[index], key = item.previewIdentity
            guard sessions[key] == nil else { continue }
            let session = makeSession(); sessions[key] = session
            session.start(item: item, referencePlayer: reference, maximumHeight: maximumHeight) { [weak self, weak session] player in
                guard let self, let session, self.sessions[key] === session else { return }
                if player != nil { self.ready.insert(key) }
                self.synchronize()
                self.onReady?(key, player)
            }
        }
        synchronize()
    }
    func player(for key: String) -> FairPlayer? { ready.contains(key) ? sessions[key]?.player : nil }
    private func synchronize() {
        let reference = referenceProvider?() ?? self.reference
        for (key, session) in sessions where ready.contains(key) {
            session.synchronize(reference: reference, visible: visible.contains(key))
        }
    }
    func stop() {
        timer?.invalidate(); timer = nil
        sessions.values.forEach { $0.stop() }; sessions.removeAll(); ready.removeAll(); visible.removeAll(); referenceProvider = nil
    }
    deinit {
        timer?.invalidate()
        let remaining = Array(sessions.values)
        Task { @MainActor in remaining.forEach { $0.stop() } }
    }
}

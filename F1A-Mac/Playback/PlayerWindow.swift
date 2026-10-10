import AppKit
import AVFoundation
import SwiftUI

@MainActor final class FeedPlaybackWindow: NSWindow {
    var playbackKey: ((String) -> Void)?
    private var playerObservation: NSKeyValueObservation?
    private var sizeObservation: NSKeyValueObservation?
    private var observationID = UUID()
    private var observing = false
    private(set) var chromeVisible = true
    private var chromeAnimationID = UUID()

    func setChromeVisible(_ visible: Bool, animated: Bool = true) {
        chromeVisible = visible
        let id = UUID(); chromeAnimationID = id
        let buttons = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap { standardWindowButton($0) }
        if !animated || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            buttons.forEach { $0.alphaValue = visible ? 1 : 0; $0.isHidden = !visible }
            return
        }
        if visible { buttons.forEach { $0.isHidden = false } }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.2 : 0
            buttons.forEach { $0.animator().alphaValue = visible ? 1 : 0 }
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.chromeAnimationID == id, !visible else { return }
                buttons.forEach { $0.isHidden = true }
            }
        }
    }

    func configure(player: AVPlayer) {
        observing = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        acceptsMouseMovedEvents = true
        contentAspectRatio = CGSize(width: 16, height: 9)
        playerObservation = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async { self?.observePresentationSize(player.currentItem) }
        }
    }

    private func observePresentationSize(_ item: AVPlayerItem?) {
        guard observing else { return }
        let id = UUID(); observationID = id
        sizeObservation = item?.observe(\.presentationSize, options: [.initial, .new]) { [weak self] item, _ in
            let size = item.presentationSize
            DispatchQueue.main.async {
                guard let self, self.observing, self.observationID == id else { return }
                self.applyAspectRatio(size)
            }
        }
    }

    func setAlwaysOnTop(_ enabled: Bool) { level = enabled ? .floating : .normal }

    func setFramePreservingAspect(_ proposed: CGRect, on bounds: CGRect) {
        let ratio = contentAspectRatio.width / contentAspectRatio.height
        let width = min(proposed.width, bounds.width, bounds.height * ratio)
        let resized = CGRect(x: min(max(proposed.minX, bounds.minX), bounds.maxX - width),
                             y: max(bounds.minY, min(proposed.maxY, bounds.maxY) - width / ratio),
                             width: width, height: width / ratio)
        setFrame(resized, display: true)
    }

    private func applyAspectRatio(_ size: CGSize) {
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return }
        let ratio = size.width / size.height
        guard abs(contentAspectRatio.width / contentAspectRatio.height - ratio) > 0.001 else { return }
        contentAspectRatio = size
        guard !styleMask.contains(.fullScreen) else { return }
        // Keep the upper edge stable when a stream reports its actual dimensions.
        let bounds = screen?.visibleFrame ?? frame
        setFramePreservingAspect(frame, on: bounds)
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown,
           !(firstResponder is NSTextView), !(firstResponder is NSTextField),
           event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
           let key = event.charactersIgnoringModifiers?.lowercased(),
           [" ", "m", "\u{f702}", "\u{f703}"].contains(key), let playbackKey {
            playbackKey(key)
            return
        }
        super.sendEvent(event)
    }

    override func close() {
        observing = false; observationID = UUID()
        chromeAnimationID = UUID()
        playerObservation = nil; sizeObservation = nil; playbackKey = nil
        super.close()
    }
}

/// Tracks activity across AVPlayerView and SwiftUI controls without intercepting input.
struct PlayerActivitySurface: NSViewRepresentable {
    var controlsVisible: Bool
    var presence: (Bool) -> Void
    var activity: () -> Void
    var trafficLightsHover: (Bool) -> Void = { _ in }
    func makeNSView(context: Context) -> ActivityView { ActivityView() }
    func updateNSView(_ view: ActivityView, context: Context) {
        view.presence = presence; view.activity = activity; view.controlsVisible = controlsVisible
        view.trafficLightsHover = trafficLightsHover
        view.updateWindowChrome()
    }
    static func dismantleNSView(_ view: ActivityView, coordinator: ()) { view.stop() }

    final class ActivityView: NSView {
        var presence: ((Bool) -> Void)?
        var activity: (() -> Void)?
        var controlsVisible = true
        var trafficLightsHover: ((Bool) -> Void)?
        private var overTrafficLights = false
        private let cursor = PlayerCursorVisibility()
        func updateWindowChrome() {
            if let window = window as? FeedPlaybackWindow, window.chromeVisible != controlsVisible {
                window.setChromeVisible(controlsVisible)
            }
            // Cursor visibility is app-wide, so only the foreground player under
            // the pointer may hide it. Inactive and covered windows must not.
            let pointerInside = window.map {
                bounds.contains(convert($0.mouseLocationOutsideOfEventStream, from: nil)) &&
                NSWindow.windowNumber(at: NSEvent.mouseLocation, belowWindowWithWindowNumber: 0) == $0.windowNumber
            } ?? false
            cursor.update(controlsVisible: controlsVisible, pointerInside: pointerInside,
                          windowActive: NSApp.isActive && window?.isKeyWindow == true && window?.isVisible == true)
        }
        private var tracking: NSTrackingArea?
        private var monitor: Any?
        private var observers: [NSObjectProtocol] = []
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let tracking { removeTrackingArea(tracking) }
            let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved], owner: self)
            addTrackingArea(area); tracking = area
        }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow(); stop()
            guard let window else { return }
            updateWindowChrome()
            for (name, object) in [(NSWindow.didResignKeyNotification, window as AnyObject?),
                                   (NSWindow.willCloseNotification, window),
                                   (NSWindow.willMiniaturizeNotification, window),
                                   (NSApplication.didResignActiveNotification, nil)] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.cursor.restore() }
                })
            }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown, .rightMouseDown, .scrollWheel, .keyDown]) { [weak self] event in
                if let self, let window = self.window, event.window === window {
                    self.cursor.restore()
                    self.activity?()
                    if [.mouseMoved, .leftMouseDragged, .leftMouseDown].contains(event.type) {
                        let overButtons = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap { window.standardWindowButton($0) }.contains {
                            $0.bounds.contains($0.convert(event.locationInWindow, from: nil))
                        }
                        if self.overTrafficLights != overButtons {
                            self.overTrafficLights = overButtons; self.trafficLightsHover?(overButtons)
                        }
                    }
                }
                return event
            }
        }
        override func mouseEntered(with event: NSEvent) { cursor.restore(); presence?(true) }
        override func mouseExited(with event: NSEvent) {
            cursor.restore()
            overTrafficLights = false; trafficLightsHover?(false); presence?(false)
        }
        override func mouseMoved(with event: NSEvent) { cursor.restore(); activity?() }
        func stop() {
            cursor.restore()
            if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil
            observers.forEach(NotificationCenter.default.removeObserver); observers.removeAll()
        }
        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
            observers.forEach(NotificationCenter.default.removeObserver)
        }
    }
}

/// Uses AppKit's automatic restoration on mouse movement, with explicit cleanup
/// for keyboard activity, window changes and removal of the player surface.
@MainActor final class PlayerCursorVisibility {
    private(set) var hidden = false
    private let setHidden: (Bool) -> Void
    init(setHidden: @escaping (Bool) -> Void = { NSCursor.setHiddenUntilMouseMoves($0) }) {
        self.setHidden = setHidden
    }
    func update(controlsVisible: Bool, pointerInside: Bool, windowActive: Bool) {
        let shouldHide = !controlsVisible && pointerInside && windowActive
        guard hidden != shouldHide else { return }
        hidden = shouldHide
        setHidden(shouldHide)
    }
    func restore() { update(controlsVisible: true, pointerInside: false, windowActive: false) }
    deinit { if hidden { setHidden(false) } }
}

@MainActor final class PlayerChrome: ObservableObject {
    @Published private(set) var visible = true
    private var pointerInside = false
    private var interacting = false
    private var hideTask: Task<Void, Never>?
    private let delay: Duration
    init(delay: Duration = .seconds(3)) { self.delay = delay }

    func presence(_ inside: Bool) {
        pointerInside = inside
        if inside { activity() }
        else if !interacting { hideTask?.cancel(); visible = false }
    }
    func activity() {
        visible = true; scheduleHide()
    }
    func hold(_ active: Bool) {
        interacting = active
        if active { hideTask?.cancel(); visible = true }
        else if pointerInside { scheduleHide() }
        else { hideTask?.cancel(); visible = false }
    }
    private func scheduleHide() {
        hideTask?.cancel()
        guard !interacting else { return }
        hideTask = Task { [weak self, delay] in
            do { try await Task.sleep(for: delay) } catch { return }
            guard let self, !self.interacting else { return }
            self.visible = false
        }
    }
    func stop() { hideTask?.cancel(); hideTask = nil }
    deinit { hideTask?.cancel() }
}

import AppKit
import AVKit
import SwiftUI

enum PlayerDynamicRange: String, CaseIterable, Identifiable {
    case automatic, sdr, hdr
    var id: String { rawValue }
    var label: String {
        switch self { case .automatic: "Automatic"; case .sdr: "SDR"; case .hdr: "HDR" }
    }
    func renderingPolicy(supportsHDR: Bool) -> AVDisplayDynamicRange {
        switch self {
        case .automatic: supportsHDR ? .automatic : .standard
        case .sdr: .standard
        case .hdr: supportsHDR ? .high : .standard
        }
    }
}

struct NativePlayerSurface: NSViewRepresentable {
    let player: AVPlayer
    var dynamicRange: PlayerDynamicRange = .automatic
    var displayChanged: (String, Bool) -> Void = { _, _ in }
    func makeNSView(context: Context) -> PlayerVideoView {
        let view = PlayerVideoView(); view.controlsStyle = .none; view.player = player; view.videoGravity = .resizeAspect
        return view
    }
    func updateNSView(_ view: PlayerVideoView, context: Context) {
        view.displayChanged = displayChanged
        if view.player !== player { view.player = player }
        view.dynamicRange = dynamicRange
        view.updateDisplay()
    }
    static func dismantleNSView(_ view: PlayerVideoView, coordinator: ()) { view.stop(); view.player = nil }
}

final class PlayerVideoView: AVPlayerView {
    var dynamicRange = PlayerDynamicRange.automatic
    var displayChanged: ((String, Bool) -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var lastDisplay: String?
    private var lastSupportsHDR: Bool?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow(); removeObservers()
        lastDisplay = nil; lastSupportsHDR = nil
        guard let window else { return }
        for (name, object) in [(NSWindow.didChangeScreenNotification, window as AnyObject?), (NSApplication.didChangeScreenParametersNotification, nil)] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.updateDisplay() }
            })
        }
        updateDisplay()
    }
    func updateDisplay() {
        let screen = window?.screen
        let name = screen?.localizedName ?? "Unknown display"
        let supportsHDR = (screen?.maximumPotentialExtendedDynamicRangeColorComponentValue ?? 1) > 1
        preferredDisplayDynamicRange = dynamicRange.renderingPolicy(supportsHDR: supportsHDR)
        if name != lastDisplay || supportsHDR != lastSupportsHDR {
            lastDisplay = name; lastSupportsHDR = supportsHDR
            DispatchQueue.main.async { [weak self] in self?.displayChanged?(name, supportsHDR) }
        }
    }
    // AVPlayerView's internal video subviews must not swallow window dragging.
    // SwiftUI controls above this surface retain their own hit testing.
    override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point) == nil ? nil : self }
    override func mouseDown(with event: NSEvent) {
        guard let window, !window.styleMask.contains(.fullScreen) else { return }
        window.performDrag(with: event)
    }
    private func removeObservers() { observers.forEach(NotificationCenter.default.removeObserver); observers.removeAll() }
    func stop() { removeObservers(); displayChanged = nil }
    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
}

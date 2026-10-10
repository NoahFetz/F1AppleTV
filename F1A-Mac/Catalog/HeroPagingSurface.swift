import SwiftUI
import AppKit

/// macOS paging needs to handle discrete horizontal wheels as well as phased
/// trackpad gestures. Vertical input continues to the enclosing catalog scroll.
struct HeroPagingSurface: NSViewRepresentable {
    let advance: (Int) -> Void
    final class PagingView: NSView {
        var advance: ((Int) -> Void)?
        var monitor: Any?
        private var distance: CGFloat = 0
        private var completedGesture = false
        private var lastInput = TimeInterval.zero
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        func install() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let window, event.window === window,
                      bounds.contains(convert(event.locationInWindow, from: nil)),
                      abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return event }
                let phased = !event.phase.isEmpty || !event.momentumPhase.isEmpty
                if event.phase.contains(.began) || event.timestamp - lastInput > 0.3 {
                    distance = 0; completedGesture = false
                }
                lastInput = event.timestamp
                if event.momentumPhase.isEmpty && !completedGesture {
                    distance += event.scrollingDeltaX
                    let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 32 : 3
                    if abs(distance) >= threshold {
                        advance?(distance < 0 ? 1 : -1)
                        distance = 0
                        if phased { completedGesture = true }
                    }
                }
                // Swallow momentum for the gesture already handled by this surface.
                return nil
            }
        }
        func removeMonitor() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
    func makeNSView(context: Context) -> PagingView { let view = PagingView(); view.advance = advance; view.install(); return view }
    func updateNSView(_ view: PagingView, context: Context) { view.advance = advance }
    static func dismantleNSView(_ view: PagingView, coordinator: ()) { view.removeMonitor(); view.advance = nil }
}

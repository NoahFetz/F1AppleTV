import AppKit
import AVFoundation
import AVKit

@main struct PlayerWindowTests {
    @MainActor static func main() async throws {
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
        }
        let chrome = PlayerChrome(delay: .milliseconds(40))
        chrome.presence(true)
        check(chrome.visible, "Mouse entry must reveal controls")
        try await Task.sleep(for: .milliseconds(90))
        check(!chrome.visible, "Stationary pointer over video must hide controls")
        chrome.activity()
        check(chrome.visible, "Movement must reveal controls")
        chrome.hold(true)
        try await Task.sleep(for: .milliseconds(90))
        check(chrome.visible, "Controls, scrubbing and popovers must hold controls open")
        chrome.presence(false)
        check(chrome.visible, "Leaving during interaction must preserve controls")
        chrome.hold(false)
        check(!chrome.visible, "Ending interaction outside must hide controls")
        chrome.presence(true)
        chrome.presence(false)
        check(!chrome.visible, "Mouse exit must hide immediately")
        chrome.activity()
        try await Task.sleep(for: .milliseconds(25))
        chrome.activity()
        try await Task.sleep(for: .milliseconds(25))
        check(chrome.visible, "Superseded hide tasks must not hide active controls")
        chrome.stop()
        try await Task.sleep(for: .milliseconds(90))
        check(chrome.visible, "Teardown must cancel the idle task")
        print("PASS: control entry, idle, interaction hold, exit, stale timer and teardown")

        var cursorChanges: [Bool] = []
        var cursor: PlayerCursorVisibility? = PlayerCursorVisibility { cursorChanges.append($0) }
        cursor?.update(controlsVisible: true, pointerInside: true, windowActive: true)
        cursor?.update(controlsVisible: false, pointerInside: false, windowActive: true)
        cursor?.update(controlsVisible: false, pointerInside: true, windowActive: false)
        check(cursorChanges.isEmpty, "Visible controls, outside pointers and inactive windows must not hide the cursor")
        cursor?.update(controlsVisible: false, pointerInside: true, windowActive: true)
        cursor?.update(controlsVisible: false, pointerInside: true, windowActive: true)
        check(cursorChanges == [true], "Idle foreground playback must hide the cursor once")
        cursor?.restore()
        cursor?.restore()
        check(cursorChanges == [true, false], "Input and teardown must restore only the player's cursor hide")
        for state in [(true, true, true), (false, false, true), (false, true, false)] {
            cursor?.update(controlsVisible: false, pointerInside: true, windowActive: true)
            cursor?.update(controlsVisible: state.0, pointerInside: state.1, windowActive: state.2)
            check(cursor?.hidden == false && cursorChanges.suffix(2) == [true, false],
                  "Controls appearing, pointer exit and window deactivation must restore the cursor")
        }
        cursor?.update(controlsVisible: false, pointerInside: true, windowActive: true)
        cursor = nil
        check(cursorChanges.suffix(2) == [true, false], "Releasing an idle player must restore the cursor")
        print("PASS: idle cursor, duplicate updates, activity, exit, inactive windows and teardown")

        _ = NSApplication.shared
        if let path = ProcessInfo.processInfo.environment["F1_MAC_ICON_BUNDLE"], let bundle = Bundle(path: path) {
            check(DesktopApplicationIcon.install(from: bundle), "The bundled app icon must decode")
            let bundledIcon = NSImage(contentsOf: bundle.url(forResource: "AppIcon", withExtension: "icns")!)!
            check(NSImage(named: "NSApplicationIcon")?.tiffRepresentation == bundledIcon.tiffRepresentation, "AppKit panels must use the bundled icon")
            check(NSApp.applicationIconImage?.isValid == true, "The Dock icon must decode")
            print("PASS: bundled app icon and AppKit named-image cache")
        }
        let window = FeedPlaybackWindow(contentRect: CGRect(x: 0, y: 0, width: 800, height: 450),
                                        styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                                        backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.configure(player: AVPlayer())
        let trafficLights = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap { window.standardWindowButton($0) }
        check(trafficLights.count == 3, "All native traffic lights must remain available")
        window.setChromeVisible(false, animated: false)
        check(trafficLights.allSatisfy { $0.isHidden && $0.alphaValue == 0 }, "Hidden traffic lights must not intercept clicks")
        window.setChromeVisible(true, animated: false)
        check(trafficLights.allSatisfy { !$0.isHidden && $0.alphaValue == 1 }, "Activity must restore native window buttons")
        window.setChromeVisible(false)
        window.setChromeVisible(true)
        try await Task.sleep(for: .milliseconds(350))
        check(trafficLights.allSatisfy { !$0.isHidden }, "A superseded fade must not hide newly revealed buttons")
        print("PASS: traffic-light hide/reveal and superseded animation")
        check(window.titlebarAppearsTransparent && window.styleMask.contains(.fullSizeContentView), "Video must extend under a transparent title bar")
        check(window.contentAspectRatio == CGSize(width: 16, height: 9), "Default window aspect must match video")
        let bounds = CGRect(x: 0, y: 0, width: 1440, height: 900)
        window.setFramePreservingAspect(CGRect(x: 1300, y: -100, width: 800, height: 600), on: bounds)
        check(abs(window.frame.width / window.frame.height - 16.0 / 9) < 0.001, "Restored frames must preserve aspect")
        check(bounds.contains(window.frame), "Restored windows must stay on screen")
        window.setAlwaysOnTop(true)
        check(window.level == .floating, "Pin must use floating window level")
        window.setAlwaysOnTop(false)
        check(window.level == .normal, "Unpin must restore normal window level")
        let video = PlayerVideoView(frame: CGRect(x: 0, y: 0, width: 800, height: 450))
        video.controlsStyle = .none
        window.contentView = video
        check(video.hitTest(CGPoint(x: 400, y: 225)) === video, "The video must handle middle-window dragging")
        video.dynamicRange = .sdr; video.updateDisplay()
        check(video.preferredDisplayDynamicRange == .standard, "SDR selection must reach AVKit")
        check(PlayerDynamicRange.automatic.renderingPolicy(supportsHDR: false) == .standard, "Automatic must restrict SDR screens to SDR")
        check(PlayerDynamicRange.hdr.renderingPolicy(supportsHDR: false) == .standard, "Explicit HDR must remain compatible with SDR displays")
        check(PlayerDynamicRange.automatic.renderingPolicy(supportsHDR: true) == .automatic, "Automatic must allow HDR on capable displays")
        check(PlayerDynamicRange.hdr.renderingPolicy(supportsHDR: true) == .high, "HDR selection must allow extended range")
        print("PASS: video drag hit testing, SDR override and HDR/SDR display policies")
        window.close()
        print("PASS: full-window video, aspect-preserving restoration, visible bounds and pin/unpin")
    }
}

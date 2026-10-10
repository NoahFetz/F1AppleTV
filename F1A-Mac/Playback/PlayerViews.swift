import SwiftUI
import AppKit
import AVKit
import F1Core

struct FeedPlayerView: View {
    @ObservedObject var feed: DesktopFeed
    @ObservedObject var session: DesktopSession
    @State private var scrubbing = false
    @State private var scrubPosition = 0.0
    @State private var hoverPosition: Double?
    @State private var timelineWidth: CGFloat = 1
    @State private var controlsHovered = false
    @State private var trafficLightsHovered = false
    @State private var scrubFramesEnabled: Bool
    @StateObject private var chrome = PlayerChrome()
    @StateObject private var thumbnail: ScrubPreviewModel
    init(feed: DesktopFeed, session: DesktopSession) {
        self.feed = feed; self.session = session
        _scrubFramesEnabled = State(initialValue: session.services.preferences.player.scrubPreviews)
        _thumbnail = StateObject(wrappedValue: ScrubPreviewModel(provider: feed.thumbnails))
    }
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
            NativePlayerSurface(player: feed.player, dynamicRange: feed.dynamicRange) { name, supportsHDR in
                feed.displayName = name; feed.displaySupportsHDR = supportsHDR; feed.applyDynamicRange()
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                .frame(height: 190).allowsHitTesting(false).opacity(chrome.visible ? 1 : 0)
            GlassEffectContainer(spacing: 12) {
                controls.padding(16).glassEffect(.regular, in: .rect(cornerRadius: 22))
            }.padding(16)
                .onHover { controlsHovered = $0; updateChromeHold() }
                .opacity(chrome.visible ? 1 : 0)
                .allowsHitTesting(chrome.visible)
                .accessibilityHidden(!chrome.visible)
            if feed.loading { LoadingStatus(title: "Loading feed…").frame(maxHeight: .infinity) }
            if let error = feed.error {
                VStack(spacing: 12) { Text(error); Button("Retry") { session.load(feed) }.buttonStyle(.glassProminent) }
                    .padding(24).glassEffect(in: .rect(cornerRadius: 16)).frame(maxHeight: .infinity)
            }
        }.foregroundStyle(.white)
            .background(PlayerActivitySurface(controlsVisible: chrome.visible, presence: { chrome.presence($0) }, activity: { chrome.activity() }, trafficLightsHover: { trafficLightsHovered = $0; updateChromeHold() }))
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.2), value: chrome.visible)
            .overlay(alignment: .top) {
                if let message = session.message {
                    HStack { Text(message).font(.callout); Spacer(); Button("Dismiss") { session.message = nil } }
                        .padding(12).glassEffect(in: .rect(cornerRadius: 12)).padding(16)
                }
            }
            .onAppear { chrome.activity() }
            .onReceive(session.services.preferences.$player) { settings in
                scrubFramesEnabled = settings.scrubPreviews
                if !settings.scrubPreviews { thumbnail.reset() }
            }
            .onDisappear { chrome.stop(); thumbnail.reset(); if scrubbing { session.coordinator.isScrubbing = false } }
            .onChange(of: feed.dynamicRange) { _, _ in feed.applyDynamicRange() }
            .onChange(of: scrubbing) { _, _ in updateChromeHold() }
            .onChange(of: session.feedPickerAnchor) { _, _ in updateChromeHold() }
            .onChange(of: feed.loading) { _, loading in if loading { thumbnail.reset(); hoverPosition = nil; if scrubbing { scrubbing = false; session.coordinator.isScrubbing = false } } }
            .onChange(of: scrubPosition) { _, seconds in if scrubbing && scrubFramesEnabled { thumbnail.request(seconds) } }
    }
    private var controls: some View {
        VStack(spacing: 12) {
            if let range = feed.seekRange {
                HStack {
                    Text(time(scrubbing ? scrubPosition : feed.position)).font(.caption.monospacedDigit()).frame(minWidth: 44)
                    Slider(value: Binding(get: { scrubbing ? scrubPosition : min(max(feed.position, range.lowerBound), range.upperBound) }, set: { scrubPosition = $0 }), in: range) { editing in
                        scrubbing = editing; session.coordinator.isScrubbing = editing
                        if editing { scrubPosition = feed.position; if scrubFramesEnabled { thumbnail.request(scrubPosition) } }
                        else {
                            if hoverPosition != nil { hoverPosition = scrubPosition; if scrubFramesEnabled { thumbnail.request(scrubPosition) } } else { thumbnail.hide() }
                            session.coordinator.seek(from: feed.id, seconds: scrubPosition)
                        }
                    }.accessibilityLabel("Seek all feeds").tint(.red).disabled(feed.loading || feed.changingQuality)
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { timelineWidth = $0 }
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let point):
                                let fraction = min(max((point.x - 8) / max(1, timelineWidth - 16), 0), 1)
                                let seconds = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
                                hoverPosition = seconds
                                if !scrubbing && scrubFramesEnabled { thumbnail.request(seconds) }
                            case .ended:
                                hoverPosition = nil; if !scrubbing { thumbnail.hide() }
                            }
                        }
                        .overlay(alignment: .topLeading) {
                            GeometryReader { geometry in
                                let seconds = scrubbing ? scrubPosition : hoverPosition ?? scrubPosition
                                let fraction = min(max((seconds - range.lowerBound) / max(0.001, range.upperBound - range.lowerBound), 0), 1)
                                let trackX = 8 + max(0, geometry.size.width - 16) * fraction
                                // Only the wide frame preview needs an edge margin.
                                // The timecode can follow the pointer to either track endpoint.
                                let inset = scrubFramesEnabled ? min(104, geometry.size.width / 2) : 0
                                let x = min(max(trackX, inset), geometry.size.width - inset)
                                ScrubPreview(model: thumbnail, seconds: seconds, showsFrames: scrubFramesEnabled).position(x: x, y: scrubFramesEnabled ? -98 : -40)
                            }
                            // Keep AVFoundation's rendering host mounted while
                            // a first frame loads, including brief hover exits.
                            .opacity(scrubbing || hoverPosition != nil ? 1 : 0)
                            .accessibilityHidden(!scrubbing && hoverPosition == nil)
                            .allowsHitTesting(false)
                        }
                    Text(time(range.upperBound)).font(.caption.monospacedDigit()).frame(minWidth: 44)
                }
            }
            HStack(spacing: 10) {
                Button { session.coordinator.skip(from: feed.id, seconds: -10) } label: { Image(systemName: "gobackward.10").frame(width: 24, height: 24) }
                    .accessibilityLabel("Back 10 seconds in all feeds")
                Button { session.togglePlayback() } label: { Image(systemName: session.playing ? "pause.fill" : "play.fill").frame(width: 28, height: 24) }
                    .buttonStyle(.glassProminent).tint(.red).accessibilityLabel(session.playing ? "Pause all feeds" : "Play all feeds")
                Button { session.coordinator.skip(from: feed.id, seconds: 10) } label: { Image(systemName: "goforward.10").frame(width: 24, height: 24) }
                    .accessibilityLabel("Forward 10 seconds in all feeds")
                if feed.live { Button("Go Live") { session.coordinator.goLive(from: feed.id) }.disabled(feed.seekRange == nil) }
                Spacer(minLength: 4)
                Button { feed.muted.toggle() } label: { Image(systemName: feed.muted ? "speaker.slash.fill" : "speaker.wave.2.fill").frame(height: 24) }
                    .accessibilityLabel(feed.muted ? "Unmute this feed" : "Mute this feed")
                Slider(value: $feed.volume, in: 0...1).frame(width: 75).accessibilityLabel("Feed volume")
            }.disabled(feed.loading)
            HStack(spacing: 10) {
                CountryFlag(key: session.details?.item.race?.meetingCountryKey, country: session.details?.item.race?.meetingCountryName, width: 20)
                Text(feed.title).font(DesktopTypography.body(13, semibold: true)).lineLimit(1)
                Spacer(minLength: 4)
                Button { session.setAlwaysOnTop(feed, enabled: !feed.alwaysOnTop) } label: {
                    Image(systemName: feed.alwaysOnTop ? "pin.fill" : "pin")
                        .foregroundStyle(feed.alwaysOnTop ? Color.red : Color.white)
                }.help(feed.alwaysOnTop ? "Turn off Always on Top" : "Always on Top")
                    .accessibilityLabel("Always on Top")
                    .accessibilityValue(feed.alwaysOnTop ? "On" : "Off")
                Menu {
                    Picker("Stream dynamic range", selection: $feed.dynamicRange) {
                        ForEach(PlayerDynamicRange.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.inline)
                    Text("Display: \(feed.displayName) · \(feed.displaySupportsHDR ? "HDR capable" : "SDR")")
                    Text("\(feed.streamRangeName) · \(feed.dynamicRange == .sdr || !feed.displaySupportsHDR ? "SDR output" : "HDR allowed")")
                    if !feed.displaySupportsHDR { Text("HDR streams use SDR output on this display.") }
                    if !feed.player.availableVideoRanges.isEmpty {
                        Text("Available streams: " + feed.player.availableVideoRanges.joined(separator: ", "))
                        if feed.streamDynamicRange == .hdr && feed.player.effectiveDynamicRange == .sdr {
                            Text("HDR is unavailable for this feed; using SDR.")
                        } else if feed.streamDynamicRange == .sdr && feed.player.effectiveDynamicRange == .hdr {
                            Text("No SDR stream is available; rendering HDR in SDR.")
                        }
                    }
                    Divider()
                    Button("Default") { feed.player.selectResolution(nil) }.disabled(feed.player.resolutionStatus != .available)
                    ForEach(feed.player.availableResolutions, id: \.self) { resolution in
                        Button(resolution.label(in: feed.player.availableResolutions) + (resolution == feed.player.selectedResolution ? " ✓" : "")) { feed.player.selectResolution(resolution) }.disabled(feed.player.resolutionStatus != .available)
                    }
                    if let error = feed.player.resolutionError { Text(error) }
                } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Feed quality and dynamic range")
                Menu {
                    if !feed.audio.isEmpty {
                        Picker("Audio", selection: Binding(get: { feed.audioSelection }, set: { feed.selectAudio($0) })) {
                            Text("Stream default").tag(-1)
                            ForEach(Array(feed.audio.enumerated()), id: \.offset) { index, track in Text(track.displayName).tag(index) }
                        }.pickerStyle(.inline)
                    } else { Text("No alternate audio") }
                    Picker("Captions", selection: Binding(get: { feed.captionSelection }, set: { feed.selectCaption($0) })) {
                        Text("Off").tag(-1)
                        ForEach(Array(feed.captions.enumerated()), id: \.offset) { index, track in Text(track.displayName).tag(index) }
                    }.pickerStyle(.inline)
                } label: {
                    Label { Text(feed.audioName).lineLimit(1).frame(maxWidth: 82) } icon: { Image(systemName: "captions.bubble") }
                }.disabled(feed.loading || feed.changingQuality)
                    .help("Audio: \(feed.audioName) · Captions: \(feed.captionName)")
                    .accessibilityLabel("Audio: \(feed.audioName), captions: \(feed.captionName)")
                AddFeedButton(session: session, anchor: feed.id)
                Menu { SessionMenu(session: session) } label: { Image(systemName: "rectangle.on.rectangle") }.accessibilityLabel("Session controls")
            }
        }.buttonStyle(.glass).controlSize(.regular)
    }
    private func updateChromeHold() {
        chrome.hold(controlsHovered || trafficLightsHovered || scrubbing || session.feedPickerAnchor == feed.id)
    }
    private func time(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "--:--" }
        let value = max(0, Int(seconds)); return value >= 3600 ? String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60) : String(format: "%d:%02d", value / 60, value % 60)
    }
}

struct AddFeedButton: View {
    @ObservedObject var session: DesktopSession
    let anchor: String
    var body: some View {
        Button { session.showFeedPicker(anchor: anchor) } label: { Label("Add Feed", systemImage: "plus") }
            .disabled(session.details == nil)
            .popover(isPresented: Binding(get: { session.feedPickerAnchor == anchor }, set: { if !$0 && session.feedPickerAnchor == anchor { session.feedPickerAnchor = nil } }), arrowEdge: anchor == "catalog" ? .bottom : .top) {
                FeedPicker(session: session) { channel in
                    session.feedPickerAnchor = nil
                    // Focus the feed after the popover has relinquished its key window.
                    if let channel { DispatchQueue.main.async { session.open(channel) } }
                }
            }
    }
}
struct SessionMenu: View {
    @ObservedObject var session: DesktopSession
    var body: some View {
        Button("Add Feed…") { session.showFeedPicker() }.disabled(session.details == nil)
        Button("Sync All") { session.coordinator.synchronize() }.disabled(session.feeds.isEmpty)
        Button(session.playing ? "Pause All" : "Play All") { session.togglePlayback() }.disabled(session.feeds.isEmpty)
        Divider()
        Button("Save Setup…") { session.savingSetup = true }.disabled(session.feeds.isEmpty)
        Menu("Load Setup") {
            ForEach(session.setups) { setup in Button(setup.name) { session.restore(setup) } }
        }.disabled(session.details == nil || session.setups.isEmpty)
        Divider()
        Button("Close All Feed Windows") { session.closeAll() }.disabled(session.feeds.isEmpty)
    }
}

struct FeedPicker: View {
    @ObservedObject var session: DesktopSession
    var select: (PlaybackChannel?) -> Void
    @ObservedObject private var previews: FeedPreviewPool
    @State private var viewportHeight: CGFloat = 0
    @State private var rowFrames: [String: CGRect] = [:]
    @State private var search = ""
    init(session: DesktopSession, select: @escaping (PlaybackChannel?) -> Void) {
        self.session = session; self.select = select
        _previews = ObservedObject(wrappedValue: session.previews)
    }
    private var channels: [PlaybackChannel] {
        let sorting = session.services.preferences.player.driverChannelSorting
        return (session.details?.channels ?? []).filter {
            search.isEmpty || [$0.title, $0.driverFirstName ?? "", $0.driverLastName ?? "", $0.teamName, String($0.racingNumber)].joined(separator: " ").localizedCaseInsensitiveContains(search)
        }.sorted {
            if $0.kind != $1.kind { return $0.kind.getIdentifier() < $1.kind.getIdentifier() }
            return sorting.rawValue == 0 ? $0.racingNumber < $1.racingNumber : ($0.driverLastName ?? $0.title) < ($1.driverLastName ?? $1.title)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { CountryFlag(key: session.details?.item.race?.meetingCountryKey, country: session.details?.item.race?.meetingCountryName); Text("Add Feed").font(DesktopTypography.heading(20)); Spacer(); Button("Done") { select(nil) }.keyboardShortcut(.cancelAction) }
            TextField("Search feeds, drivers or teams", text: $search).textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(channels) { channel in
                        Button { select(channel) } label: {
                            HStack(spacing: 14) {
                                FeedPreviewThumbnail(channel: channel, feed: previews.feeds[channel.id])
                                    .frame(width: 144, height: 81).clipShape(.rect(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(channel.kind == .OnBoardCamera ? [channel.driverFirstName, channel.driverLastName].compactMap { $0 }.joined(separator: " ") : channel.title).font(.headline)
                                    if !channel.teamName.isEmpty { Text("\(channel.racingNumber) · \(channel.teamName)").font(.caption).foregroundStyle(.secondary) }
                                    if let error = previews.feeds[channel.id]?.error { Text(error).font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer(minLength: 4)
                                Image(systemName: session.feeds.contains(where: { $0.id == channel.id }) ? "rectangle.on.rectangle" : "plus.circle")
                            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.045), in: .rect(cornerRadius: 12)).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("feedPickerViewport")) } action: { frame in
                                rowFrames[channel.id] = frame
                                previews.setVisible(channel.id, visible: frame.maxY > 0 && frame.minY < viewportHeight)
                            }
                            .onDisappear { rowFrames.removeValue(forKey: channel.id); previews.setVisible(channel.id, visible: false) }
                    }
                }
                if channels.isEmpty { Text("No matching feeds").foregroundStyle(.secondary).padding(24) }
            }.coordinateSpace(name: "feedPickerViewport")
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    viewportHeight = height
                    for (id, frame) in rowFrames { previews.setVisible(id, visible: frame.maxY > 0 && frame.minY < height) }
                }
            Text("Previews are muted and follow the session timeline.").font(.caption).foregroundStyle(.secondary)
        }.padding(20).frame(width: 510, height: 480).preferredColorScheme(.dark)
            .onAppear { previews.beginPicking(channels: channels) }
            .onChange(of: channels.map(\.id)) { _, _ in previews.beginPicking(channels: channels) }
            .onDisappear { previews.endPicking() }
    }
}
struct SaveSetupView: View {
    @ObservedObject var session: DesktopSession
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save Setup").font(.title2.bold())
            Text("Save the open feeds, audio settings and window positions.").foregroundStyle(.secondary)
            TextField("Setup name", text: $session.setupName).textFieldStyle(.roundedBorder)
            HStack { Spacer(); Button("Cancel") { session.savingSetup = false }.keyboardShortcut(.cancelAction); Button("Save") { session.saveSetup(); dismiss() }.keyboardShortcut(.defaultAction).disabled(session.setupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(24).frame(width: 420).preferredColorScheme(.dark)
    }
}

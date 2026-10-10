import SwiftUI
import F1Core
import CoreGraphics
import AVFoundation
import AppKit
import Combine

struct ScrubPreview: View {
    @ObservedObject var model: ScrubPreviewModel
    let seconds: Double
    var showsFrames = true
    var body: some View {
        VStack(spacing: 6) {
            if showsFrames, let preview = model.preview {
                Group {
                    switch preview {
                    case .image(let image): Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit)
                    case .video(let layer): ScrubVideoSurface(videoLayer: layer)
                    }
                }.frame(width: 192, height: 108).clipShape(.rect(cornerRadius: 8))
                    .overlay {
                        if model.loading {
                            VStack(spacing: 6) { ProgressView().controlSize(.small); Text("Loading preview…").font(.caption) }
                                .padding(10).background(.black.opacity(0.65), in: .rect(cornerRadius: 8))
                        }
                    }
            } else if showsFrames {
                ZStack {
                    Color.black.opacity(0.45)
                    VStack(spacing: 6) { Image(systemName: "photo"); Text(model.loading ? "Loading preview…" : "Preview unavailable").font(.caption) }.foregroundStyle(.secondary)
                }
                    .frame(width: 192, height: 108).clipShape(.rect(cornerRadius: 8))
            }
            Text(Self.time(seconds)).font(.caption.monospacedDigit())
        }.padding(8).glassEffect(.regular, in: .rect(cornerRadius: 12)).allowsHitTesting(false)
            .accessibilityLabel("Preview at \(Self.time(seconds))")
    }
    private static func time(_ seconds: Double) -> String {
        let value = max(0, Int(seconds.isFinite ? seconds : 0))
        return value >= 3600 ? String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60) : String(format: "%d:%02d", value / 60, value % 60)
    }
}

private struct ScrubVideoSurface: NSViewRepresentable {
    let videoLayer: AVPlayerLayer
    func makeNSView(context: Context) -> ScrubVideoHost { ScrubVideoHost() }
    func updateNSView(_ view: ScrubVideoHost, context: Context) { view.install(videoLayer) }
    static func dismantleNSView(_ view: ScrubVideoHost, coordinator: ()) { view.install(nil) }
}

private final class ScrubVideoHost: NSView {
    private var videoLayer: AVPlayerLayer?
    override init(frame: NSRect) { super.init(frame: frame); wantsLayer = true }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func install(_ layer: AVPlayerLayer?) {
        if videoLayer !== layer {
            videoLayer?.removeFromSuperlayer(); videoLayer = layer
            if let layer { self.layer?.addSublayer(layer) }
        }
        needsLayout = true
    }
    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        videoLayer?.frame = bounds
        CATransaction.commit()
    }
}

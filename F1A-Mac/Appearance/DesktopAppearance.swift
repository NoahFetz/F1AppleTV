import SwiftUI
import AppKit
import F1Core

struct LoadingStatus: View {
    var title: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var active = false
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 3) {
                ForEach(0..<3) { index in
                    Capsule().fill(Color.red).frame(width: 4, height: 14)
                        .opacity(reduceMotion ? 0.8 : (active ? 1 : 0.25))
                        .scaleEffect(y: reduceMotion ? 1 : (active ? 1 : 0.5))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.55).repeatForever(autoreverses: true).delay(Double(index) * 0.15), value: active)
                }
            }.accessibilityHidden(true)
            Text(title).font(.callout.weight(.medium))
        }.padding(.horizontal, 18).padding(.vertical, 12)
            .glassEffect(in: .capsule).accessibilityElement(children: .combine)
            .onAppear { active = true }
    }
}

@MainActor final class DesktopBackdrop: ObservableObject {
    @Published private(set) var image: NSImage?
    private let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("DesktopCatalogBackdrop.jpg")
    init() { image = cache.flatMap { NSImage(contentsOf: $0) } }
    func load(picture: String?, size: CGSize) async {
        guard let url = picture.flatMap({ $0.hasPrefix("https://") ? URL(string: $0) : nil }) ?? CatalogArtworkRequest(pictureID: picture, size: size, scale: NSScreen.main?.backingScaleFactor ?? 2, maximumPixelDimension: 2560)?.url else { return }
        do {
            try await Task.sleep(nanoseconds: 150_000_000)
            try Task.checkCancellation()
            let (data, response) = try await URLSession.shared.data(from: url)
            try Task.checkCancellation()
            guard (response as? HTTPURLResponse)?.statusCode == 200, let image = NSImage(data: data) else { return }
            withAnimation(.easeInOut(duration: 0.35)) { self.image = image }
            if let cache { try? data.write(to: cache, options: .atomic) }
        } catch { /* Keep the last successful backdrop during navigation or an outage. */ }
    }
}

struct CatalogBackdropView: View {
    @ObservedObject var model: CatalogModel
    @ObservedObject var preferences: MacPreferences
    @StateObject private var backdrop = DesktopBackdrop()
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.082, green: 0.082, blue: 0.118)
                if let image = backdrop.image {
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        .blur(radius: 2).opacity(model.usesEventBackground ? 0.7 : 0.22)
                } else {
                    LinearGradient(colors: [Color(red: 0.09, green: 0.15, blue: 0.23), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Canvas { context, size in
                        for index in 0..<5 {
                            var line = Path()
                            line.move(to: CGPoint(x: size.width * 0.48 + CGFloat(index) * 45, y: size.height))
                            line.addLine(to: CGPoint(x: size.width * 0.83 + CGFloat(index) * 45, y: 0))
                            context.stroke(line, with: .color(.red.opacity(0.3 - Double(index) * 0.04)), lineWidth: index == 0 ? 20 : 3)
                        }
                    }.opacity(0.6)
                }
                if model.usesEventBackground { Color.black.opacity(0.25) }
                LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
            }
            .task(id: "\(model.artworkID ?? ""):\(Int(geometry.size.width)):\(Int(geometry.size.height)):\(preferences.player.followsHeroBackground)") {
                guard model.usesEventBackground || preferences.player.followsHeroBackground else { return }
                await backdrop.load(picture: model.artworkID, size: geometry.size)
            }
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

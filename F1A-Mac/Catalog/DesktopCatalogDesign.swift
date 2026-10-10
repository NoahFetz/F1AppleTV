import SwiftUI
import AppKit
import CoreText
import F1Core

@MainActor enum DesktopTypography {
    static func register() {
        for (name, ext) in [("Formula1-Bold", "ttf"), ("Formula1-Regular", "ttf"), ("Titillium-Regular", "otf"), ("Titillium-Semibold", "otf")] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
        }
    }
    static func heading(_ size: CGFloat) -> Font { .custom("Formula1-Display-Bold", size: size) }
    static func body(_ size: CGFloat = 16, semibold: Bool = false) -> Font { .custom(semibold ? "Titillium-Semibold" : "Titillium-Regular", size: size) }
}

enum DesktopTheme {
    static let red = Color(red: 225 / 255, green: 6 / 255, blue: 0)
    static let item = Color(red: 31 / 255, green: 31 / 255, blue: 39 / 255)
}
struct CatalogActionStyle: ButtonStyle {
    var compact = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        let highlighted = enabled && (hovering || focused || configuration.isPressed)
        configuration.label.font(DesktopTypography.body(compact ? 14 : 17, semibold: true))
            .padding(.horizontal, compact ? 14 : 22).padding(.vertical, compact ? 6 : 10)
            .frame(minWidth: compact ? 0 : 148)
            .foregroundStyle(highlighted ? .black : .white)
            .background(highlighted ? Color.white : DesktopTheme.item, in: .rect(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(focused ? DesktopTheme.red : .clear, lineWidth: 2) }
            .opacity(enabled ? 1 : 0.45).onHover { hovering = $0 }
    }
}
struct CountryFlag: View {
    var key: String?
    var country: String? = nil
    var width: CGFloat = 26
    var body: some View {
        if let key, !key.isEmpty {
            let url = URL(string: "https://ott-img.formula1.com/countries")?.appendingPathComponent(key + ".png")
            CatalogArtwork(picture: url?.absoluteString, size: CGSize(width: width, height: width * 0.72), fit: true)
                .frame(width: width, height: width * 0.72).clipShape(.rect(cornerRadius: 2))
                .accessibilityLabel(country.map { "\($0) flag" } ?? "Country flag")
        }
    }
}
struct CatalogSeriesBadge: View {
    let name: String?
    private var series: String { (name ?? "").uppercased() }
    var label: String {
        switch series {
        case "FORMULA 1": return "F1"
        case "FORMULA 2": return "F2"
        case "FORMULA 3": return "F3"
        case "F1 ACADEMY": return "F1 Academy"
        case let value where value.contains("PORSCHE"): return "PSC"
        default: return name ?? ""
        }
    }
    var color: Color {
        switch series {
        case "FORMULA 1": return DesktopTheme.red
        case "FORMULA 2": return Color(red: 0, green: 144 / 255, blue: 208 / 255)
        case "FORMULA 3": return .gray
        case let value where value.contains("PORSCHE"): return Color(red: 65 / 255, green: 120 / 255, blue: 177 / 255)
        default: return .white
        }
    }
    var body: some View {
        if !label.isEmpty {
            HStack(spacing: 8) {
                Rectangle().fill(color).overlay {
                    if series == "F1 ACADEMY" { LinearGradient(colors: [.cyan, Color(red: 188 / 255, green: 15 / 255, blue: 128 / 255)], startPoint: .top, endPoint: .bottom) }
                }.frame(width: 3, height: 18)
                Text(label).font(DesktopTypography.body(15, semibold: true))
            }.accessibilityElement(children: .combine)
        }
    }
}

struct CatalogFacts: View {
    let item: ContentItem
    var hero = false
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            CountryFlag(key: item.race?.meetingCountryKey, country: item.race?.meetingCountryName)
            if item.objectType == .Video {
                Text([item.uiDuration, item.contentSubtype].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
            } else if let race = item.race {
                Text([race.meetingCountryName, race.meetingDisplayDate].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
            } else if !hero {
                Text([item.uiDuration, item.contentSubtype].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
            }
        }.font(DesktopTypography.body(hero ? 17 : 14)).foregroundStyle(.secondary)
    }
}

struct CatalogDescriptionView: View {
    let item: ContentItem
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text(item.titleBrief ?? item.title ?? "").font(DesktopTypography.heading(24)); Spacer(); Button("Done") { dismiss() } }
            CatalogFacts(item: item, hero: true)
            ScrollView { Text(item.longDescription ?? "").font(DesktopTypography.body(19)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
        }.padding(28).frame(width: 680, height: 520).preferredColorScheme(.dark)
    }
}

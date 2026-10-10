import SwiftUI
import F1Core

struct CatalogCard: View {
    let item: ContentItem
    let poster: Bool
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geometry in
                    CatalogArtwork(picture: item.pictureUrl, size: geometry.size)
                }.aspectRatio(poster ? 2 / 3 : 16 / 9, contentMode: .fit).clipShape(.rect(cornerRadius: 10))
                Text(item.title ?? item.label ?? "").font(DesktopTypography.heading(14)).lineLimit(2, reservesSpace: true).frame(maxWidth: .infinity, alignment: .leading)
                CatalogFacts(item: item).frame(height: 20, alignment: .leading)
                if item.objectType == .Video { CatalogSeriesBadge(name: item.race?.series ?? item.series).frame(height: 18, alignment: .leading) }
                if let label = item.label, label != item.title { Text(label).font(DesktopTypography.body(14)).foregroundStyle(.secondary).lineLimit(1) }
            }.padding(8).background(hovering ? Color.white.opacity(0.08) : .clear, in: .rect(cornerRadius: 14))
        }.buttonStyle(.plain).onHover { hovering = $0 }.disabled(item.action == nil || (item.objectType == .Video && !item.canPlay))
    }
}

struct MainCatalogView: View {
    @ObservedObject var model: CatalogModel
    @ObservedObject var session: DesktopSession
    @ObservedObject var preferences: MacPreferences
    @State private var section = "catalog"
    var body: some View {
        NavigationSplitView {
            List(selection: sidebarSelection) {
                Section("Browse") {
                    ForEach(model.menu, id: \.identity) { entry in
                        Button { section = "catalog"; model.select(entry) } label: {
                            Label(entry.title, systemImage: symbol(entry))
                                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain).padding(.vertical, 5).tag("catalog:" + entry.identity)
                    }
                }
                Section {
                    Label("Account", systemImage: "person.crop.circle").tag("account")
                    Label("Settings", systemImage: "gearshape").tag("settings")
                    Label("Error Log", systemImage: "exclamationmark.bubble").tag("diagnostics")
                }
                if !session.feeds.isEmpty {
                    Section("Watching") {
                        Text(session.details?.item.title ?? "Current session").font(.caption).foregroundStyle(.secondary)
                        Button("Add Feed…") { session.showFeedPicker(anchor: "catalog") }
                        Button("Sync All") { session.coordinator.synchronize() }
                        Button("Close All") { session.closeAll() }
                    }
                }
            }.listStyle(.sidebar).tint(Color(nsColor: .controlAccentColor))
                .scrollContentBackground(.hidden).background(.ultraThinMaterial)
                .navigationTitle("Vroom TV").navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
        } detail: {
            Group {
                switch section {
                case "account": AccountView(services: session.services, session: session)
                case "settings": DesktopSettingsView(preferences: preferences, session: session)
                case "diagnostics": DiagnosticsView()
                default: catalog
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { CatalogBackdropView(model: model, preferences: preferences) }
        }
        .toolbar {
            if section == "catalog", model.history.count > 1 {
                ToolbarItem(placement: .navigation) { Button { model.back() } label: { Image(systemName: "chevron.left") }.help("Back") }
            }
            ToolbarItem { Button { model.load() } label: { Image(systemName: "arrow.clockwise") }.help("Refresh") }
            ToolbarItem { AddFeedButton(session: session, anchor: "catalog") }
            ToolbarItem { Menu { SessionMenu(session: session) } label: { Label("Session", systemImage: "rectangle.on.rectangle") } }
        }
        .overlay(alignment: .bottom) {
            if session.loading { LoadingStatus(title: "Preparing playback…").padding(24) }
        }
        .task { await model.start() }
        .alert("Playback", isPresented: Binding(get: { session.message != nil }, set: { if !$0 { session.message = nil } })) { Button("OK") { session.message = nil } } message: { Text(session.message ?? "") }
        .preferredColorScheme(.dark)
    }
    private var sidebarSelection: Binding<String?> {
        Binding(get: {
            guard section == "catalog" else { return section }
            return model.menu.first { $0.uri == model.history.first?.destination.uri }.map { "catalog:" + $0.identity }
        }, set: { selection in
            guard let selection else { return }
            if let entry = model.menu.first(where: { "catalog:" + $0.identity == selection }) {
                section = "catalog"; model.select(entry)
            } else { section = selection }
        })
    }
    private var catalog: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if model.loading { LoadingStatus(title: "Loading catalog…").frame(maxWidth: .infinity).padding(.vertical, 24) }
                if let error = model.error { VStack(alignment: .leading, spacing: 12) { Text(error); Button("Retry") { model.load() } }.padding(24) }
                ForEach(model.sections) { content in
                    CatalogSectionView(section: content, model: model, session: session)
                }
                if model.sections.isEmpty && !model.loading && model.error == nil { ContentUnavailableView("No content available", systemImage: "film") }
            }.padding(28)
        }
    }
    private func symbol(_ entry: CatalogMenuEntry) -> String {
        let href = entry.href.lowercased()
        if href.contains("archive") { return "archivebox" }
        if href == "/" || href.contains("home") { return "house.fill" }
        if href.contains("season") { return "flag.checkered" }
        return "play.rectangle"
    }
}

struct CatalogSectionView: View {
    let section: ContentSection
    @ObservedObject var model: CatalogModel
    @ObservedObject var session: DesktopSession
    @State private var featuredID: String?
    @State private var descriptionItem: ContentItem?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !section.title.isEmpty {
                HStack { Text(section.title).font(DesktopTypography.heading(20)); Spacer(); if let destination = section.viewAllAction { Button("view_all".localizedString) { model.navigate(destination, title: section.title) }.buttonStyle(CatalogActionStyle(compact: true)) } }
            }
            if !section.subtitle.isEmpty { Text(section.subtitle).font(DesktopTypography.body(16)).foregroundStyle(.secondary) }
            if let schedule = section.schedule { DesktopScheduleView(schedule: schedule) { activate($0) } }
            else if [.Hero, .GpBanner, .PageHeader].contains(section.layoutType), !section.items.isEmpty {
                if model.usesEventBackground, [.GpBanner, .PageHeader].contains(section.layoutType), let item = section.items.first {
                    hero(item, floating: true)
                } else { featuredCarousel }
            } else if section.layoutType.isHorizontal {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(section.items) { item in CatalogCard(item: item, poster: section.layoutType.isPoster) { activate(item) }.frame(width: section.layoutType.isPoster ? 180 : 280) }
                    }
                }.scrollIndicators(.hidden)
                    .contentMargins(.horizontal, 28, for: .scrollContent)
                    .padding(.horizontal, -28)
            } else if !section.items.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: section.layoutType.isPoster ? 150 : 230), spacing: 16)], spacing: 20) {
                    ForEach(section.items) { item in CatalogCard(item: item, poster: section.layoutType.isPoster) { activate(item) } }
                }
            }
        }.sheet(item: $descriptionItem) { item in
            CatalogDescriptionView(item: item)
        }
    }
    private var featuredIndex: Int { section.items.firstIndex { $0.id == featuredID } ?? 0 }
    private var featuredCarousel: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(section.items) { item in
                    hero(item).containerRelativeFrame(.horizontal).id(item.id)
                }
            }.scrollTargetLayout()
        }.scrollIndicators(.hidden).scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $featuredID)
            .frame(height: section.layoutType == .PageHeader ? 300 : 400)
            .clipShape(.rect(cornerRadius: 16))
            .background { HeroPagingSurface { advanceFeatured($0) } }
            .overlay {
                if section.items.count > 1 {
                    HStack {
                        featuredArrow("chevron.left", direction: -1, label: "Previous featured item")
                        Spacer()
                        featuredArrow("chevron.right", direction: 1, label: "Next featured item")
                    }.padding(.horizontal, 14)
                }
            }
            .overlay(alignment: .bottom) {
                if section.items.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                            Button { withAnimation { featuredID = item.id } } label: {
                                Capsule().fill(index == featuredIndex ? DesktopTheme.red : Color.white.opacity(0.4)).frame(width: index == featuredIndex ? 18 : 6, height: 6)
                            }.buttonStyle(.plain).accessibilityLabel("Featured item \(index + 1)")
                        }
                    }.padding(10).glassEffect(in: .capsule).padding(.bottom, 14)
                }
            }
            .onAppear { featuredID = section.items.first?.id; updateBackdrop() }
            .onChange(of: featuredID) { _, _ in updateBackdrop() }
            .onChange(of: section.items.map(\.id)) { _, _ in featuredID = section.items.first?.id }
    }
    private func featuredArrow(_ symbol: String, direction: Int, label: String) -> some View {
        Button {
            advanceFeatured(direction)
        } label: { Image(systemName: symbol).font(.headline).frame(width: 32, height: 32) }
            .buttonStyle(.glass).buttonBorderShape(.circle).accessibilityLabel(label)
    }
    private func advanceFeatured(_ direction: Int) {
        guard section.items.count > 1 else { return }
        let index = (featuredIndex + direction + section.items.count) % section.items.count
        withAnimation(.easeInOut(duration: 0.3)) { featuredID = section.items[index].id }
    }
    private func updateBackdrop() {
        guard !section.items.isEmpty else { return }
        model.artworkID = section.items[featuredIndex].pictureUrl
    }
    private func hero(_ item: ContentItem, floating: Bool = false) -> some View {
        ZStack(alignment: .bottomLeading) {
            if !floating {
                Button { activate(item) } label: {
                    GeometryReader { geometry in CatalogArtwork(picture: item.pictureUrl, size: geometry.size) }
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(item.action == nil || isCurrentDestination(item) || (item.objectType == .Video && !item.canPlay))
                    .accessibilityLabel(item.titleBrief ?? item.title ?? "Featured content")
                LinearGradient(stops: [.init(color: .clear, location: 0.1), .init(color: .black.opacity(0.92), location: 1)], startPoint: .top, endPoint: .bottom).allowsHitTesting(false)
            }
            VStack(alignment: .leading, spacing: 12) {
                Rectangle().fill(DesktopTheme.red).frame(width: 48, height: 3).allowsHitTesting(false)
                if section.layoutType == .GpBanner {
                    HStack(spacing: 10) {
                        CountryFlag(key: item.race?.meetingCountryKey, country: item.race?.meetingCountryName, width: 30)
                        if let country = item.race?.meetingCountryName { Text(country.uppercased()).font(DesktopTypography.body(18, semibold: true)) }
                    }
                }
                Text(section.layoutType == .GpBanner ? item.race?.meetingOfficialName ?? item.title ?? "" : item.titleBrief.flatMap { $0.isEmpty ? nil : $0 } ?? item.title ?? "")
                    .font(DesktopTypography.heading(section.layoutType == .PageHeader ? 26 : 30)).lineLimit(2).allowsHitTesting(false)
                if section.layoutType == .GpBanner {
                    Text([item.race?.championshipMeetingOrdinal.flatMap { $0.isEmpty ? nil : "\("catalog_round".localizedString) \($0)" }, item.race?.meetingDisplayDate].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "  |  "))
                        .font(DesktopTypography.body(17)).foregroundStyle(.secondary)
                } else { CatalogFacts(item: item, hero: true).allowsHitTesting(false) }
                if let description = item.longDescription, !description.isEmpty {
                    Text(description).font(DesktopTypography.body(18)).lineLimit(section.layoutType == .PageHeader ? 2 : 3).frame(maxWidth: 760, alignment: .leading).allowsHitTesting(false)
                }
                CatalogSeriesBadge(name: item.race?.series ?? item.series).allowsHitTesting(false)
                HStack(spacing: 12) {
                    if item.action != nil && !isCurrentDestination(item) {
                        Button { activate(item) } label: {
                            Label(item.objectType == .Video ? "catalog_watch_now".localizedString : "catalog_explore".localizedString, systemImage: item.objectType == .Video ? "play.fill" : "arrow.right")
                        }.disabled(item.objectType == .Video && !item.canPlay)
                    }
                    if (item.longDescription?.count ?? 0) > 220 { Button("catalog_more".localizedString) { descriptionItem = item } }
                }.buttonStyle(CatalogActionStyle())
            }.frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, floating ? 4 : section.items.count > 1 ? 62 : 28)
                .padding(.vertical, floating ? 16 : 0)
                .padding(.bottom, floating ? 0 : section.items.count > 1 ? 50 : 28)
        }.frame(height: floating ? nil : section.layoutType == .PageHeader ? 300 : 400).clipShape(.rect(cornerRadius: floating ? 0 : 16))
    }
    private func isCurrentDestination(_ item: ContentItem) -> Bool {
        if case .destination(let destination) = item.action { return model.history.last?.destination.uri == destination.uri }
        return false
    }
    private func activate(_ item: ContentItem) {
        guard let action = item.action else { return }
        switch action {
        case .destination(let destination): model.navigate(destination, item: item)
        case .playback: session.requestPlayback(item)
        }
    }
}

import Foundation

protocol CatalogService: Sendable {
    func menu() async throws -> [CatalogMenuEntry]
    func page(_ destination: CatalogDestination) async throws -> CatalogDocument
}
struct F1CatalogService: CatalogService {
    let client: APIClient
    let endpoints: APIEndpoints
    let diagnostics: @Sendable (CatalogDiagnostic) -> Void
    init(client: APIClient, endpoints: APIEndpoints, diagnostics: @escaping @Sendable (CatalogDiagnostic) -> Void = { context in guard !Task.isCancelled else { return }; AppErrorStore.shared.record(APIError.decoding.diagnostic, operation: context.scope == .menu ? .menu : .page, catalogContext: context) }) {
        self.client = client; self.endpoints = endpoints; self.diagnostics = diagnostics
    }
    func menu() async throws -> [CatalogMenuEntry] {
        let payload = try await client.envelope(CatalogPayloadDTO.self, request: endpoints.menu(), retryTransient: true)
        if (payload.containers?.dropped ?? 0) > 0 { diagnostics(CatalogDiagnostic(scope: .menu, reason: .malformedSibling)) }
        let entries = CatalogMapper.menu(payload, baseURL: endpoints.catalogBase)
        guard !entries.isEmpty else { throw APIError.invalidResponse }; return entries
    }
    func page(_ destination: CatalogDestination) async throws -> CatalogDocument {
        let payload = try await client.envelope(CatalogPayloadDTO.self, request: endpoints.page(destination.uri), retryTransient: true)
        guard let containers = payload.containers, !containers.values.isEmpty || containers.dropped == 0 else { throw APIError.invalidResponse }
        let sections = CatalogMapper.sections(payload, diagnostics: diagnostics)
        try Task.checkCancellation()
        return CatalogDocument(sections: sections)
    }
}

enum CatalogMapper {
    static func menu(_ payload: CatalogPayloadDTO, baseURL: URL = APIEndpoints().catalogBase) -> [CatalogMenuEntry] {
        return (payload.containers?.values ?? []).compactMap { node -> CatalogMenuEntry? in
            guard let m = node.metadata, m.type != "search", m.featureIdentifier != "my_list",
                  let action = node.actions?.values.first(where: { $0.key == "onClick" && $0.targetType == "PAGE" }),
                  !(action.href ?? "").contains("/search"), !(action.href ?? "").contains("/my-list"),
                  let title = m.label, !title.isEmpty,
                  CatalogRequest.url(for: action.uri, baseURL: baseURL) != nil else { return nil }
            return CatalogMenuEntry(title: title, uri: action.uri, href: action.href ?? "")
        }
    }
    static func item(_ node: CatalogNodeDTO, fallbackID: String) -> ContentItem {
        let m = node.metadata
        var item = ContentItem()
        item.objectType = .fromIdentifier(identifier: m?.contentType ?? m?.objectType ?? "")
        item.title = m?.title; item.titleBrief = m?.titleBrief; item.label = m?.label; item.longDescription = m?.longDescription
        let id = m?.contentId?.value ?? node.contentId?.value
        item.contentId = id.flatMap { Int64($0).map { $0 > 0 ? String($0) : nil } ?? nil }
        item.pictureUrl = m?.pictureUrl ?? node.platformVariants?.values.first?.pictureUrl
        item.race = m?.emfAttributes?.model; item.series = item.race?.series ?? node.properties?.values.first?.series
        item.contentSubtype = m?.contentSubtype; item.uiDuration = m?.uiDuration
        item.interactive = m?.interactive; item.locked = m?.locked; item.resumePosition = node.user?.resume?.playHeadPosition
        if item.objectType == .Video, let contentID = item.contentId {
            let uri = m?.additionalStreams?.values.first?.playbackUrl ?? contentID
            item.action = .playback(PlaybackTarget(uri: uri, requiresVideoDetails: item.race?.videoType == "meetingSession"))
        } else if let action = node.actions?.values.first(where: { $0.key == "onClick" && !$0.uri.isEmpty }) {
            item.action = .destination(CatalogDestination(uri: action.uri, href: action.href ?? ""))
        }
        let destinationID: String?
        if case .destination(let destination) = item.action { destinationID = destination.uri } else { destinationID = nil }
        item.id = item.contentId.map { "video:\($0)" } ?? destinationID ?? node.id?.value.nonPlaceholder ?? "\(fallbackID):\(item.title ?? ""):\(item.race?.sessionStartDate?.timeIntervalSince1970 ?? 0)"
        return item
    }
    static func sections(_ page: CatalogPayloadDTO, diagnostics: (CatalogDiagnostic) -> Void = { _ in }) -> [ContentSection] {
        var sections = [ContentSection]()
        if (page.containers?.dropped ?? 0) > 0 { diagnostics(CatalogDiagnostic(reason: .malformedSibling)) }
        for (index, node) in (page.containers?.values ?? []).enumerated() {
            let layout = ContainerLayoutType.fromIdentifier(identifier: node.layout ?? "")
            if node.actions?.values.contains(where: { $0.uri.contains("/CONTENT/WATCHING/") || $0.uri.contains("/USERSELECTIONS/") }) == true { continue }
            var section = ContentSection(); section.id = node.id?.value ?? "section:\(index):\(node.layout ?? "")"; section.layoutType = layout
            section.title = [.Hero, .GpBanner].contains(layout) ? "" : node.metadata?.label ?? ""
            section.artwork = node.metadata?.pictureUrl
            let raw = node.retrieveItems?.resultObj.containers
            if (raw?.dropped ?? 0) > 0 { diagnostics(CatalogDiagnostic(sectionIndex: index, reason: .malformedSibling)) }
            let items = (raw?.values ?? []).enumerated().compactMap { entry -> ContentItem? in
                let value = item(entry.element, fallbackID: "\(section.id):\(entry.offset)")
                guard value.objectType != .Video || value.contentId != nil else { diagnostics(CatalogDiagnostic(sectionIndex: index, itemIndex: entry.offset, reason: .unusableVideo)); return nil }
                if (entry.element.actions?.dropped ?? 0) > 0 { diagnostics(CatalogDiagnostic(sectionIndex: index, itemIndex: entry.offset, reason: .invalidAction)) }
                return value
            }
            section.total = node.retrieveItems?.resultObj.total
            if let action = node.actions?.values.first(where: { $0.key == "onTitleClick" && !$0.uri.isEmpty }), ![.Hero, .GpBanner, .PageHeader, .Schedule, .Title, .Subtitle, .ContentItem].contains(layout) {
                section.viewAllAction = CatalogDestination(uri: action.uri, href: action.href ?? "")
            }
            switch layout {
            case .Unknown: diagnostics(CatalogDiagnostic(sectionIndex: index, reason: .unsupportedLayout)); continue
            case .ContentItem:
                if sections.last?.layoutType != .ContentItem { sections.append(section) }
                sections[sections.count - 1].items.append(item(node, fallbackID: section.id)); continue
            case .Title, .Subtitle:
                guard !section.title.isEmpty else { continue }; section.content = .heading
            case .Schedule:
                let groups = (raw?.values ?? []).compactMap { group -> CatalogSchedule.Group? in
                    if (group.events?.dropped ?? 0) > 0 { diagnostics(CatalogDiagnostic(sectionIndex: index, reason: .malformedSibling)) }
                    let name = group.eventName ?? ""
                    let events = (group.events?.values ?? []).map { item($0, fallbackID: "session") }
                    guard !events.isEmpty else { return nil }
                    return CatalogSchedule.Group(name: name, label: group.eventShortName ?? name, events: events)
                }
                guard !groups.isEmpty else { continue }; section.content = .schedule(CatalogSchedule(groups: groups))
            default: guard !items.isEmpty else { continue }; section.items = items
            }
            sections.append(section)
        }
        return sections
    }
}

private extension String {
    var nonPlaceholder: String? { isEmpty || self == "0" ? nil : self }
}

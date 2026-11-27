import Foundation

public struct F1PersonalizedCatalog: Sendable {
    private let client: APIClient
    private let endpoints: APIEndpoints
    private let auth: any (AuthService & AuthorizedRequestSending)

    public init(client: APIClient, endpoints: APIEndpoints, auth: any (AuthService & AuthorizedRequestSending)) {
        self.client = client
        self.endpoints = endpoints
        self.auth = auth
    }

    private struct Context {
        var authorization: AuthorizationMode?
        var entitlement = "F1_TV_Pro_Annual"
        var groupID = 14
    }

    private func context() async -> Context {
        var context = Context()
        if (try? await auth.account()) != nil,
           let mode = try? await auth.catalogEntitlement(using: endpoints) {
            context.authorization = mode
            if let location = try? await auth.catalogLocation(using: endpoints, authorization: mode),
               Self.validPathSegment(location.entitlement) {
                context.entitlement = location.entitlement
                context.groupID = location.groupID
            }
        }
        return context
    }

    public func homeSections(featured: ContentItem?) async -> [ContentSection] {
        let context = await context()
        guard !Task.isCancelled else { return [] }
        var watching: [ContentItem] = []
        if context.authorization != nil {
            watching = await items(path: "CONTENT/WATCHING", context: context, limit: 20)
                .filter { $0.continuationPosition != nil }
        }
        guard !Task.isCancelled else { return [] }
        let seed = watching.first ?? featured
        var suggestions: [ContentItem] = []
        if let contentID = seed?.contentId {
            suggestions = await items(path: "UPNEXT", context: context, contentID: contentID, limit: 15)
                .filter { $0.contentId != contentID }
        }
        guard !Task.isCancelled else { return [] }
        return [
            HomeCatalogRows.row(id: HomeCatalogRows.continueWatching, title: "catalog_continue_watching".localizedString, items: watching),
            HomeCatalogRows.row(id: HomeCatalogRows.upNext, title: "catalog_up_next".localizedString, items: suggestions)
        ].compactMap { $0 }
    }

    public func upcomingStreams(for contentID: String) async -> [ContentItem] {
        let context = await context()
        return await items(path: "UPNEXT", context: context, contentID: contentID, limit: 15, scheduledLiveOnly: true)
    }

    private func items(path: String, context: Context, contentID: String? = nil, limit: Int,
                       scheduledLiveOnly: Bool = false) async -> [ContentItem] {
        guard !Task.isCancelled, var url = URLComponents(url: endpoints.catalogBase, resolvingAgainstBaseURL: false) else { return [] }
        url.path = "/2.0/R/\(endpoints.language)/\(CatalogRequest.provider)/ALL/\(path)/\(context.entitlement)/\(context.groupID)"
        if let contentID { url.queryItems = [URLQueryItem(name: "contentId", value: contentID)] }
        guard let address = url.url else { return [] }
        var request = URLRequest(url: address, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 6)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        do {
            let data: Data
            if let authorization = context.authorization { data = try await auth.authorizedData(request, mode: authorization) }
            else { data = try await client.data(request) }
            let envelope = try APIClient.decode(APIEnvelope<CatalogPayloadDTO>.self, from: data)
            var seen = Set<String>()
            let items = (envelope.resultObj?.containers?.values ?? []).compactMap { node -> ContentItem? in
                let item = CatalogMapper.item(node, fallbackID: path)
                let eligible = scheduledLiveOnly
                    ? item.objectType == .Video && item.contentId != nil && item.contentSubtype == "LIVE"
                        && item.coverageStartsAt != nil && item.locked != true && item.contentId != contentID
                    : item.canPlay
                guard eligible, seen.insert(item.id).inserted else { return nil }
                return item
            }
            return Array(items.prefix(limit))
        } catch {
            return []
        }
    }

    private static func validPathSegment(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 95 || $0 == 45 }
    }
}

public enum HomeCatalogRows {
    public static let continueWatching = "home:continue-watching"
    public static let upNext = "home:up-next"

    public static func isHome(_ uri: String) -> Bool {
        let path = URLComponents(string: uri)?.path.split(separator: "/") ?? []
        return path.count >= 7 && path[5] == "PAGE" && path[6] == "395"
    }

    public static func featured(in sections: [ContentSection]) -> ContentItem? {
        let videos = base(in: sections).flatMap(\.items).filter(\.canPlay)
        return videos.first { $0.contentSubtype != "LIVE" } ?? videos.first
    }

    public static func base(in sections: [ContentSection]) -> [ContentSection] {
        sections.filter { $0.id != continueWatching && $0.id != upNext }
    }

    public static func replacing(in sections: [ContentSection], with rows: [ContentSection]) -> [ContentSection] {
        var result = base(in: sections)
        let insertion = result.firstIndex { $0.layoutType == .Hero }.map { $0 + 1 } ?? 0
        result.insert(contentsOf: rows, at: insertion)
        return result
    }

    fileprivate static func row(id: String, title: String, items: [ContentItem]) -> ContentSection? {
        guard !items.isEmpty else { return nil }
        var section = ContentSection()
        section.id = id
        section.title = title
        section.layoutType = .HorizontalThumbnail
        section.items = items
        return section
    }
}

public extension Notification.Name {
    static let playbackHistoryDidChange = Notification.Name("VroomTV.playbackHistoryDidChange")
    static let catalogAccountDidChange = Notification.Name("VroomTV.catalogAccountDidChange")
}

import Foundation

protocol PlaybackService: Sendable {
    func video(_ id: String) async throws -> VideoDetails
    func entitlement(_ target: PlaybackTarget) async throws -> PlaybackEntitlement
    func report(contentID: String, subtype: String, position: Int, timestamp: Int) async throws
}
struct F1PlaybackService: PlaybackService {
    let endpoints: APIEndpoints
    let auth: any AuthorizedRequestSending
    func video(_ id: String) async throws -> VideoDetails {
        let data = try await auth.authorizedData(endpoints.video(id), mode: .video)
        let envelope = try APIClient.decode(APIEnvelope<CatalogPayloadDTO>.self, from: data)
        guard envelope.resultCode == "OK" else { throw APIError.backend }
        guard let node = envelope.resultObj?.containers?.values.first else { throw APIError.invalidResponse }
        let item = CatalogMapper.item(node, fallbackID: "video:\(id)")
        guard let contentID = item.contentId else { throw APIError.invalidPlayback }
        var channels = [PlaybackChannel(id: "main:\(contentID)", target: PlaybackTarget(uri: contentID, requiresVideoDetails: false), kind: .MainFeed, contentID: contentID, title: "INTERNATIONAL", artwork: item.pictureUrl, contentSubtype: item.contentSubtype, resumePosition: item.resumePosition)]
        var identities = Set(channels.map(\.id))
        for raw in node.metadata?.additionalStreams?.values ?? [] {
            guard let uri = raw.playbackUrl, !uri.isEmpty, raw.title != "INTERNATIONAL", identities.insert(uri).inserted else { continue }
            let kind: ChannelType
            switch raw.type { case "additional": kind = .AdditionalFeed; case "obc": kind = .OnBoardCamera; default: continue }
            channels.append(PlaybackChannel(id: uri, target: PlaybackTarget(uri: uri, requiresVideoDetails: false), kind: kind, contentID: contentID, title: raw.title ?? "", racingNumber: Int(raw.racingNumber?.value ?? "") ?? 0, driverFirstName: raw.driverFirstName, driverLastName: raw.driverLastName, teamName: raw.teamName ?? "", driverImg: raw.driverImg ?? "", teamImg: raw.teamImg ?? "", hex: raw.hex, contentSubtype: item.contentSubtype, resumePosition: item.resumePosition))
        }
        return VideoDetails(item: item, channels: channels)
    }
    func entitlement(_ target: PlaybackTarget) async throws -> PlaybackEntitlement {
        let request = try endpoints.entitlement(target.uri)
        let data = try await auth.authorizedData(request, mode: .entitlement)
        let envelope = try APIClient.decode(APIEnvelope<EntitlementDTO>.self, from: data)
        guard envelope.resultCode == "OK" else { throw APIError.backend }
        guard let dto = envelope.resultObj else { throw APIError.invalidPlayback }
        return try dto.model()
    }
    func report(contentID: String, subtype: String, position: Int, timestamp: Int) async throws {
        guard let id = Int(contentID), id > 0 else { throw APIError.invalidPlayback }
        let body = PlayTimeReportingDto(contentId: id, contentSubType: subtype, playHeadPosition: position, timestamp: timestamp)
        let request = try endpoints.report(body)
        let data = try await auth.authorizedData(request, mode: .reporting)
        let envelope = try APIClient.decode(APIEnvelope<CatalogPayloadDTO>.self, from: data)
        guard envelope.resultCode == "OK" else { throw APIError.backend }
    }
}

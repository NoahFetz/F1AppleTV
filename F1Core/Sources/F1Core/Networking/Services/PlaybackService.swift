import Foundation

public protocol PlaybackService: Sendable {
    func video(_ id: String) async throws -> VideoDetails
    func entitlement(_ target: PlaybackTarget) async throws -> PlaybackEntitlement
    func report(contentID: String, subtype: String, position: Int, timestamp: Int) async throws
}
public protocol PreviewFeedBundleLoading: Sendable {
    func previewFeedBundle(contentID: String) async throws -> PreviewFeedBundle
}

public enum PlaybackStart: Sendable {
    case session(VideoDetails)
    case direct(ContentItem, PlaybackChannel)

    public var details: VideoDetails {
        switch self {
        case .session(let details): details
        case .direct(let item, let channel): VideoDetails(item: item, channels: [channel])
        }
    }
}

public extension PlaybackService {
    func resolveStart(for item: ContentItem) async throws -> PlaybackStart {
        guard item.canPlay, let id = item.contentId, case .playback(let target) = item.action else {
            throw APIError.invalidPlayback
        }
        if target.requiresVideoDetails {
            let details = try await video(id)
            guard !details.isLive, let position = item.continuationPosition else { return .session(details) }
            var sessionItem = details.item
            sessionItem.resumePosition = position
            let channels = details.channels.map { channel in
                var channel = channel
                channel.resumePosition = position
                return channel
            }
            return .session(VideoDetails(item: sessionItem, channels: channels))
        }
        let channel = PlaybackChannel(id: "main:\(id)", target: target, kind: .MainFeed, contentID: id,
                                      title: item.title ?? "INTERNATIONAL", artwork: item.pictureUrl,
                                      contentSubtype: item.contentSubtype, resumePosition: item.resumePosition)
        return .direct(item, channel)
    }
}

public struct F1PlaybackService: PlaybackService, PreviewFeedBundleLoading {
    public init(endpoints: APIEndpoints, auth: any AuthorizedRequestSending) { self.endpoints = endpoints; self.auth = auth }

    public let endpoints: APIEndpoints
    public let auth: any AuthorizedRequestSending
    public func video(_ id: String) async throws -> VideoDetails {
        let legacyRequest = try endpoints.video(id)
        do {
            let authorization = try await auth.catalogEntitlement(using: endpoints)
            let location = try await auth.catalogLocation(using: endpoints, authorization: authorization)
            let request = try endpoints.videoV4(id, entitlement: location.entitlement, groupID: location.groupID,
                                               homeCountry: location.registeredCountryIsoCode)
            let details = try await auth.authorizedData(request, mode: authorization)
            return try decodeVideo(details, id: id)
        } catch {
            try Task.checkCancellation()
            guard !AppErrorStore.isCancellation(error), !(error is CancellationError) else { throw error }
            let data = try await auth.authorizedData(legacyRequest, mode: .video)
            return try decodeVideo(data, id: id)
        }
    }

    private func decodeVideo(_ data: Data, id: String) throws -> VideoDetails {
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
    public func entitlement(_ target: PlaybackTarget) async throws -> PlaybackEntitlement {
        let request = try endpoints.entitlement(target.uri)
        let data = try await playData(request)
        let envelope = try APIClient.decode(APIEnvelope<EntitlementDTO>.self, from: data)
        guard envelope.resultCode == "OK" else { throw APIError.backend }
        guard let dto = envelope.resultObj else { throw APIError.invalidPlayback }
        return try dto.model()
    }
    public func previewFeedBundle(contentID: String) async throws -> PreviewFeedBundle {
        let request = try endpoints.previewFeedBundle(contentID)
        let data = try await playData(request)
        let envelope = try APIClient.decode(APIEnvelope<PreviewFeedBundleDTO>.self, from: data)
        guard envelope.resultCode == "OK" else { throw APIError.backend }
        guard let dto = envelope.resultObj, let bundle = dto.model(for: contentID) else { throw APIError.invalidPlayback }
        return bundle
    }

    private func playData(_ request: URLRequest) async throws -> Data {
        do {
            return try await auth.authorizedData(request, mode: .entitlement)
        } catch let original as APIError {
            guard let status = original.httpStatus, [400, 401, 403, 404].contains(status) else { throw original }
            // Keep the account-session request verified for partner subscriptions as the first attempt.
            let authorization: AuthorizationMode
            do {
                authorization = try await auth.catalogEntitlement(using: endpoints)
            } catch {
                try Task.checkCancellation()
                guard !AppErrorStore.isCancellation(error), !(error is CancellationError) else { throw error }
                throw original
            }
            return try await auth.authorizedData(request, mode: authorization)
        }
    }

    public func report(contentID: String, subtype: String, position: Int, timestamp: Int) async throws {
        guard let id = Int(contentID), id > 0 else { throw APIError.invalidPlayback }
        let body = PlayTimeReportingDto(contentId: id, contentSubType: subtype, playHeadPosition: position, timestamp: timestamp)
        let request = try endpoints.report(body)
        let data = try await auth.authorizedData(request, mode: .reporting)
        let envelope = try APIClient.decode(APIEnvelope<CatalogPayloadDTO>.self, from: data)
        guard envelope.resultCode == "OK" else { throw APIError.backend }
    }
}

extension AuthorizedRequestSending {
    func catalogEntitlement(using endpoints: APIEndpoints) async throws -> AuthorizationMode {
        let subscription = try await subscriptionToken()
        let data = try await authorizedData(endpoints.userEntitlement(), mode: .entitlementLookup(subscription: subscription))
        let response = try APIClient.decode(APIEnvelope<UserEntitlement>.self, from: data)
        guard response.resultCode == "OK", let token = response.resultObj?.entitlementToken, !token.isEmpty else {
            throw APIError.invalidResponse
        }
        return .dedicatedEntitlement(token: token, subscription: subscription)
    }

    func catalogLocation(using endpoints: APIEndpoints, authorization: AuthorizationMode) async throws
        -> (entitlement: String, groupID: Int, registeredCountryIsoCode: String?) {
        let data = try await authorizedData(endpoints.userLocation(), mode: authorization)
        let response = try APIClient.decode(APIEnvelope<LocationResult>.self, from: data)
        guard response.resultCode == "OK", let location = response.resultObj?.userLocation.first,
              let groupID = Int(location.groupId.value), groupID > 0 else { throw APIError.invalidResponse }
        return (location.entitlement, groupID, location.registeredCountryIsoCode)
    }
}

private struct UserEntitlement: Decodable {
    let entitlementToken: String
}

private struct LocationResult: Decodable {
    struct Location: Decodable {
        let entitlement: String
        let groupId: WireIdentifier
        let registeredCountryIsoCode: String?
    }
    let userLocation: [Location]
}

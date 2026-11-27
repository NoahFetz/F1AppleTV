import Foundation

/// A picker can share one bundle request between the tiled player and its individual previews.
@MainActor
public final class PreviewFeedLoader {
    private let loadBundle: (String) async throws -> PreviewFeedBundle?
    private var requests: [String: Task<PreviewFeedBundle?, Never>] = [:]

    public init(loadBundle: @escaping (String) async throws -> PreviewFeedBundle?) {
        self.loadBundle = loadBundle
    }

    public func bundle(for contentID: String) async -> PreviewFeedBundle? {
        guard !Task.isCancelled else { return nil }
        if let request = requests[contentID] { return await request.value }
        let request = Task { [loadBundle] in try? await loadBundle(contentID) }
        requests[contentID] = request
        return await request.value
    }

    /// Return true when the preview is using a bundled stream.
    public func prepare(channel: PlaybackChannel?, allowBundle: Bool = true, cached: PlaybackEntitlement? = nil,
                        individual: () async throws -> PlaybackEntitlement,
                        using prepare: (PlaybackEntitlement, Duration) async throws -> Void) async throws -> Bool {
        if allowBundle, let channel, let entitlement = await bundle(for: channel.contentID)?.entitlement(for: channel) {
            try Task.checkCancellation()
            do {
                try await prepare(entitlement, .seconds(6))
                return true
            } catch {
                try Task.checkCancellation()
                if AppErrorStore.isCancellation(error) { throw error }
            }
        }
        if let cached {
            try Task.checkCancellation()
            do {
                try await prepare(cached, .seconds(6))
                return false
            } catch {
                try Task.checkCancellation()
                if AppErrorStore.isCancellation(error) { throw error }
            }
        }
        try Task.checkCancellation()
        let entitlement = try await individual()
        try Task.checkCancellation()
        try await prepare(entitlement, .seconds(20))
        return false
    }

    public func reset() {
        requests.values.forEach { $0.cancel() }
        requests.removeAll()
    }

    deinit { requests.values.forEach { $0.cancel() } }
}

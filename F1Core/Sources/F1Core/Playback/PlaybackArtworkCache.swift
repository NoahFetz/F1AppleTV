import Foundation

/// Coalesces public artwork requests across feeds, with bounded retained data.
public actor PlaybackArtworkCache {
    public static let shared = PlaybackArtworkCache()
    private let fetch: @Sendable (URL) async throws -> Data
    private let cache = NSCache<NSURL, NSData>()
    private var requests: [URL: Task<Data?, Never>] = [:]
    public init(fetch: @escaping @Sendable (URL) async throws -> Data = { url in
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }) {
        self.fetch = fetch; cache.totalCostLimit = 12 * 1_024 * 1_024; cache.countLimit = 16
    }
    public func data(for url: URL) async -> Data? {
        if let value = cache.object(forKey: url as NSURL) { return value as Data }
        if let request = requests[url] { return await request.value }
        let fetch = fetch
        let request = Task<Data?, Never> {
            guard let value = try? await fetch(url), !value.isEmpty, value.count <= 5 * 1_024 * 1_024 else { return nil }
            return value
        }
        requests[url] = request
        let value = await request.value
        requests[url] = nil
        if let value { cache.setObject(value as NSData, forKey: url as NSURL, cost: value.count) }
        return value
    }
}

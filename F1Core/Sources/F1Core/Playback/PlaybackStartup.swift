import Foundation

/// Bounds preparation and the first transition to playback; attempt IDs reject late callbacks.
public struct PlaybackStartup {
    public private(set) var attempt: UUID?
    private var deadline: Date?
    private var awaitingPlayback = false
    private let preparationTimeout: TimeInterval
    private let playbackTimeout: TimeInterval

    public init(preparationTimeout: TimeInterval = 45, playbackTimeout: TimeInterval = 20) {
        self.preparationTimeout = preparationTimeout; self.playbackTimeout = playbackTimeout
    }
    @discardableResult public mutating func begin(now: Date = Date()) -> UUID {
        let id = UUID(); attempt = id; awaitingPlayback = false
        deadline = now.addingTimeInterval(preparationTimeout); return id
    }
    public func accepts(_ id: UUID) -> Bool { attempt == id }
    public mutating func prepared(_ id: UUID, now: Date = Date()) {
        guard accepts(id) else { return }
        awaitingPlayback = true; deadline = now.addingTimeInterval(playbackTimeout)
    }
    /// A deliberately paused group must never be treated as a failed startup.
    public mutating func expired(now: Date = Date(), wantsPlayback: Bool, isPlaying: Bool) -> Bool {
        guard attempt != nil, let deadline else { return false }
        if awaitingPlayback {
            if isPlaying { self.deadline = nil; return false }
            if !wantsPlayback { self.deadline = now.addingTimeInterval(playbackTimeout); return false }
        }
        return now >= deadline
    }
    public mutating func cancel() { attempt = nil; deadline = nil; awaitingPlayback = false }
}

/// Reissue an expiring media URL once after a CDN rejection, not after a license
/// rejection or a user cancellation. The caller keeps the original startup deadline.
public struct PlaybackAccessRetry {
    public private(set) var used = false
    public init() {}
    public mutating func consume(_ error: Error) -> Bool {
        let value = error as NSError
        guard !used, !AppErrorStore.isCancellation(error),
              value.domain == NSURLErrorDomain, value.code == NSURLErrorNoPermissionsToReadFile,
              AppErrorStore.httpStatus(for: error) == 403 else { return false }
        used = true
        return true
    }
}

import Foundation

/// Owns progress delivery independently of the screen that submits it. A final
/// position replaces queued intermediate positions, but never cancels a request.
@MainActor
public final class PlaybackProgressReporter {
    public struct Progress: Equatable, Sendable {
        public let contentID: String
        public let subtype: String
        public let position: Int
        public let timestamp: Int
        public init(contentID: String, subtype: String, position: Int, timestamp: Int) {
            self.contentID = contentID; self.subtype = subtype
            self.position = position; self.timestamp = timestamp
        }
    }
    private let deliver: (Progress) async throws -> Void
    private let onError: (Error) -> Void
    private var pending: [Progress] = []
    private var task: Task<Void, Never>?

    public init(deliver: @escaping (Progress) async throws -> Void, onError: @escaping (Error) -> Void) {
        self.deliver = deliver; self.onError = onError
    }
    public func submit(_ progress: Progress) {
        guard progress.position >= 0 else { return }
        pending.removeAll { $0.contentID == progress.contentID }
        pending.append(progress)
        guard task == nil else { return }
        // Retain the reporter until the queue drains, even after the viewer exits.
        task = Task { [self] in
            while !pending.isEmpty {
                let next = pending.removeFirst()
                do { try await deliver(next) } catch { onError(error) }
            }
            task = nil
        }
    }
    public func flush() async { await task?.value }
}

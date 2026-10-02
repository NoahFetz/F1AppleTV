import Foundation

protocol FairPlayLoadingRequest: AnyObject, Sendable {
    var identity: ObjectIdentifier { get }
    var keyURL: URL? { get }
    var isCancelled: Bool { get }
    var isFinished: Bool { get }
    func spc(certificate: Data, assetID: String, completion: @escaping @Sendable (Result<Data, Error>) -> Void)
    func respond(_ data: Data)
    func finish(error: Error?)
}

/// Resolves once, including cancellation before the native completion callback arrives.
private final class SPCCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data, Error>?
    private var result: Result<Data, Error>?
    func install(_ continuation: CheckedContinuation<Data, Error>) -> Bool {
        lock.lock()
        if let result {
            lock.unlock()
            continuation.resume(with: result)
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }
    func resolve(_ result: Result<Data, Error>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}

/// Native requests stay on their delegate queue; the lock owns task cancellation and operation IDs.
final class FairPlayKeyLoader: @unchecked Sendable {
    private struct Pending { let task: Task<Void, Never>; let request: any FairPlayLoadingRequest; let generation: UUID }
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var pending = [ObjectIdentifier: Pending]()
    private let onError: @Sendable (Error) -> Void
    init(queue: DispatchQueue, onError: @escaping @Sendable (Error) -> Void = { _ in }) { self.queue = queue; self.onError = onError }
    private func current(_ id: ObjectIdentifier, generation: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }; return pending[id]?.generation == generation
    }
    private func take(_ id: ObjectIdentifier, generation: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard pending[id]?.generation == generation else { return false }
        pending.removeValue(forKey: id); return true
    }
    func load(_ request: any FairPlayLoadingRequest, entitlement: PlaybackEntitlement, service: any FairPlayService, reportsErrors: Bool) {
        let id = request.identity
        lock.lock()
        let generation = UUID()
        pending[id]?.task.cancel()
        let task = Task { [weak self] in
            var operation: AppErrorOperation = .certificate
            do {
                let certificate = try await service.certificate()
                try Task.checkCancellation()
                operation = .license
                let completion = SPCCompletion()
                let spc = try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { continuation in
                        guard completion.install(continuation) else { return }
                        guard let self else { completion.resolve(.failure(CancellationError())); return }
                        self.queue.async {
                            guard self.current(id, generation: generation), !request.isCancelled, !request.isFinished else { completion.resolve(.failure(CancellationError())); return }
                            guard let keyURL = request.keyURL, let assetID = FairPlayLicenseRequest.assetID(for: keyURL) else { completion.resolve(.failure(APIError.invalidPlayback)); return }
                            request.spc(certificate: certificate, assetID: assetID) { result in completion.resolve(result) }
                        }
                    }
                } onCancel: {
                    completion.resolve(.failure(CancellationError()))
                }
                try Task.checkCancellation()
                guard self?.current(id, generation: generation) == true else { throw CancellationError() }
                guard let keyURL = request.keyURL, let assetID = FairPlayLicenseRequest.assetID(for: keyURL), !spc.isEmpty else { throw APIError.invalidPlayback }
                let ckc = try await service.license(entitlement: entitlement, spc: spc, assetID: assetID)
                try Task.checkCancellation()
                guard !ckc.isEmpty else { throw APIError.invalidPlayback }
                self?.queue.async { [weak self] in
                    guard let self, self.take(id, generation: generation), !request.isCancelled, !request.isFinished else { return }
                    request.respond(ckc)
                    request.finish(error: nil)
                }
            } catch {
                let failedOperation = reportsErrors ? operation : .preview
                self?.queue.async { [weak self] in
                    guard let self, self.take(id, generation: generation), !request.isCancelled, !request.isFinished else { return }
                    recordServiceFailure(error, operation: failedOperation)
                    if reportsErrors, !AppErrorStore.isCancellation(error) { self.onError(error) }
                    request.finish(error: AppErrorStore.isCancellation(error) ? URLError(.cancelled) : error)
                }
            }
        }
        pending[id] = Pending(task: task, request: request, generation: generation); lock.unlock()
    }
    func cancel(_ request: any FairPlayLoadingRequest) { cancel(identity: request.identity) }
    func cancel(identity: ObjectIdentifier) {
        lock.lock(); let item = pending.removeValue(forKey: identity); lock.unlock(); item?.task.cancel()
    }
    func cancelAll() {
        lock.lock(); let values = Array(pending.values); pending.removeAll(); lock.unlock()
        values.forEach { value in
            value.task.cancel()
            queue.async { if !value.request.isCancelled && !value.request.isFinished { value.request.finish(error: URLError(.cancelled)) } }
        }
    }
    deinit { pending.values.forEach { $0.task.cancel() } }
}

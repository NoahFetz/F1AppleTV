import AVFoundation

/// Native key requests must retain their session until asynchronous SPC work completes.
private final class AVFoundationKeyRequest: FairPlayLoadingRequest, @unchecked Sendable {
    let request: AVContentKeyRequest
    private let session: AVContentKeySession
    private let active: () -> Bool
    private let failed: () -> Void
    let keyURL: URL?
    init(_ request: AVContentKeyRequest, session: AVContentKeySession, active: @escaping () -> Bool, failed: @escaping () -> Void) {
        self.request = request
        self.session = session
        self.active = active
        self.failed = failed
        keyURL = AVFoundationFairPlaySession.keyURL(for: request.identifier)
    }
    var identity: ObjectIdentifier { ObjectIdentifier(request) }
    var isCancelled: Bool { !active() }
    var isFinished: Bool { request.status == .receivedResponse || request.status == .failed }
    func spc(certificate: Data, assetID: String, completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        request.makeStreamingContentKeyRequestData(forApp: certificate, contentIdentifier: Data(assetID.utf8), options: nil) { [session] data, error in
            defer { withExtendedLifetime(session) {} }
            if let error { completion(.failure(error)) }
            else if let data, !data.isEmpty { completion(.success(data)) }
            else { completion(.failure(APIError.invalidPlayback)) }
        }
    }
    func respond(_ data: Data) {
        guard !isCancelled, !isFinished else { return }
        request.processContentKeyResponse(AVContentKeyResponse(fairPlayStreamingKeyResponseData: data))
    }
    func finish(error: Error?) {
        guard let error, !isCancelled, !isFinished else { return }
        failed()
        request.processContentKeyResponseError(error)
    }
}

/// One ephemeral session per player/preview. Native operations and delegate state share one queue.
final class AVFoundationFairPlaySession: NSObject, AVContentKeySessionDelegate, @unchecked Sendable {
    // The simulator rejects FairPlay session construction with an Objective-C exception.
    static var isSupported: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }
    let session: AVContentKeySession
    private let queue: DispatchQueue
    private let queueKey = DispatchSpecificKey<Bool>()
    private let entitlement: PlaybackEntitlement
    private let service: any FairPlayService
    private let reportsErrors: Bool
    private let onError: @Sendable (Error) -> Void
    private let loader: FairPlayKeyLoader
    private var active = true
    private var reportedFailures = Set<ObjectIdentifier>()

    init?(entitlement: PlaybackEntitlement, service: any FairPlayService, queue: DispatchQueue, reportsErrors: Bool, onError: @escaping @Sendable (Error) -> Void) {
        guard Self.isSupported else { return nil }
        self.entitlement = entitlement
        self.service = service
        self.queue = queue
        self.reportsErrors = reportsErrors
        self.onError = onError
        session = AVContentKeySession(keySystem: .fairPlayStreaming)
        loader = FairPlayKeyLoader(queue: queue, onError: onError)
        super.init()
        queue.setSpecific(key: queueKey, value: true)
        session.setDelegate(self, queue: queue)
    }

    static func keyURL(for identifier: Any?) -> URL? {
        if let url = identifier as? URL { return url }
        if let text = identifier as? String { return URL(string: text) }
        return nil
    }

    private func onQueue(_ operation: () -> Void) {
        if DispatchQueue.getSpecific(key: queueKey) == true { operation() }
        else { queue.sync(execute: operation) }
    }

    func register(_ asset: AVURLAsset) {
        // Registration must finish before the asset loads any properties or media.
        onQueue {
            guard active else { return }
            session.addContentKeyRecipient(asset)
        }
    }

    func invalidate() {
        onQueue {
            guard active else { return }
            active = false
            loader.cancelAll()
            session.setDelegate(nil, queue: nil)
            session.expire()
            reportedFailures.removeAll()
        }
    }

    deinit { invalidate() }

    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        guard active, session === self.session else { return }
        let id = ObjectIdentifier(keyRequest)
        let request = AVFoundationKeyRequest(keyRequest, session: session, active: { [weak self] in self?.active == true }, failed: { [weak self] in _ = self?.reportedFailures.insert(id) })
        loader.load(request, entitlement: entitlement, service: service, reportsErrors: reportsErrors)
    }

    func contentKeySession(_ session: AVContentKeySession, didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
        contentKeySession(session, didProvide: keyRequest)
    }

    func contentKeySession(_ session: AVContentKeySession, contentKeyRequest keyRequest: AVContentKeyRequest, didFailWithError error: Error) {
        guard active, session === self.session else { return }
        let id = ObjectIdentifier(keyRequest)
        loader.cancel(identity: id)
        // Loader-owned failures were already recorded before notifying AVFoundation.
        guard reportedFailures.remove(id) == nil else { return }
        recordServiceFailure(error, operation: reportsErrors ? .license : .preview)
        if reportsErrors, !AppErrorStore.isCancellation(error) { onError(error) }
    }
}

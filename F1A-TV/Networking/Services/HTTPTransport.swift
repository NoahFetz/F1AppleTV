import Foundation

enum APIError: Error, Equatable {
    case transport(Int), http(Int), backend, decoding, invalidResponse, authentication, invalidPlayback
    var httpStatus: Int? { if case .http(let status) = self { return status }; return nil }
    var diagnostic: NSError {
        let code: Int
        switch self {
        case .transport(let value): return NSError(domain: NSURLErrorDomain, code: value)
        case .http(let value): code = value
        case .backend: code = 1001
        case .decoding: code = 1002
        case .invalidResponse: code = 1003
        case .authentication: code = 1004
        case .invalidPlayback: code = 1005
        }
        return NSError(domain: "Application", code: code)
    }
}

protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> Data
}

struct APIClient: Sendable {
    let transport: any HTTPTransport
    var delay: @Sendable () async throws -> Void = { try await Task.sleep(nanoseconds: 500_000_000) }
    func data(_ request: URLRequest, retryTransient: Bool = false) async throws -> Data {
        try Task.checkCancellation()
        do { let data = try await transport.send(request); try Task.checkCancellation(); return data }
        catch {
            try Task.checkCancellation()
            guard retryTransient, request.httpMethod == "GET", Self.isTransient(error) else { throw error }
            try await delay()
            try Task.checkCancellation()
            let data = try await transport.send(request); try Task.checkCancellation(); return data
        }
    }
    static func isTransient(_ error: Error) -> Bool {
        switch error {
        case APIError.http(let status): return [502, 503, 504].contains(status)
        case APIError.transport(let code): return [NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost, NSURLErrorNotConnectedToInternet].contains(code)
        default: return false
        }
    }
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw APIError.decoding }
    }
    func envelope<T: Decodable>(_ type: T.Type, request: URLRequest, retryTransient: Bool = false) async throws -> T {
        let data = try await self.data(request, retryTransient: retryTransient)
        let response = try Self.decode(APIEnvelope<T>.self, from: data)
        guard response.resultCode == "OK" else { throw APIError.backend }
        guard let payload = response.resultObj else { throw APIError.invalidResponse }
        return payload
    }
}

struct APIEnvelope<Payload: Decodable>: Decodable {
    let resultCode: String
    let resultObj: Payload?
    private enum CodingKeys: String, CodingKey { case resultCode, resultObj }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        resultCode = try values.decode(String.self, forKey: .resultCode)
        resultObj = resultCode == "OK" ? try values.decodeIfPresent(Payload.self, forKey: .resultObj) : nil
    }
}

/// Every request declares its own headers. Catalog/media requests never inherit authentication headers.
struct APIEndpoints: Sendable {
    var catalogBase = URL(string: "https://f1tv.formula1.com")!
    var accountBase = URL(string: "https://api.formula1.com")!
    var language = "ENG"
    var playbackProvider = "BIG_SCREEN_HLS"
    var registrationAPIKey = "BPhVa4xbZoebPNdxRor9rouq6gzMoPyZ"
    var systemID = "60a9ad84-e93d-480f-80d6-af37494f2e22"
    var distributionChannel = "40500b92-005d-4e10-972f-b41850d6125b"
    static let deviceInfo = "device=tvos;screen=bigscreen;os=tvos;model=appletv14.1;osVersion=16.4;appVersion=2.11.0;playerVersion=3.16.0"
    func menu() -> URLRequest { URLRequest(url: URL(string: "/2.0/R/\(language)/WEB_HLS/ALL/MENU/PREMIUM/14", relativeTo: catalogBase)!) }
    func page(_ uri: String) throws -> URLRequest {
        guard let url = CatalogRequest.url(for: uri, baseURL: catalogBase) else { throw APIError.invalidResponse }
        return URLRequest(url: url)
    }
    func video(_ id: String) throws -> URLRequest {
        guard !id.isEmpty, id.allSatisfy(\.isNumber) else { throw APIError.invalidPlayback }
        return URLRequest(url: URL(string: "/3.0/R/\(language)/\(playbackProvider)/ALL/CONTENT/VIDEO/\(id)/F1_TV_Pro_Annual/14", relativeTo: catalogBase)!)
    }
    func entitlement(_ target: String) throws -> URLRequest {
        let uri = target.hasPrefix("CONTENT/") ? target : "CONTENT/PLAY?contentId=\(target)"
        guard uri.hasPrefix("CONTENT/PLAY?"), let url = URL(string: "/2.0/R/\(language)/\(playbackProvider)/ALL/\(uri)", relativeTo: catalogBase) else { throw APIError.invalidPlayback }
        var request = URLRequest(url: url); request.setValue(Self.deviceInfo, forHTTPHeaderField: "x-f1-device-info")
        return request
    }
    func certificate() -> URLRequest { URLRequest(url: catalogBase.appendingPathComponent("fairplay01.der")) }
    func register<T: Encodable>(_ body: T, challenge: String) throws -> URLRequest {
        try account("/v1/account/Subscriber/RegisterDevice", body: body, challenge: challenge)
    }
    func unregister<T: Encodable>(_ body: T, sessionID: String) throws -> URLRequest {
        try account("/v1/account/Subscriber/UnregisterDevice", body: body, sessionID: sessionID)
    }
    func refresh<T: Encodable>(_ body: T) throws -> URLRequest {
        try account("/v2/account/subscriber/authenticate/by-device", body: body)
    }
    private func account<T: Encodable>(_ path: String, body: T, challenge: String? = nil, sessionID: String? = nil) throws -> URLRequest {
        var request = URLRequest(url: URL(string: path, relativeTo: accountBase)!)
        request.httpMethod = "POST"; request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(registrationAPIKey, forHTTPHeaderField: "apikey")
        if let challenge { request.setValue(challenge, forHTTPHeaderField: "X-D-Token") }
        if path.contains("RegisterDevice") || path.contains("UnregisterDevice") { request.setValue(systemID, forHTTPHeaderField: "CD-SystemID") }
        if let sessionID { request.setValue(sessionID, forHTTPHeaderField: "CD-SessionID") }
        return request
    }
    func report<T: Encodable>(_ body: T) throws -> URLRequest {
        var request = URLRequest(url: URL(string: "/1.0/R/\(language)/\(playbackProvider)/ALL/ACTION/PLAY", relativeTo: catalogBase)!)
        request.httpMethod = "POST"; request.httpBody = try JSONEncoder().encode(body); request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}

struct ServiceFailure: Error {
    let operation: AppErrorOperation
    let underlying: Error
}

func recordServiceFailure(_ error: Error, operation: AppErrorOperation, store: AppErrorStoring = AppErrorStore.shared) {
    guard !(error is CancellationError), !AppErrorStore.isCancellation(error) else { return }
    let owned = error as? ServiceFailure
    let failure = owned?.underlying ?? error
    guard !AppErrorStore.isCancellation(failure) else { return }
    let api = failure as? APIError
    store.record(api?.diagnostic ?? failure, operation: owned?.operation ?? operation, httpStatus: api?.httpStatus)
}

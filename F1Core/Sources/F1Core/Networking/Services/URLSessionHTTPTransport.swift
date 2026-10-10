import Foundation

/// Native desktop transport; the API client's retry and authorization policy is shared.
public struct URLSessionHTTPTransport: HTTPTransport {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }
    public func send(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            guard (200..<300).contains(response.statusCode) else { throw APIError.http(response.statusCode) }
            return data
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw APIError.transport(error.errorCode)
        }
    }
}

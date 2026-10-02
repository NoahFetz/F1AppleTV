import Foundation
import Alamofire

/// Transport owns no account state and never presents or persists failures.
actor AlamofireHTTPTransport: HTTPTransport {
    private let session: Session
    init(session: Session? = nil) {
        let configuration = URLSessionConfiguration.af.default
        configuration.httpAdditionalHeaders = ["User-Agent": "F1TV-tvOS Darwin"]
        self.session = session ?? Session(configuration: configuration)
    }
    func send(_ request: URLRequest) async throws -> Data {
        try Task.checkCancellation()
        let response = await session.request(request).serializingData(automaticallyCancelling: true).response
        try Task.checkCancellation()
        if let status = response.response?.statusCode, !(200..<300).contains(status) { throw APIError.http(status) }
        switch response.result {
        case .success(let data): return data
        case .failure(let error):
            if error.isExplicitlyCancelledError { throw CancellationError() }
            let underlying = (error.underlyingError as NSError?) ?? (error as NSError)
            throw APIError.transport(underlying.code)
        }
    }
}


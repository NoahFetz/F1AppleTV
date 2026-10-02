import Foundation

/// Browsing uses the complete web catalog independently of the chosen playback CDN.
enum CatalogRequest {
    static let provider = "WEB_HLS"

    static func pageURI(pageID: String, language: String) -> String {
        "/2.0/R/\(language)/\(provider)/ALL/PAGE/\(pageID)/F1_TV_Pro_Annual/14"
    }

    static func url(for uri: String, baseURL: URL) -> URL? {
        guard let resolved = URL(string: uri, relativeTo: baseURL)?.absoluteURL,
              resolved.scheme == baseURL.scheme, resolved.host == baseURL.host,
              resolved.port == baseURL.port,
              var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false) else { return nil }
        var path = components.percentEncodedPath.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard path.count >= 6, ["R", "A"].contains(path[1]),
              path[4] == "ALL", ["PAGE", "CONTENT"].contains(path[5]) else { return nil }
        path[3] = provider
        components.percentEncodedPath = "/" + path.joined(separator: "/")
        // Do not rebuild the query: its encoding, filters and pagination belong to the API.
        return components.url
    }
}

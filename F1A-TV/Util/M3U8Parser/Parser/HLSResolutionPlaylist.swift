import Foundation

struct StreamResolution: Hashable {
    let width: Int
    let height: Int

    init?(attribute: String) {
        let dimensions = attribute.split(separator: "x")
        guard dimensions.count == 2, let width = Int(dimensions[0]), let height = Int(dimensions[1]),
              width > 0, height > 0 else { return nil }
        self.width = width
        self.height = height
    }

    func label(in options: [StreamResolution]) -> String {
        options.filter { $0.height == height }.count > 1 ? "\(width)x\(height)" : "\(height)p"
    }
}

struct ResolutionSwitchState {
    private(set) var selected: StreamResolution?
    private(set) var pending: UUID?

    mutating func begin() -> UUID {
        let request = UUID()
        pending = request
        return request
    }

    @discardableResult
    mutating func finish(_ request: UUID, resolution: StreamResolution?, succeeded: Bool) -> Bool {
        guard pending == request else { return false }
        pending = nil
        if succeeded { selected = resolution }
        return true
    }

    mutating func cancel() { pending = nil }
}

struct HLSResolutionPlaylist {
    enum PlaylistError: Error { case unavailable, malformed, unsupportedReference }

    private struct Variant {
        let tagIndex: Int
        let uriIndex: Int
        let resolution: StreamResolution?
    }

    let baseURL: URL
    let resolutions: [StreamResolution]
    private let lines: [String]
    private let variants: [Variant]

    init(text: String, baseURL: URL) throws {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        guard lines.first == "#EXTM3U" else { throw PlaylistError.malformed }
        var variants = [Variant]()
        for index in lines.indices where lines[index].hasPrefix(EXT_X_STREAM_INF.tag) {
            let uriIndex = index + 1
            guard lines.indices.contains(uriIndex), !lines[uriIndex].isEmpty,
                  !lines[uriIndex].hasPrefix("#") else { throw PlaylistError.malformed }
            let tag = try EXT_X_STREAM_INF(text: lines[index] + "\n" + lines[uriIndex], tagType: EXT_X_STREAM_INF.self, extraParams: nil)
            variants.append(Variant(tagIndex: index, uriIndex: uriIndex, resolution: StreamResolution(attribute: tag.resolution)))
        }
        let resolutions = Set(variants.compactMap { $0.resolution }).sorted {
            let left = Double($0.width) * Double($0.height)
            let right = Double($1.width) * Double($1.height)
            return left == right ? $0.height > $1.height : left > right
        }
        guard !resolutions.isEmpty else { throw PlaylistError.unavailable }
        self.baseURL = baseURL
        self.lines = lines
        self.variants = variants
        self.resolutions = resolutions
    }

    func startupResolution(maximumHeight: Int?) -> StreamResolution? {
        guard let maximumHeight else { return resolutions.first }
        return resolutions.first(where: { $0.height <= maximumHeight }) ?? resolutions.last
    }

    func filtered(resolution: StreamResolution?) throws -> Data {
        guard let target = resolution ?? resolutions.first, resolutions.contains(target) else {
            throw PlaylistError.unavailable
        }
        var removed = Set<Int>()
        for variant in variants where variant.resolution != target {
            removed.insert(variant.tagIndex)
            removed.insert(variant.uriIndex)
        }
        var output = [String]()
        for index in lines.indices where !removed.contains(index) {
            let line = lines[index]
            // Trick-play and image renditions are independent of normal playback resolution.
            // Steering must not reintroduce variants removed by the fixed-resolution filter.
            if line.hasPrefix("#EXT-X-CONTENT-STEERING:") { continue }
            if !line.isEmpty && !line.hasPrefix("#") {
                output.append(try absoluteReference(line))
            } else if let colon = line.firstIndex(of: ":") {
                let prefix = String(line[...colon])
                let attributes = HLSAttributeList.fields(in: String(line[line.index(after: colon)...]))
                let rewritten = try attributes.map { field -> String in
                    guard let equals = field.firstIndex(of: "="), field[..<equals].trimmingCharacters(in: .whitespaces) == "URI" else { return field }
                    let rawValue = field[field.index(after: equals)...].trimmingCharacters(in: .whitespaces)
                    let value = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    return "URI=\"\(try absoluteReference(value))\""
                }
                output.append(prefix + rewritten.joined(separator: ","))
            } else {
                output.append(line)
            }
        }
        return Data(output.joined(separator: "\n").utf8)
    }

    private func absoluteReference(_ reference: String) throws -> String {
        // Variable substitution would require resolving EXT-X-DEFINE first; fail safely instead.
        guard !reference.contains("{$"), let url = URL(string: reference, relativeTo: baseURL)?.absoluteURL,
              let scheme = url.scheme, ["http", "https", "skd", "data"].contains(scheme.lowercased()) else {
            throw PlaylistError.unsupportedReference
        }
        return url.absoluteString
    }
}

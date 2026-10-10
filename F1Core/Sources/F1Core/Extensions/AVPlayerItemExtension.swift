import AVFoundation

/// A track and its owning group, loaded before presenting the selection menu.
public struct MediaTrackDto {
    public init(option: AVMediaSelectionOption, group: AVMediaSelectionGroup) { self.option = option; self.group = group }

    public let option: AVMediaSelectionOption
    public let group: AVMediaSelectionGroup
    public var displayName: String { option.displayName }
}

extension AVPlayerItem {
    public enum TrackType {
        case subtitle, audio, video
        public var characteristic: AVMediaCharacteristic {
            switch self {
            case .subtitle: return .legible
            case .audio: return .audible
            case .video: return .visual
            }
        }
    }

    public func tracks(type: TrackType) async throws -> [MediaTrackDto] {
        try Task.checkCancellation()
        guard let group = try await asset.loadMediaSelectionGroup(for: type.characteristic) else { return [] }
        try Task.checkCancellation()
        return group.options.map { MediaTrackDto(option: $0, group: group) }
    }

    public func select(track: MediaTrackDto) {
        select(track.option, in: track.group)
    }
}

import AVFoundation

/// A track and its owning group, loaded before presenting the selection menu.
struct MediaTrackDto {
    let option: AVMediaSelectionOption
    let group: AVMediaSelectionGroup
    var displayName: String { option.displayName }
}

extension AVPlayerItem {
    enum TrackType {
        case subtitle, audio, video
        var characteristic: AVMediaCharacteristic {
            switch self {
            case .subtitle: return .legible
            case .audio: return .audible
            case .video: return .visual
            }
        }
    }

    func tracks(type: TrackType) async throws -> [MediaTrackDto] {
        try Task.checkCancellation()
        guard let group = try await asset.loadMediaSelectionGroup(for: type.characteristic) else { return [] }
        try Task.checkCancellation()
        return group.options.map { MediaTrackDto(option: $0, group: group) }
    }

    func select(track: MediaTrackDto) {
        select(track.option, in: track.group)
    }
}

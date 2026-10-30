import AVFoundation

extension PlaybackMetadata {
    public var externalMetadata: [AVMetadataItem] {
        var values: [(AVMetadataIdentifier, Any)] = [(.commonIdentifierTitle, title), (.iTunesMetadataTrackSubTitle, subtitle)]
        if let description { values.append((.commonIdentifierDescription, description)) }
        if let artworkData { values.append((.commonIdentifierArtwork, artworkData)) }
        return values.compactMap { identifier, value in
            guard let value = value as? (NSCopying & NSObjectProtocol) else { return nil }
            let item = AVMutableMetadataItem(); item.identifier = identifier; item.value = value; item.extendedLanguageTag = "und"
            return item.copy() as? AVMetadataItem
        }
    }
}

// =========================================================================================
// Copyright 2017 Gal Orlanczyk
//
// Permission is hereby granted, free of charge,
// to any person obtaining a copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction,
// including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
// =========================================================================================

import Foundation

/// `MediaPlaylist` object represent a media playlist (could be of all types video/audio/subtitles)
/// Holds tags and extra tags requested, the original text of the playlist and altered text in case the text was post processed.
public struct MediaPlaylist: Playlist {
    public let originalText: String
    public let alteredText: String?
    public let type: PlaylistType
    public let baseUrl: URL
    /// the media playlist tags
    public let tags: MediaPlaylistTags
    public let extraTags: [String: [Tag]]
}

/// `MediaPlaylistTags` contains media playlists tags
public struct MediaPlaylistTags {
    public let targetDurationTag: EXT_X_TARGETDURATION
    public let allowCacheTag: EXT_X_ALLOW_CACHE?
    public let playlistTypeTag: EXT_X_PLAYLIST_TYPE?
    public let versionTag: EXT_X_VERSION?
    public let mediaSequence: EXT_X_MEDIA_SEQUENCE?
    public let mediaSegments: [EXTINF]
    public let keySegments: [EXT_X_KEY]
}

/// `MediaPlaylistTagsBuilder` used to build `MediaPlaylistTags` object.
/// Aggregates the results when parsing and building at the end.
public class MediaPlaylistTagsBuilder {
    var targetDurationTag: EXT_X_TARGETDURATION? = nil
    var allowCacheTag: EXT_X_ALLOW_CACHE? = nil
    var playlistTypeTag: EXT_X_PLAYLIST_TYPE? = nil
    var versionTag: EXT_X_VERSION? = nil
    var mediaSequence: EXT_X_MEDIA_SEQUENCE? = nil
    var mediaSegments = [EXTINF]()
    var keySegments = [EXT_X_KEY]()
    
    func build() -> MediaPlaylistTags? {
        guard let targetDurationTag = self.targetDurationTag else { return nil }
        return MediaPlaylistTags(targetDurationTag: targetDurationTag,
                          allowCacheTag: self.allowCacheTag,
                          playlistTypeTag: self.playlistTypeTag,
                          versionTag: self.versionTag,
                          mediaSequence: self.mediaSequence,
                          mediaSegments: self.mediaSegments,
                          keySegments: self.keySegments)
    }
}

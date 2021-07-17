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

/// `Playlist` a general playlist protocol defined as a base for master and media playlist.
public protocol Playlist {
    /// The original text of the playlist
    var originalText: String { get }
    /// The altered text of the playist, only exists when post process handler was provided.
    var alteredText: String? { get }
    /// The type of the playlist
    var type: PlaylistType { get }
    /// The base url of the playlist
    var baseUrl: URL { get }
    /// dictionary of extra tags mapping to: [tag (EXT...): array of same type of tags]
    var extraTags: [String: [Tag]] { get }
}

/// Playlist type (master/video/audio/subtitles)
public enum PlaylistType: String {
    case master
    case video
    case audio
    case subtitles
    
    /// The default handled tags for each playlist type, this is used a default by the parser.
    var handledTagTypes: [Tag.Type] {
        switch self {
        case .master:
            return [
                EXT_X_MEDIA.self,
                EXT_X_STREAM_INF.self,
                EXT_X_VERSION.self
            ]
        case .video, .audio, .subtitles:
            return [
                EXT_X_TARGETDURATION.self,
                EXT_X_PLAYLIST_TYPE.self,
                EXT_X_VERSION.self,
                EXTINF.self,
                EXT_X_KEY.self,
                EXT_X_ALLOW_CACHE.self,
                EXT_X_MEDIA_SEQUENCE.self
            ]
        }
    }
}

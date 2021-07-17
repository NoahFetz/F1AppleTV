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

/// `MasterPlaylist` represents a master playlist object
public struct MasterPlaylist: Playlist {
    public let originalText: String
    public let alteredText: String?
    public let type: PlaylistType = .master
    public let baseUrl: URL
    public let tags: MasterPlaylistTags
    public let extraTags: [String: [Tag]]
}

/// `MasterPlaylistTags` objects represents tags used by the master playlist
public struct MasterPlaylistTags {
    public let versionTag: EXT_X_VERSION?
    public let mediaTags: [EXT_X_MEDIA]
    public let streamTags: [EXT_X_STREAM_INF]
}

/// `MasterPlaylistTagsBuilder` used to build `MasterPlaylistTags` object.
/// Aggregates the results when parsing and building at the end.
class MasterPlaylistTagsBuilder {
    var versionTag: EXT_X_VERSION? = nil
    var mediaTags = [EXT_X_MEDIA]()
    var streamTags = [EXT_X_STREAM_INF]()
    
    func build() -> MasterPlaylistTags? {
        return MasterPlaylistTags(versionTag: self.versionTag, mediaTags: self.mediaTags, streamTags: self.streamTags)
    }
}

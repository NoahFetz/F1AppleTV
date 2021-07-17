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

/// `M3U8Parser` handles parsing all type of playlists (master/video/audio/subtitles).
///
/// The parser can be used multiple times, **but make sure to reset the state**.
public class M3U8Parser {
    
    public init() {}
    
    /// `M3U8Parser` required params
    public struct Params {
        let playlist: String
        let playlistType: PlaylistType
        let baseUrl: URL
        
        public init(playlist: String, playlistType: PlaylistType, baseUrl: URL) {
            self.playlist = playlist
            self.playlistType = playlistType
            self.baseUrl = baseUrl
        }
    }
    
    /// `M3U8Parser` extra params
    public struct ExtraParams {
        /// Custom handled tags to be used when searching for a match in the playlist.
        /// Can be used to match less/more tags than the default handled.
        let customHandledTags: [Tag.Type]?
        let extraTags: [Tag.Type]?
        /// post processing on a line, receiving an array of lines and returning an array of lines, must be of equal size!
        /// use this in case you need to change attributes or data inside some of the tags.
        /// For example if you want to set a uri to a different url.
        let linePostProcessHandler: (([String]) -> [String])?
        
        public init(customRequiredTags: [Tag.Type]? = nil, extraTypes: [Tag.Type]? = nil, linePostProcessHandler: (([String]) -> [String])? = nil) {
            self.customHandledTags = customRequiredTags
            self.extraTags = extraTypes
            self.linePostProcessHandler = linePostProcessHandler
        }
    }
    
    /// This property is used to cancel the parser.
    /// - important: To be able to use this, the parser call must be performed async (parse function is synchronous),
    /// otherwise the change will have no effect.
    public var isCancelled = false
    
    
    /// Parse a playlist using the provided params.
    ///
    /// - Parameters:
    ///   - params: The required params for the parsing.
    ///   - extraParams: Extra params for additional handling.
    /// - Returns: Parser result, which can be master/media/cancelled.
    /// - Throws: malformedPlaylist when missing requred tags in the playlist,
    /// and tag errors when there was an issue with parsing a tag.
    public func parse(params: M3U8Parser.Params, extraParams: M3U8Parser.ExtraParams? = nil) throws -> ParserResult {
        // get all lines in the playlist
        var lines = params.playlist.components(separatedBy: .newlines)
        let linesCount = lines.count
        var extraTags = [String: [Tag]]()
        var lineIndex = 0
        
        // make sure the playlist starts with #EXTM3U tag
        guard lines[0].isMatch(tagType: EXTM3U.self) else { throw Error.malformedPlaylist }
        // we checked the first row, update line index
        lineIndex += 1
        
        let tagTypes: [Tag.Type] = extraParams?.customHandledTags ?? params.playlistType.handledTagTypes
        
        // remove duplications from extra types
        var extraTypes = extraParams?.extraTags ?? []
        for (index, tagType) in extraTypes.enumerated().reversed() {
            if tagTypes.contains(where: { $0 == tagType }) {
                extraTypes.remove(at: index)
            }
        }
        
        // master playlist tags builder
        var masterPlaylistTagsBuilder = MasterPlaylistTagsBuilder()
        // media playlist tags builder
        var mediaPlaylistTagsBuilder = MediaPlaylistTagsBuilder()
        
        while lineIndex < linesCount {
            // check if parsing cancelled
            guard !isCancelled else { return .cancelled }
            // used to keep track of the index before modifications where made
            var startingLineIndex = lineIndex
            var line = lines[lineIndex]
            // handle required tags
            try self.handleTags(tagTypes: tagTypes, on: &line, lines: &lines, lineIndex: &lineIndex, playlistType: params.playlistType,
                                masterPlaylistTagsBuilder: &masterPlaylistTagsBuilder, mediaPlaylistTagsBuilder: &mediaPlaylistTagsBuilder)
            // handle extra tags
            try self.handleExtraTags(tagTypes: extraTypes, on: &line, lineIndex: &lineIndex, lines: &lines, extraTags: &extraTags)
            
            let linesBeforePostProcessing = line.components(separatedBy: .newlines)
            if let updatedLines = extraParams?.linePostProcessHandler?(linesBeforePostProcessing),
                updatedLines.count == linesBeforePostProcessing.count {
                for line in updatedLines {
                    lines[startingLineIndex] = line
                    startingLineIndex += 1
                }
            }
            lineIndex += 1
        }
        
        var alteredText: String? = nil
        // if has post proccess handler make sure to save altered text
        if extraParams?.linePostProcessHandler != nil {
            alteredText = lines.joined(separator: "\n")
        }
        
        // create resilt according to playlist type
        switch params.playlistType {
        case .master:
            guard let masterPlaylistTags = masterPlaylistTagsBuilder.build() else {
                throw Error.malformedPlaylist
            }
            return .master(MasterPlaylist(originalText: params.playlist, alteredText: alteredText,
                                                    baseUrl: params.baseUrl, tags: masterPlaylistTags, extraTags: extraTags))
        case .video, .audio, .subtitles:
            guard let mediaPlaylistTags = mediaPlaylistTagsBuilder.build() else {
                throw Error.malformedPlaylist
            }
            let mediaPlaylist = MediaPlaylist(originalText: params.playlist, alteredText: alteredText, type: params.playlistType,
                                              baseUrl: params.baseUrl, tags: mediaPlaylistTags, extraTags: extraTags)
            return .media(mediaPlaylist)
        }
    }
    
    /// cancels the parsing by changing isCancelled property to true.
    public func cancel() {
        DispatchQueue.global().async {
            self.isCancelled = true
        }
    }
    
    /* ***********************************************************/
    // MARK: - Private Implementation
    /* ***********************************************************/
    
    private func handleTags(tagTypes: [Tag.Type], on line: inout String, lines: inout [String],
                            lineIndex: inout Int, playlistType: PlaylistType,
                            masterPlaylistTagsBuilder: inout MasterPlaylistTagsBuilder,
                            mediaPlaylistTagsBuilder: inout MediaPlaylistTagsBuilder) throws {
        
        for tagType in tagTypes {
            // find tag match
            if line.isMatch(tagType: tagType) {
                // handle multiline tags
                self.handleMultilineTag(tagType: tagType, on: &line, lineIndex: &lineIndex, lines: &lines)
                // handle matched tag for master/media playlists
                switch playlistType {
                case .master:
                    try self.handleMasterPlaylistTags(line: line,
                                                      tagType: tagType,
                                                      masterPlaylistTagsBuilder: &masterPlaylistTagsBuilder)
                case .video, .audio, .subtitles:
                    try self.handleMediaPlaylistTags(line: line, tagType: tagType,
                                                     mediaPlaylistTagsBuilder: &mediaPlaylistTagsBuilder)
                }
                // break after the first match
                break
            }
        }
    }
    
    private func handleExtraTags(tagTypes: [Tag.Type], on line: inout String, lineIndex: inout Int,
                                 lines: inout [String], extraTags: inout [String: [Tag]]) throws {
        
        for tagType in tagTypes {
            if line.isMatch(tagType: tagType) {
                // handle multiline tags
                self.handleMultilineTag(tagType: tagType, on: &line, lineIndex: &lineIndex, lines: &lines)
                // handle the extra tag and add it
                if var tags = extraTags[tagType.tag] {
                    tags.append(try tagType.init(text: line, tagType: tagType, extraParams: nil))
                    extraTags[tagType.tag] = tags
                } else {
                    extraTags[tagType.tag] = [try tagType.init(text: line, tagType: tagType, extraParams: nil)]
                }
            }
        }
    }
    
    private func handleMultilineTag(tagType: Tag.Type, on line: inout String, lineIndex: inout Int, lines: inout [String]) {
        if let multilineTagType = tagType as? MultilineTag.Type {
            // multiline tags must have a minimum of 2 lines, to check if more we need to send the 2 lines combined
            lineIndex += 1
            let extraLine = lines[lineIndex]
            line += "\n" + extraLine
            let linesCount = multilineTagType.linesCount(for: line)
            // add lines according to line count - 2 (-2 because first line is already inside the line and we added the second at the start).
            for _ in 0..<linesCount - 2 {
                lineIndex += 1
                let extraLine = lines[lineIndex]
                line += "\n" + extraLine
            }
        }
    }
    
    private func handleMasterPlaylistTags(line: String,
                                          tagType: Tag.Type,
                                          masterPlaylistTagsBuilder: inout MasterPlaylistTagsBuilder) throws {
        
        switch tagType {
        case is EXT_X_MEDIA.Type:
            let mediaTag = try tagType.init(text: line, tagType: EXT_X_MEDIA.self, extraParams: nil) as! EXT_X_MEDIA
            masterPlaylistTagsBuilder.mediaTags.append(mediaTag)
        case is EXT_X_STREAM_INF.Type:
            let streamTag = try tagType.init(text: line, tagType: EXT_X_STREAM_INF.self, extraParams: nil) as! EXT_X_STREAM_INF
            masterPlaylistTagsBuilder.streamTags.append(streamTag)
        case is EXT_X_VERSION.Type:
            let versionTag = try tagType.init(text: line, tagType: EXT_X_VERSION.self, extraParams: nil) as? EXT_X_VERSION
            masterPlaylistTagsBuilder.versionTag = versionTag
        default: break
        }
    }
    
    private func handleMediaPlaylistTags(line: String,
                                         tagType: Tag.Type,
                                         mediaPlaylistTagsBuilder: inout MediaPlaylistTagsBuilder) throws {
        
        switch tagType {
        case is EXT_X_TARGETDURATION.Type:
            let targetDurationTag = try tagType.init(text: line, tagType: EXT_X_TARGETDURATION.self, extraParams: nil) as? EXT_X_TARGETDURATION
            mediaPlaylistTagsBuilder.targetDurationTag = targetDurationTag
        case is EXT_X_ALLOW_CACHE.Type:
            let allowCacheTag = try tagType.init(text: line, tagType: EXT_X_ALLOW_CACHE.self, extraParams: nil) as? EXT_X_ALLOW_CACHE
            mediaPlaylistTagsBuilder.allowCacheTag = allowCacheTag
        case is EXT_X_PLAYLIST_TYPE.Type:
            let playlistTypeTag = try tagType.init(text: line, tagType: EXT_X_PLAYLIST_TYPE.self, extraParams: nil) as? EXT_X_PLAYLIST_TYPE
            mediaPlaylistTagsBuilder.playlistTypeTag = playlistTypeTag
        case is EXT_X_VERSION.Type:
            mediaPlaylistTagsBuilder.versionTag = try tagType.init(text: line, tagType: EXT_X_VERSION.self, extraParams: nil) as? EXT_X_VERSION
        case is EXT_X_MEDIA_SEQUENCE.Type:
            let mediaSequence = try tagType.init(text: line, tagType: EXT_X_MEDIA_SEQUENCE.self, extraParams: nil) as? EXT_X_MEDIA_SEQUENCE
            mediaPlaylistTagsBuilder.mediaSequence = mediaSequence
        case is EXTINF.Type:
            mediaPlaylistTagsBuilder.mediaSegments.append(try tagType.init(text: line, tagType: EXTINF.self, extraParams: nil) as! EXTINF)
        case is EXT_X_KEY.Type:
            mediaPlaylistTagsBuilder.keySegments.append(try tagType.init(text: line, tagType: EXT_X_KEY.self, extraParams: nil) as! EXT_X_KEY)
        default: break
        }
    }
}

/* ***********************************************************/
// MARK: - M3U8Parser Inner Types
/* ***********************************************************/

public extension M3U8Parser {
    
    enum Error: LocalizedError {
        case malformedPlaylist
        
        public var errorDescription: String? {
            switch self {
            case .malformedPlaylist:
                return "Malformed playlist, missing required elements"
            }
        }
    }
    
    enum ParserResult {
        case master(MasterPlaylist)
        case media(MediaPlaylist)
        case cancelled
        
        var playlist: Playlist? {
            switch self {
            case .master(let masterPlaylist): return masterPlaylist
            case .media(let mediaPlaylist): return mediaPlaylist
            case .cancelled: return nil
            }
        }
    }
}

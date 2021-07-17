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

/// Repesents `EXTM3U` tag.
public class EXTM3U: BaseTag {
    override public class var tag: String { return "#EXTM3U" }
}

/// Repesents `EXT-X-INDEPENDENT-SEGMENTS` tag.
public class EXT_X_INDEPENDENT_SEGMENTS: BaseTag {
    override public class var tag: String { return "#EXT-X-INDEPENDENT-SEGMENTS" }
}

/// Repesents `EXT-X-TARGETDURATION` tag.
public class EXT_X_TARGETDURATION: BaseValueTag<Int> {
    override public class var tag: String { return "#EXT-X-TARGETDURATION:" }
}

/// Repesents `EXT-X-VERSION` tag.
public class EXT_X_VERSION: BaseValueTag<Int> {
    override public class var tag: String { return "#EXT-X-VERSION:" }
}

/// Repesents `EXT-X-MEDIA-SEQUENCE` tag.
public class EXT_X_MEDIA_SEQUENCE: BaseValueTag<Int> {
    override public class var tag: String { return "#EXT-X-MEDIA-SEQUENCE:" }
}

/// Repesents a type with vod/event options.
public enum PlaylistTagType: String , StringInitializable {
    
    case vod = "VOD", event = "EVENT"
    
    public init?(_ string: String) {
        self.init(rawValue: string)
    }
}

/// Repesents `EXT-X-PLAYLIST-TYPE` tag.
public class EXT_X_PLAYLIST_TYPE: BaseValueTag<PlaylistTagType> {
    override public class var tag: String { return "#EXT-X-PLAYLIST-TYPE:" }
}

/// Repesents a type with yes/no options.
public enum BoolTagType: String, StringInitializable {
    case yes = "YES", no = "NO"
    
    public init?(_ string: String) {
        self.init(rawValue: string)
    }
}

/// Repesents `EXT-X-ALLOW-CACHE` tag.
public class EXT_X_ALLOW_CACHE: BaseValueTag<BoolTagType> {
    override public class var tag: String { return "#EXT-X-ALLOW-CACHE:" }
}

/// Repesents `EXT-X-BITRATE` tag.
public class EXT_X_BITRATE: BaseValueTag<Int> {
    override public class var tag: String { return "#EXT-X-BITRATE:" }
}

/// Repesents `EXTINF` tag.
public class EXTINF: BaseValueTag<Double>, MultilineTag {
    override public class var tag: String { return "#EXTINF:" }
    
    public let title: String?
    public let uri: String
    public let bitrate: EXT_X_BITRATE?
    
    public required init(text: String, tagType: Tag.Type, extraParams: [String: Any]?) throws {
        // extinf tag has multi lines
        let lines = text.components(separatedBy: .newlines)
        let linesCount = EXTINF.linesCount(for: text)
        guard lines.count == linesCount else { throw TagError.invalidData(tag: tagType.tag, received: "more/less than \(linesCount) lines of data", expected: "exactly \(linesCount) lines of data") }
        if linesCount == 3 {
            self.bitrate = try EXT_X_BITRATE(text: lines[1], tagType: EXT_X_BITRATE.self, extraParams: nil)
            self.uri = lines[2]
        } else {
            self.bitrate = nil
            self.uri = lines[1]
        }
        // remove comma and get optional title if exists
        var alteredText = lines[0]
        if let commaRange = lines[0].range(of: ",") {
            self.title = String(alteredText[commaRange.upperBound..<alteredText.endIndex])
            alteredText.removeSubrange(commaRange.lowerBound..<alteredText.endIndex)
        } else {
            self.title = nil
        }
        try super.init(text: alteredText, tagType: tagType, extraParams: extraParams)
    }
    
    public static func linesCount(for text: String) -> Int {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            // for some reason Apple has #EXT-X-BITRATE tag in their own sample but there are no docs for it.
            // we parse this tag and put it inside EXTINF when exists.
            if line.hasPrefix(EXT_X_BITRATE.tag) {
                return 3
            }
        }
        return 2
    }
}

/// Repesents `EXT-X-KEY` tag.
public class EXT_X_KEY: BaseAttributedTag {
    override public class var tag: String { return "#EXT-X-KEY:" }
    
    static let methodAttributeKey = "METHOD"
    static let uriAttributeKey = "URI"
    
    public var method: String {
        return self.attributes[EXT_X_KEY.methodAttributeKey] ?? ""
    }
    
    public var uri: String {
        return self.attributes[EXT_X_KEY.uriAttributeKey] ?? ""
    }
    
    public required init(text: String, tagType: Tag.Type, extraParams: [String: Any]?) throws {
        let attributesExtraParams: [String: Any] = [
            TagParamsKeys.attributesCount: 2,
            TagParamsKeys.attributesSeperator: ",",
            TagParamsKeys.attributesExtrasToRemove: ["\""],
            TagParamsKeys.attributesKeys: [EXT_X_KEY.methodAttributeKey, EXT_X_KEY.uriAttributeKey]
        ]
        try super.init(text: text, tagType: tagType, extraParams: attributesExtraParams)
    }
}

/// Repesents `EXT-X-STREAM-INF` tag.
public class EXT_X_STREAM_INF: BaseAttributedTag, MultilineTag {
    override public class var tag: String { return "#EXT-X-STREAM-INF:" }
    
    static let bandwidthAttributeKey = "BANDWIDTH"
    static let resolutionAttributeKey = "RESOLUTION"
    static let audioAttributeKey = "AUDIO"
    static let programIdAttributeKey = "PROGRAM-ID"
    
    public let uri: String
    
    public var bandwidth: Int {
        return Int(self.attributes[EXT_X_STREAM_INF.bandwidthAttributeKey] ?? " ") ?? -1
    }
    
    public var resolution: String {
        return self.attributes[EXT_X_STREAM_INF.resolutionAttributeKey] ?? ""
    }
    
    public var audio: String? {
        return self.attributes[EXT_X_STREAM_INF.audioAttributeKey]
    }
    
    public var programId: Int? {
        return Int(self.attributes[EXT_X_STREAM_INF.programIdAttributeKey] ?? " ")
    }
    
    public required init(text: String, tagType: Tag.Type, extraParams: [String: Any]?) throws {
        let attributesExtraParams: [String: Any] = [
            TagParamsKeys.attributesCount: 2,
            TagParamsKeys.attributesSeperator: ",",
            TagParamsKeys.attributesExtrasToRemove: ["\""],
            TagParamsKeys.attributesKeys: [
                EXT_X_STREAM_INF.bandwidthAttributeKey,
                EXT_X_STREAM_INF.resolutionAttributeKey
            ]
        ]
        let multiline = text.components(separatedBy: .newlines)
        guard multiline.count == 2 else { throw TagError.invalidData(tag: tagType.tag, received: "more/less than 2 lines of data", expected: "exactly 2 lines of data, 1 for tag and 1 for uri") }
        self.uri = multiline[1]
        try super.init(text: multiline[0], tagType: tagType, extraParams: attributesExtraParams)
    }
    
    public static func linesCount(for text: String) -> Int {
        return 2
    }
}

/// Repesents `EXT-X-MEDIA` tag.
public class EXT_X_MEDIA: BaseAttributedTag {
    override public class var tag: String { return "#EXT-X-MEDIA:" }
    /// Media type of `EXT-X-MEDIA` tag (audio/video/subtitles/cc/invalid)
    public enum MediaType: String {
        case audio = "AUDIO", video = "VIDEO", subtitles = "SUBTITLES", closedCaptions = "CLOSED-CAPTIONS", invalid
        
        var asPlaylistType: PlaylistType? {
            switch self {
            case .video: return .video
            case .audio: return .audio
            case .subtitles: return .subtitles
            case .closedCaptions: return nil
            case .invalid: return nil
            }
        }
    }
    
    static let typeAttributeKey = "TYPE"
    static let groupIdAttributeKey = "GROUP-ID"
    static let languageAttributeKey = "LANGUAGE"
    static let nameAttributeKey = "NAME"
    static let uriAttributeKey = "URI"
    
    public var mediaType: MediaType {
        return MediaType(rawValue: self.attributes[EXT_X_MEDIA.typeAttributeKey]!) ?? .invalid // should never reach invalid
    }
    
    public var groupId: String {
        return self.attributes[EXT_X_MEDIA.groupIdAttributeKey] ?? ""
    }
    
    public var language: String {
        return self.attributes[EXT_X_MEDIA.languageAttributeKey] ?? ""
    }
    
    public var name: String {
        return self.attributes[EXT_X_MEDIA.nameAttributeKey] ?? ""
    }
    
    public var uri: String {
        return self.attributes[EXT_X_MEDIA.uriAttributeKey] ?? ""
    }
    
    public required init(text: String, tagType: Tag.Type, extraParams: [String: Any]?) throws {
        let attributesExtraParams: [String: Any] = [
            TagParamsKeys.attributesCount: 2,
            TagParamsKeys.attributesSeperator: ",",
            TagParamsKeys.attributesExtrasToRemove: ["\""],
            TagParamsKeys.attributesKeys: [
                EXT_X_MEDIA.typeAttributeKey,
                EXT_X_MEDIA.groupIdAttributeKey
            ]
        ]
        try super.init(text: text, tagType: tagType, extraParams: attributesExtraParams)
    }
}

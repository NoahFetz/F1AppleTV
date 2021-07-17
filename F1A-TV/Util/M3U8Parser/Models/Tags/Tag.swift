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

/// `TagParamsKeys` holds the param keys for the tags extra params info.
/// This param keys are used to get information like the attributes seperator,
/// extras to remove required count and keys and more.
enum TagParamsKeys {
    /// the attributes seperator key.
    static let attributesSeperator = "attributeSeperator"
    /// the extras to remove from the text key.
    static let attributesExtrasToRemove = "attributesExtrasToRemove"
    /// The required attributes count key (can have more that are not required).
    static let attributesCount = "attributesCount"
    /// The required attributes keys key (can have more that are not required).
    /// Used also for validating the integrity of the tag when parsing.
    static let attributesKeys = "attributesKeys"
}

/* ***********************************************************/
// MARK: - PlaylistLine
/* ***********************************************************/

/// `PlaylistLine` protocol represents a general line in the playlist text
public protocol PlaylistLine {
    /// The text string of the line (the actual original data for each line)
    var text: String { get }
    
    init(text: String, tagType: Tag.Type, extraParams: [String: Any]?) throws
}

/* ***********************************************************/
// MARK: - Tag
/* ***********************************************************/

/// `Tag` protocol represents a tag line in the playlist
public protocol Tag: PlaylistLine {
    /// The tag itself, for example: '#EXTM3U'
    static var tag: String { get }
    /// The tag text data - all of the text after the tag.
    /// For example: '#EXTINF:4.458667,' tagDataText = '4.458667,'
    var tagDataText: String { get }
    /// The tag type, used to help subclass of base tags to identify the real type of the object.
    var tagType: Tag.Type { get }
    
    func toText(replacingTagValueWith newValue: String) -> String
}

extension Tag {
    
    public func toText(replacingTagValueWith newValue: String) -> String {
        return self.tagType.tag + tagDataText
    }
}

enum TagError: LocalizedError {
    case invalidData(tag: String, received: String, expected: String)
    case missingAttributes
    
    var errorDescription: String? {
        switch self {
        case .invalidData(let tag, let received, let expected):
            return "Failed to create tag (\(tag)) invalid data, \(received), \(expected).\nMake sure the playlist is valid."
        case .missingAttributes:
            return "Required attributes are missing, can not parse invalid playlist"
        }
    }
}

public protocol AttributedTag: Tag {
    var attributes: [String: String] { get }
}

public protocol MultilineTag {
    /// gets the line count for the text
    static func linesCount(for text: String) -> Int
}

extension AttributedTag {
    
    /// Gets the line attributes providing the tag, seperator and extras to remove before spliting.
    /// This action get the attributes by:
    /// - Removing extra strings provided
    /// - Spliting  the remaining string using the provided seperator
    /// - Fetching key value by substring to the first "=" to get the key and from it get the value.
    ///   For example: URI="http..." key is URI and value is "http...".
    ///
    /// - Parameters:
    ///   - tagDataText: The tag data text we need to extract the attributes from.
    ///   - seperator: The seperator between each attribute (usually ',').
    ///   - extrasToRemove: extra strings to remove from the line(" or ' etc) default is nil.
    /// - Returns: The attributes of playlist line. if no attributes found returns nil.
    static func getAttributes(from tagDataText: String, seperatedBy seperator: String, extrasToRemove: [String]? = nil) -> [String: String] {
        var attributes = [String: String]()
        // a mutable copy of the line tag text value so we can extract data from it.
        var mutableText = tagDataText
        // remove extras
        if let extrasToRemove = extrasToRemove {
            for extraToRemove in extrasToRemove {
                mutableText = mutableText.replacingOccurrences(of: extraToRemove, with: "")
            }
        }
        // get the raw attributes that are seperated by the seperator.
        let rawAttributes = mutableText.components(separatedBy: seperator)
        for rawAttribute in rawAttributes {
            guard let equationRange = rawAttribute.range(of: "=") else { continue }
            let attributeKey = String(rawAttribute[..<equationRange.lowerBound])
            let attributeValue = String(rawAttribute[equationRange.upperBound...])
            attributes[attributeKey] = attributeValue
        }
        
        return attributes
    }
    
    func validateIntegrity(requiredAttributes: [String]) throws {
        for requiredAttribute in requiredAttributes {
            if self.attributes[requiredAttribute] == nil {
                throw TagError.missingAttributes
            }
        }
    }
}

extension String {
    
    func isMatch(tagType: Tag.Type) -> Bool {
        return self.hasPrefix(tagType.tag)
    }
    
    func getTagValue(forType tagType: Tag.Type) -> String {
        guard let tagRange = self.range(of: tagType.tag) else { return "" }
        var tagValue = self
        tagValue.removeSubrange(tagRange)
        return tagValue
    }
}

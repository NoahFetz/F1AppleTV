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

/// `PlaylistOperation` operation handles fetching and parsing a single playlist object.
public class PlaylistOperation: Operation {
    
    /// `PlaylistOperation` required params
    public struct Params {
        public let fetcher: PlaylistFetcher
        public let url: URL
        public let playlistType: PlaylistType
        
        public init(fetcher: PlaylistFetcher? = nil, url: URL, playlistType: PlaylistType) {
            self.fetcher = fetcher ?? DefaultPlaylistFetcher()
            self.url = url
            self.playlistType = playlistType
        }
    }
    
    /// `PlaylistOperation` extra params
    public struct ExtraParams {
        public let parser: M3U8Parser.ExtraParams?
        
        public init(parser: M3U8Parser.ExtraParams? = nil) {
            self.parser = parser
        }
    }
    
    /// Required params
    let params: PlaylistOperation.Params
    /// Extra params
    let extraParams: PlaylistOperation.ExtraParams?
    /// Error object, will be available only if the operation will failed because of an error.
    var error: Error? = nil
    /// The results of operation
    var result: M3U8Parser.ParserResult? = nil
    
    public init(params: PlaylistOperation.Params, extraParams: PlaylistOperation.ExtraParams? = nil) {
        self.params = params
        self.extraParams = extraParams
    }
    
    public override func main() {
        
        if self.isCancelled { return }
        
        let playlistResult = self.params.fetcher.fetchPlaylist(from: self.params.url, timeoutInterval: 15)
        
        if self.isCancelled { return }
        
        switch playlistResult {
        case .success(let playlist):
            let parser = M3U8Parser()
            do {
                let baseUrl = self.params.url.deletingLastPathComponent()
                let parserParams = M3U8Parser.Params(playlist: playlist, playlistType: self.params.playlistType, baseUrl: baseUrl)
                let extraParams = M3U8Parser.ExtraParams(customRequiredTags: self.extraParams?.parser?.customHandledTags,
                                                         extraTypes: self.extraParams?.parser?.extraTags,
                                                         linePostProcessHandler: self.extraParams?.parser?.linePostProcessHandler)
                self.result = try parser.parse(params: parserParams, extraParams: extraParams)
            } catch {
                self.error = error
            }
        case .failure(let error): self.error = error
        }
    }
}

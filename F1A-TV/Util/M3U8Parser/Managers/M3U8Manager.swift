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

/// `Result` object for cases where we can get success of object or failure.
public enum M3U8Result<Value> {
    case success(Value)
    case failure(Swift.Error?)
}

/// `M3U8Manager` is an helper class for fetching and parsing playlists.
/// This class is used for convenience,
/// and its functionality can be mimiced by using the `M3U8Parser`, `PlaylistFetcher` and other required params.
public class M3U8Manager {
    
    public init() {}
    
    /// The operations queue all jobs of fetching + parsing will be performed on.
    private let operationsQueue = OperationQueue()
    
    /* ***********************************************************/
    // MARK: - Inner Types
    /* ***********************************************************/
    
    /// The result of a manager action.
    public enum M3U8Result<Value> {
        case success(Value)
        case failure(Swift.Error?)
        case cancelled
    }
    
    /// Holds the data needed to execute a playlist operation
    public struct PlaylistOperationData {
        public let params: PlaylistOperation.Params
        public let extraParams: PlaylistOperation.ExtraParams?
        
        public init(params: PlaylistOperation.Params, extraParams: PlaylistOperation.ExtraParams? = nil) {
            self.params = params
            self.extraParams = extraParams
        }
    }
    
    /// The manager allowed errors
    public enum Error: LocalizedError {
        case emptyResult
        case invalidType
        
        public var errorDescription: String? {
            switch self {
            case .emptyResult: return "Operation result returned empty"
            case .invalidType: return "Invalid type was provided for playlist result handling"
            }
        }
    }
    
    /* ***********************************************************/
    // MARK: - Public Implementation
    /* ***********************************************************/
    
    /// Fetches and parses a single playlist object.
    /// Returns a general playlist cast according to the type you requested.
    ///
    /// - Parameters:
    ///   - operationData: The data params neeeded to make the request.
    ///   - playlistType: The playlist type to to return in the result. used to save extra casting.
    ///   - operationHandler: Handler for making actions on the operation performing the fetch and parse.
    ///   can be used to cancel the request for example.
    ///   - completionHandler: The completion handler to be called when finished with the result of the operation.
    public func fetchAndParsePlaylist<T: Playlist>(from operationData: PlaylistOperationData, playlistType: T.Type,
                                                   operationHandler: ((PlaylistOperation) -> Void)? = nil,
                                                   completionHandler: @escaping (M3U8Manager.M3U8Result<T>) -> Void) {
        
        let playlistOperation = PlaylistOperation(params: operationData.params, extraParams: operationData.extraParams)
        playlistOperation.completionBlock = {
            if playlistOperation.isCancelled {
                completionHandler(.cancelled)
                return
            }
            if let error = playlistOperation.error {
                completionHandler(.failure(error))
                return
            }
            guard let result = playlistOperation.result, let playlist = result.playlist else {
                completionHandler(.failure(M3U8Manager.Error.emptyResult))
                return
            }
            guard let playlistResult = playlist as? T else {
                completionHandler(.failure(M3U8Manager.Error.invalidType))
                return
            }
            completionHandler(.success(playlistResult))
        }
        operationHandler?(playlistOperation)
        self.operationsQueue.addOperation(playlistOperation)
    }
    
    /// Helper method to fetch and parse multiple media playlists
    ///
    /// - Parameters:
    ///   - operationDataList: The data params neeeded to make all the requests.
    ///   - operationsHandler: Handler for making actions on the operations performing the fetch and parse.
    ///   can be used to cancel a single/multiple request/s for example.
    ///   - completionHandler: The completion handler to be called when finished with the result of the operations.
    public func fetchAndParseMediaPlaylists(from operationDataList: [PlaylistOperationData],
                                            operationsHandler: (([PlaylistOperation]) -> Void)? = nil,
                                            completionHandler: @escaping (M3U8Manager.M3U8Result<[MediaPlaylist]>) -> Void) {
        
        let synchronizedQueue = DispatchQueue(label: "com.goswifty.goswiftym3u8.manager.temp-queue")
        let dispatchGroup = DispatchGroup()
        var operations = [PlaylistOperation]()
        var resultMediaPlaylists = [MediaPlaylist]()
        var error: Swift.Error? = nil
        var isCancelled = false
        
        for operationData in operationDataList {
            self.fetchAndParsePlaylist(from: operationData, playlistType: MediaPlaylist.self, operationHandler: { (operation) in
                operations.append(operation)
            }, completionHandler: { (result) in
                defer {
                    dispatchGroup.leave()
                }
                switch result {
                case .success(let mediaPlaylist):
                    synchronizedQueue.sync {
                        resultMediaPlaylists.append(mediaPlaylist)
                    }
                case .failure(let e):
                    error = e
                    if self.operationsQueue.operationCount > 0 {
                        operations.forEach {
                            if !$0.isFinished {
                                $0.cancel()
                            }
                        }
                    }
                case .cancelled: isCancelled = true
                }
            })
            dispatchGroup.enter()
        }
        operationsHandler?(operations)
        dispatchGroup.notify(queue: DispatchQueue.main) {
            if let e = error {
                completionHandler(.failure(e))
            } else if isCancelled {
                completionHandler(.cancelled)
            } else {
                completionHandler(.success(resultMediaPlaylists))
            }
        }
    }
    
    /// Cancels all the running operations on the manager.
    public func cancel() {
        if self.operationsQueue.operationCount > 0 {
            self.operationsQueue.cancelAllOperations()
        }
    }
    
    /* ***********************************************************/
    // MARK: - Internal Implementation
    /* ***********************************************************/
    
    static func createUrl(from uri: String, using originalUrl: URL) -> URL? {
        let url: URL
        if uri.hasPrefix("http") {
            guard let httpUrl = URL(string: uri) else { return nil }
            url = httpUrl
        } else {
            url = originalUrl.deletingLastPathComponent().appendingPathComponent(uri, isDirectory: false)
        }
        return url
    }
}

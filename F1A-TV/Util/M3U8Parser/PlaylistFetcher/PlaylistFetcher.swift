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

enum PlaylistFetcherError: LocalizedError {
    case error(Error)
    case statusCode(Int)
    case noData
    case invalidData
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .error(let error):
            return "received an error with description: \(error.localizedDescription)"
        case .statusCode(let statusCode):
            return "request failed with status code of: \(statusCode)"
        case .noData:
            return "request succeeded, but received empty data"
        case .invalidData:
            return "request received data is different from expected type"
        case .timeout:
            return "request was timed out"
        }
    }
}

public protocol PlaylistFetcher: AnyObject {
    /// fetches a playlist synchronously
    func fetchPlaylist(from url: URL, timeoutInterval: TimeInterval) -> M3U8Result<String>
    /// fetches a playlist asynchronously
    func fetchPlaylist(from url: URL, timeoutInterval: TimeInterval, completionHandler: @escaping (M3U8Result<String>) -> Void)
}

public class DefaultPlaylistFetcher: PlaylistFetcher {
    
    public func fetchPlaylist(from url: URL, timeoutInterval: TimeInterval = 60) -> M3U8Result<String> {
        let taskSemaphore = DispatchSemaphore(value: 0)
        var taskPlaylist: String? = nil
        var taskError: Error? = nil
        let urlRequest = URLRequest(url: url, timeoutInterval: timeoutInterval)
        let task = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
            // make sure no error
            guard (error == nil) else {
                print("There was an error with your request: \(String(describing: error))")
                taskError = PlaylistFetcherError.error(error!)
                taskSemaphore.signal()
                return
            }
            // make sure we got a successfull 2xx code response
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                print("Your request returned a status code other than 2xx!")
                taskError = PlaylistFetcherError.statusCode((response as? HTTPURLResponse)?.statusCode ?? -1)
                taskSemaphore.signal()
                return
            }
            
            guard let data = data else {
                print("No data was returned by the request!")
                taskError = PlaylistFetcherError.noData
                taskSemaphore.signal()
                return
            }
            
            taskPlaylist = String(data: data, encoding: .utf8)
            taskSemaphore.signal()
        }
        task.resume()
        // wait until network request will finish
        switch taskSemaphore.wait(timeout: .now() + timeoutInterval) {
        case .success:
            if let playlist = taskPlaylist {
                return .success(playlist)
            } else if let error = taskError {
                return .failure(error)
            } else {
                return .failure(PlaylistFetcherError.invalidData)
            }
        case .timedOut:
            return .failure(PlaylistFetcherError.timeout)
        }
    }
    
    public func fetchPlaylist(from url: URL, timeoutInterval: TimeInterval, completionHandler: @escaping (M3U8Result<String>) -> Void) {
        let urlRequest = URLRequest(url: url, timeoutInterval: timeoutInterval)
        let task = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
            // make sure no error
            guard (error == nil) else {
                print("There was an error with your request: \(String(describing: error))")
                completionHandler(.failure(error))
                return
            }
            // make sure we got a successfull 2xx code response
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                print("Your request returned a status code other than 2xx!")
                completionHandler(.failure(PlaylistFetcherError.statusCode((response as? HTTPURLResponse)?.statusCode ?? -1)))
                return
            }
            
            guard let data = data else {
                print("No data was returned by the request!")
                completionHandler(.failure(PlaylistFetcherError.noData))
                return
            }
            
            guard let taskPlaylist = String(data: data, encoding: .utf8) else {
                print("Invalid data, failed to convert data to String with utf8 encoding")
                completionHandler(.failure(PlaylistFetcherError.invalidData))
                return
            }
            completionHandler(.success(taskPlaylist))
        }
        task.resume()
    }
}

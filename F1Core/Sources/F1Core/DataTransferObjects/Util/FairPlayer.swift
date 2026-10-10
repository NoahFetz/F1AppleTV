//
//  FairPlayer.swift
//  F1A-TV
//
//  Created by Noah Fetz on 09.04.22.
//

import Foundation
import AVKit

public class FairPlayer: AVPlayer {
    public static let resolutionDidChange = Notification.Name("FairPlayerResolutionDidChange")
    public enum ResolutionStatus { case loading, available, switching, unavailable }

    public var streamEntitlement: PlaybackEntitlement?
    public var fairPlayAsset: AVURLAsset?
    public var reportsPlaybackErrors = true
    public var onPlaybackError: ((Error) -> Void)?
    public private(set) var availableResolutions = [StreamResolution]()
    public private(set) var resolutionStatus: ResolutionStatus = .loading
    public private(set) var resolutionError: String?
    public private(set) var previewManifest: String?
    public private(set) var previewBaseURL: URL?
    private var selection = ResolutionSwitchState()
    private var playlist: HLSResolutionPlaylist?
    private var failureObservation: NSKeyValueObservation?
    private var playlistTask: URLSessionDataTask?
    private var preparationID = UUID()
    private var switchObservation: NSKeyValueObservation?
    private var switchTimeout: DispatchWorkItem?
    private var rollbackItem: AVPlayerItem?
    private var rollbackSnapshot: PlaybackSnapshot?
    private var pendingResolution: StreamResolution?
    private var pendingDynamicRange: StreamDynamicRange?
    public private(set) var selectedDynamicRange = StreamDynamicRange.automatic
    public var requestedDynamicRange: StreamDynamicRange { pendingDynamicRange ?? selectedDynamicRange }
    public var availableVideoRanges: [String] { playlist?.videoRanges ?? [] }
    /// Only HTTP status and error codes are retained from AVFoundation's log.
    /// Native -1102/-12660 can wrap a CDN 403 rather than a local-file failure.
    public static func playbackFailure(for item: AVPlayerItem) async -> NSError {
        let error = (item.error ?? URLError(.cannotDecodeContentData)) as NSError
        var status: Int?
        // The failed-item KVO callback can precede its native error-log event.
        for attempt in 0..<4 {
            let log: AVPlayerItemErrorLog?
            if #available(macOS 27, tvOS 27, *) { log = await item.errorLog }
            else { log = item.errorLog() }
            for event in log?.events.reversed() ?? [] {
                if (100...599).contains(event.errorStatusCode) { status = event.errorStatusCode; break }
                guard let comment = event.errorComment,
                      let range = comment.range(of: "HTTP [1-5][0-9]{2}", options: .regularExpression),
                      let value = Int(comment[range].suffix(3)) else { continue }
                status = value; break
            }
            if status != nil || Task.isCancelled { break }
            if attempt < 3 { try? await Task.sleep(nanoseconds: 50_000_000) }
        }
        guard let status else { return error }
        var info = error.userInfo
        info[AppErrorStore.httpStatusKey] = status
        return NSError(domain: error.domain, code: error.code, userInfo: info)
    }
    public var effectiveDynamicRange: StreamDynamicRange { playlist?.effectiveDynamicRange(selectedDynamicRange) ?? .automatic }
    private var resolutionPreparationTask: Task<Void, Never>?
    private var mediaRestorationTask: Task<Void, Never>?
    private var mediaRestorationID = UUID()
    private var playlistData = [URL: Data]()
    private let playlistLock = NSLock()

    public override func replaceCurrentItem(with item: AVPlayerItem?) {
        failureObservation = nil
        super.replaceCurrentItem(with: item)
        guard let item else { return }
        failureObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor in
                guard let self, self.currentItem === item else { return }
                let error = await Self.playbackFailure(for: item)
                guard self.currentItem === item else { return }
                AppErrorStore.shared.record(error, operation: self.reportsPlaybackErrors ? .playback : .preview)
                if self.reportsPlaybackErrors && self.resolutionStatus != .switching {
                    self.onPlaybackError?(error)
                }
            }
        }
    }

    public var selectedResolution: StreamResolution? { selection.selected }
    
    public let vroomQueue = DispatchQueue(label: "VroomFairPlayer")
    public var fairPlayService: (any FairPlayService)?
    private var contentKeySession: AVFoundationFairPlaySession?

    private func configureKeyHandling(for asset: AVURLAsset) {
        asset.resourceLoader.setDelegate(self, queue: vroomQueue)
        guard let entitlement = streamEntitlement,
              entitlement.drmType?.lowercased().contains("fairplay") == true || entitlement.licenseURL != nil,
              let service = fairPlayService else { return }
        if contentKeySession == nil {
            let epoch = preparationID
            contentKeySession = AVFoundationFairPlaySession(entitlement: entitlement, service: service, queue: vroomQueue, reportsErrors: reportsPlaybackErrors) { [weak self] error in
                DispatchQueue.main.async {
                    guard let self, self.preparationID == epoch else { return }
                    self.onPlaybackError?(error)
                }
            }
        }
        contentKeySession?.register(asset)
    }

    public func playStream(streamEntitlement: PlaybackEntitlement) {
        stopStream()
        self.streamEntitlement = streamEntitlement
        resolutionStatus = .loading
        resolutionError = nil
        selection = ResolutionSwitchState()
        selectedDynamicRange = .automatic
        availableResolutions = []
        playlist = nil
        previewManifest = nil
        previewBaseURL = nil
    }
    
    public func makeFairPlayReady() -> AVURLAsset? {
        if let urlString = self.streamEntitlement?.url, let url = URL(string: urlString) {
            self.fairPlayAsset = AVURLAsset(url: url)
            if let asset = fairPlayAsset { configureKeyHandling(for: asset) }
        }
        
        return self.fairPlayAsset
    }

    public func prepareStream(startupMaximumHeight: Int? = nil, previewMaximumHeight: Int? = nil, cachedManifest: String? = nil, cachedBaseURL: URL? = nil, dynamicRange: StreamDynamicRange = .automatic, completion: @escaping (AVPlayerItem) -> Void) {
        guard let urlString = streamEntitlement?.url, let url = URL(string: urlString) else {
            AppErrorStore.shared.record(URLError(.badURL), operation: reportsPlaybackErrors ? .preparation : .preview)
            if reportsPlaybackErrors { onPlaybackError?(URLError(.badURL)) }
            return
        }
        playlistTask?.cancel(); playlistTask = nil
        let requestID = UUID()
        preparationID = requestID
        if let cachedManifest, let cachedBaseURL,
           let discovered = try? HLSResolutionPlaylist(text: cachedManifest, baseURL: cachedBaseURL) {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.preparationID == requestID else { return }
                self.installPreparedStream(discovered: discovered, text: cachedManifest, baseURL: cachedBaseURL,
                                           startupMaximumHeight: startupMaximumHeight, previewMaximumHeight: previewMaximumHeight, dynamicRange: dynamicRange, completion: completion)
            }
            return
        }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        playlistTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let discovered: HLSResolutionPlaylist?
            var masterText: String?
            var masterURL: URL?
            if error == nil, let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
               let finalURL = response.url, let data = data, let text = String(data: data, encoding: .utf8) {
                discovered = try? HLSResolutionPlaylist(text: text, baseURL: finalURL)
                masterText = text
                masterURL = finalURL
            } else {
                discovered = nil
            }
            DispatchQueue.main.async {
                guard let self = self, self.preparationID == requestID else { return }
                self.playlistTask = nil
                if let error { AppErrorStore.shared.record(error, operation: self.reportsPlaybackErrors ? .preparation : .preview) }
                else if let response = response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
                    AppErrorStore.shared.record(URLError(.badServerResponse), operation: self.reportsPlaybackErrors ? .preparation : .preview, httpStatus: response.statusCode)
                }
                self.installPreparedStream(discovered: discovered, text: masterText, baseURL: masterURL,
                                           startupMaximumHeight: startupMaximumHeight, previewMaximumHeight: previewMaximumHeight, dynamicRange: dynamicRange, completion: completion)
            }
        }
        playlistTask?.resume()
    }

    private func installPreparedStream(discovered: HLSResolutionPlaylist?, text: String?, baseURL: URL?, startupMaximumHeight: Int?, previewMaximumHeight: Int?, dynamicRange: StreamDynamicRange, completion: @escaping (AVPlayerItem) -> Void) {
        previewManifest = text
        previewBaseURL = baseURL
        playlist = discovered
        selectedDynamicRange = dynamicRange
        availableResolutions = discovered?.resolutions(for: dynamicRange) ?? []
        let asset: AVURLAsset?
        let previewResolution = (previewMaximumHeight ?? startupMaximumHeight).flatMap { height in
            discovered?.startupResolution(maximumHeight: height, dynamicRange: dynamicRange)
        }
        if let data = try? discovered?.filtered(resolution: previewResolution, dynamicRange: dynamicRange) {
            asset = makeResolutionAsset(data: data)
            resolutionStatus = .available
            if let previewResolution = previewResolution {
                let request = selection.begin()
                selection.finish(request, resolution: previewResolution, succeeded: true)
            }
        } else {
            playlist = nil
            availableResolutions = []
            asset = makeFairPlayReady()
            resolutionStatus = .unavailable
        }
        guard let asset = asset else { return }
        let item = AVPlayerItem(asset: asset)
        if let height = previewMaximumHeight {
            item.preferredMaximumResolution = CGSize(width: height * 16 / 9, height: height)
            item.preferredPeakBitRate = height <= 360 ? 900_000 : 1_600_000
        }
        fairPlayAsset = asset
        replaceCurrentItem(with: item)
        completion(item)
        notifyResolutionChanged()
    }

    public func makeThumbnailAsset(url previewURL: URL? = nil) -> AVURLAsset? {
        guard let url = previewURL ?? streamEntitlement.flatMap({ URL(string: $0.url) }),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        let asset = AVURLAsset(url: url)
        configureKeyHandling(for: asset)
        return asset
    }

    public func selectResolution(_ resolution: StreamResolution?) {
        selectStream(resolution: resolution, dynamicRange: requestedDynamicRange)
    }

    public func selectDynamicRange(_ dynamicRange: StreamDynamicRange) {
        guard let playlist else { return }
        let resolution = selectedResolution.flatMap { old in
            let options = playlist.resolutions(for: dynamicRange)
            return options.contains(old) ? old : playlist.startupResolution(maximumHeight: old.height, dynamicRange: dynamicRange)
        }
        selectStream(resolution: resolution, dynamicRange: dynamicRange)
    }

    private func selectStream(resolution: StreamResolution?, dynamicRange: StreamDynamicRange) {
        guard let playlist,
              let data = try? playlist.filtered(resolution: resolution, dynamicRange: dynamicRange), let current = currentItem else { return }
        if selection.pending == nil && selection.selected == resolution && selectedDynamicRange == dynamicRange { return }
        if selection.pending != nil && pendingResolution == resolution && pendingDynamicRange == dynamicRange { return }

        // A newer choice supersedes the in-flight switch; rollback uses the last committed item.
        let original = rollbackItem ?? current
        let initialSnapshot = rollbackSnapshot ?? PlaybackSnapshot(player: self, item: original)
        resolutionPreparationTask?.cancel()
        mediaRestorationTask?.cancel()
        mediaRestorationID = UUID()
        switchObservation = nil
        switchTimeout?.cancel()
        current.cancelPendingSeeks()
        let request = selection.begin()
        pendingResolution = resolution
        pendingDynamicRange = dynamicRange
        rollbackItem = original
        rollbackSnapshot = initialSnapshot
        resolutionStatus = .switching
        resolutionError = nil
        pause()
        notifyResolutionChanged()

        resolutionPreparationTask = Task { @MainActor [weak self] in
            let snapshot = await initialSnapshot.loadingMediaChoices(from: original)
            guard let self, !Task.isCancelled, self.selection.pending == request else { return }
            self.rollbackSnapshot = snapshot
            let asset = self.makeResolutionAsset(data: data)
            let candidate = AVPlayerItem(asset: asset)
            self.replaceCurrentItem(with: candidate)

            self.switchObservation = candidate.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                DispatchQueue.main.async {
                    guard let self, self.selection.pending == request, self.switchObservation != nil else { return }
                    if item.status == .failed {
                        self.finishResolutionSwitch(request: request, resolution: resolution, succeeded: false)
                    } else if item.status == .readyToPlay {
                        self.switchObservation = nil
                        self.restore(snapshot: snapshot, on: item) { [weak self] restored in
                            DispatchQueue.main.async {
                                guard let self, self.selection.pending == request else { return }
                                self.finishResolutionSwitch(request: request, resolution: resolution, succeeded: restored)
                            }
                        }
                    }
                }
            }
        }
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.selection.pending == request else { return }
            self.finishResolutionSwitch(request: request, resolution: resolution, succeeded: false)
        }
        switchTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
    }

    public func stopStream() {
        resolutionPreparationTask?.cancel()
        mediaRestorationTask?.cancel()
        mediaRestorationID = UUID()
        contentKeySession?.invalidate()
        contentKeySession = nil
        preparationID = UUID()
        playlistTask?.cancel()
        playlistTask = nil
        selection.cancel()
        switchObservation = nil
        switchTimeout?.cancel()
        switchTimeout = nil
        rollbackItem = nil
        rollbackSnapshot = nil
        pendingResolution = nil
        pendingDynamicRange = nil
        currentItem?.cancelPendingSeeks()
        pause()
        replaceCurrentItem(with: nil)
        fairPlayAsset = nil
        playlistLock.lock()
        playlistData.removeAll()
        playlistLock.unlock()
    }

    public func cancelResolutionSwitch() {
        guard let request = selection.pending else { return }
        finishResolutionSwitch(request: request, resolution: pendingResolution, succeeded: false, resumePlayback: false)
    }

    private func makeResolutionAsset(data: Data) -> AVURLAsset {
        let url = URL(string: "f1-resolution://playlist/\(UUID().uuidString).m3u8")!
        playlistLock.lock()
        playlistData[url] = data
        playlistLock.unlock()
        // The in-memory master has a custom scheme, so AVFoundation treats it as
        // local. Its default policy rejects references to the service's CDN (-12660).
        // Allow CDN media and custom FairPlay key references. The playlist parser
        // rejects file URLs; remote assets remain unable to reference local files.
        let restrictions: AVAssetReferenceRestrictions = .forbidRemoteReferenceToLocal
        let asset = AVURLAsset(url: url, options: [AVURLAssetReferenceRestrictionsKey: NSNumber(value: restrictions.rawValue)])
        configureKeyHandling(for: asset)
        return asset
    }

    private func finishResolutionSwitch(request: UUID, resolution: StreamResolution?, succeeded: Bool, resumePlayback: Bool = true) {
        guard selection.finish(request, resolution: resolution, succeeded: succeeded) else { return }
        resolutionPreparationTask?.cancel()
        mediaRestorationTask?.cancel()
        mediaRestorationID = UUID()
        switchObservation = nil
        switchTimeout?.cancel()
        switchTimeout = nil
        let snapshot = rollbackSnapshot
        let original = rollbackItem
        rollbackItem = nil
        rollbackSnapshot = nil
        let dynamicRange = pendingDynamicRange
        pendingResolution = nil
        pendingDynamicRange = nil
        resolutionStatus = .available
        if succeeded {
            if let dynamicRange { selectedDynamicRange = dynamicRange }
            availableResolutions = playlist?.resolutions(for: selectedDynamicRange) ?? []
            fairPlayAsset = currentItem?.asset as? AVURLAsset
            if let snapshot = snapshot { rate = snapshot.rate }
        } else if let original = original {
            currentItem?.cancelPendingSeeks()
            replaceCurrentItem(with: original)
            fairPlayAsset = original.asset as? AVURLAsset
            if !resumePlayback { pause() }
            resolutionError = resumePlayback ? "Could not change stream quality. The previous selection was restored." : nil
            if let snapshot = snapshot {
                restore(snapshot: snapshot, on: original) { [weak self] _ in
                    DispatchQueue.main.async {
                        guard resumePlayback, let self = self, self.currentItem === original, self.selection.pending == nil else { return }
                        self.rate = snapshot.rate
                    }
                }
            }
        }
        let activeURL = fairPlayAsset?.url
        playlistLock.lock()
        playlistData = playlistData.filter { $0.key == activeURL }
        playlistLock.unlock()
        notifyResolutionChanged()
    }

    private func notifyResolutionChanged() {
        NotificationCenter.default.post(name: Self.resolutionDidChange, object: self)
    }

    private struct PlaybackSnapshot {
        struct MediaChoice {
            public let characteristic: AVMediaCharacteristic
            public let displayName: String?
            public let language: String?
        }
        let time: Double
        let date: Date?
        let secondsBehindLiveEdge: Double?
        let capturedAt = Date()
        let rate: Float
        var choices = [MediaChoice]()

        init(player: AVPlayer, item: AVPlayerItem) {
            time = player.currentTime().seconds
            date = item.currentDate()
            rate = player.rate
            if !item.duration.seconds.isFinite, let range = item.seekableTimeRanges.last?.timeRangeValue,
               time.isFinite, CMTimeRangeGetEnd(range).seconds.isFinite {
                secondsBehindLiveEdge = max(0, CMTimeRangeGetEnd(range).seconds - time)
            } else {
                secondsBehindLiveEdge = nil
            }
        }

        @MainActor
        func loadingMediaChoices(from item: AVPlayerItem) async -> Self {
            var snapshot = self
            snapshot.choices = []
            for characteristic in [AVMediaCharacteristic.audible, .legible] {
                guard let group = try? await item.asset.loadMediaSelectionGroup(for: characteristic) else { continue }
                guard !Task.isCancelled else { return self }
                let option = item.currentMediaSelection.selectedMediaOption(in: group)
                snapshot.choices.append(MediaChoice(characteristic: characteristic, displayName: option?.displayName, language: option?.extendedLanguageTag))
            }
            return snapshot
        }
    }

    private func restore(snapshot: PlaybackSnapshot, on item: AVPlayerItem, completion: @escaping (Bool) -> Void) {
        guard currentItem === item else { completion(false); return }
        mediaRestorationTask?.cancel()
        mediaRestorationID = UUID()
        let restorationID = mediaRestorationID
        mediaRestorationTask = Task { @MainActor [weak self] in
            for choice in snapshot.choices {
                guard let group = try? await item.asset.loadMediaSelectionGroup(for: choice.characteristic) else { continue }
                guard let self, !Task.isCancelled, self.mediaRestorationID == restorationID, self.currentItem === item else { completion(false); return }
                if choice.displayName == nil, group.allowsEmptySelection {
                    item.select(nil, in: group)
                } else if let option = group.options.first(where: { $0.displayName == choice.displayName })
                    ?? group.options.first(where: { choice.language != nil && $0.extendedLanguageTag == choice.language }) {
                    item.select(option, in: group)
                }
            }
            guard let self, !Task.isCancelled, self.mediaRestorationID == restorationID, self.currentItem === item else { completion(false); return }
            let elapsed = Date().timeIntervalSince(snapshot.capturedAt) * Double(snapshot.rate)
            if let date = snapshot.date, item.currentDate() != nil {
                self.seek(to: date.addingTimeInterval(elapsed)) { [weak self] succeeded in
                    DispatchQueue.main.async {
                        guard let self, self.mediaRestorationID == restorationID, self.currentItem === item else { completion(false); return }
                        if succeeded { completion(true) }
                        else { self.restoreTime(snapshot: snapshot, on: item, completion: completion) }
                    }
                }
                return
            }
            self.restoreTime(snapshot: snapshot, on: item, completion: completion)
        }
    }

    private func restoreTime(snapshot: PlaybackSnapshot, on item: AVPlayerItem, completion: @escaping (Bool) -> Void) {
        let elapsed = Date().timeIntervalSince(snapshot.capturedAt) * Double(snapshot.rate)
        var time = snapshot.time.isFinite ? max(0, snapshot.time + elapsed) : 0
        if let range = item.seekableTimeRanges.last?.timeRangeValue {
            if let lag = snapshot.secondsBehindLiveEdge, !item.duration.seconds.isFinite {
                let windowElapsed = Date().timeIntervalSince(snapshot.capturedAt)
                time = CMTimeRangeGetEnd(range).seconds - lag - windowElapsed * (1 - Double(snapshot.rate))
            }
            time = min(max(time, range.start.seconds), max(range.start.seconds, CMTimeRangeGetEnd(range).seconds - 0.1))
        } else if item.duration.seconds.isFinite {
            time = min(time, max(0, item.duration.seconds - 0.1))
        }
        seek(to: CMTime(seconds: time, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: completion)
    }


}

extension FairPlayer: AVAssetResourceLoaderDelegate {
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if AVFoundationFairPlaySession.routeResourceKey(url: loadingRequest.request.url, hasSession: contentKeySession != nil, finish: { contentType in
            // A resource-loader delegate must identify custom key URLs even when
            // AVContentKeySession performs SPC/CKC loading. Returning false rejects the key.
            loadingRequest.contentInformationRequest?.contentType = contentType
            loadingRequest.finishLoading()
        }) { return true }
        if let url = loadingRequest.request.url, url.scheme == "f1-resolution" {
            playlistLock.lock()
            let data = playlistData[url]
            playlistLock.unlock()
            guard let data = data else {
                loadingRequest.finishLoading(with: URLError(.resourceUnavailable))
                return true
            }
            loadingRequest.contentInformationRequest?.contentType = "public.m3u-playlist"
            loadingRequest.contentInformationRequest?.contentLength = Int64(data.count)
            loadingRequest.contentInformationRequest?.isByteRangeAccessSupported = true
            loadingRequest.response = URLResponse(url: url, mimeType: "application/vnd.apple.mpegurl", expectedContentLength: data.count, textEncodingName: "utf-8")
            if let request = loadingRequest.dataRequest {
                let offset = max(request.requestedOffset, request.currentOffset)
                let end = request.requestsAllDataToEndOfResource ? data.count : min(data.count, Int(request.requestedOffset) + request.requestedLength)
                if offset >= 0 && offset < Int64(end) {
                    request.respond(with: data.subdata(in: Int(offset)..<end))
                }
            }
            loadingRequest.finishLoading()
            return true
        }
        // Unsupported resources are not handled by this delegate.
        return false
    }

    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForRenewalOfRequestedResource renewalRequest: AVAssetResourceRenewalRequest) -> Bool {
        self.resourceLoader(resourceLoader, shouldWaitForLoadingOfRequestedResource: renewalRequest)
    }
}

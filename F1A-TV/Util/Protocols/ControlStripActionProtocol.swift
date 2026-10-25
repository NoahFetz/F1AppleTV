#if canImport(F1Core)
import F1Core
#endif
//
//  ControlStripActionProtocol.swift
//  F1A-TV
//
//  Created by Noah Fetz on 09.04.21.
//

import Foundation

@MainActor protocol ControlStripActionProtocol: AnyObject {
    var transportReference: PlayerItem? { get }
    var transportIsPlaying: Bool { get }
    func beginTransportPreview() -> MultiviewScrubSession?
    func commitTransportPreview(_ session: MultiviewScrubSession, time: Double)
    func cancelTransportPreview(_ session: MultiviewScrubSession, restorePlayback: Bool)
    func audioMixSnapshot() -> [AudioMixStreamState]
    func setStreamVolume(id: String, volume: Float)
    func setStreamMuted(id: String, muted: Bool)
    func willClosePlayer(id: String)
    func enterFullScreenPlayer(id: String)
    func playPausePlayer()
    func rewindPlayer()
    func forwardPlayer()
    func seekPlayersTo(time: Float64)
    func isSeekingPlayer(id: String) -> Bool
    func didFinishSeeking()
    func showChannelSelectorOverlay()
    func swapToMainPlayer(id: String)
    func showLayoutPicker()
    func showSetupPicker()
    func goLive()
    func restartStreams()
}

//
//  ControlStripActionProtocol.swift
//  F1A-TV
//
//  Created by Noah Fetz on 09.04.21.
//

import Foundation

protocol ControlStripActionProtocol {
    func willClosePlayer(id: String)
    func enterFullScreenPlayer(id: String)
    func playPausePlayer()
    func rewindPlayer()
    func forwardPlayer()
    func seekPlayersTo(time: Float64)
    func didFinishSeeking()
    func showChannelSelectorOverlay()
    func swapToMainPlayer(id: String)
}

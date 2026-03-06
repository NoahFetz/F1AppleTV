//
//  ControlStripActionProtocol.swift
//  F1A-TV
//
//  Created by Noah Fetz on 09.04.21.
//

import Foundation

protocol ControlStripActionProtocol {
    func willCloseFocusedPlayer()
    func enterFullScreenPlayer()
    func playPausePlayer()
    func rewindPlayer()
    func forwardPlayer()
    func showChannelSelectorOverlay()
    func swapToMainPlayer()  // New: Swap focused player to main position
}

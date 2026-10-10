#if canImport(F1Core)
import F1Core
#endif
//
//  ChannelSelectionProtocol.swift
//  F1A-TV
//
//  Created by Noah Fetz on 06.04.21.
//

import Foundation

protocol ChannelSelectionProtocol: AnyObject {
    func didSelectChannel(channelItem: ContentItem)
    func didRemoveChannel(channelItem: ContentItem)
}

//
//  AVPlayerItemExtension.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.04.21. from https://gist.github.com/peatiscoding/4f01a64797289fd40793837fb727c9c6
//

import AVFoundation
extension AVPlayerItem {
    enum TrackType {
        case subtitle
        case audio
        /**
         Return valid AVMediaSelectionGroup is item is available.
         */
        fileprivate func characteristic(item:AVPlayerItem) -> AVMediaSelectionGroup?  {
            let str = self == .subtitle ? AVMediaCharacteristic.legible : AVMediaCharacteristic.audible
            if item.asset.availableMediaCharacteristicsWithMediaSelectionOptions.contains(str) {
                return item.asset.mediaSelectionGroup(forMediaCharacteristic: str)
            }
            return nil
        }
    }
    
    func tracks(type:TrackType) -> [String] {
        if let characteristic = type.characteristic(item: self) {
            return characteristic.options.map { $0.displayName }
        }
        return [String]()
    }
    
    func selected(type:TrackType) -> String? {
        guard let group = type.characteristic(item: self) else {
            return nil
        }
        let selected = self.currentMediaSelection.selectedMediaOption(in: group)
        return selected?.displayName
    }
    
    func select(type:TrackType, name:String) -> Bool {
        guard let group = type.characteristic(item: self) else {
            return false
        }
        guard let matched = group.options.filter({ $0.displayName == name }).first else {
            return false
        }
        self.select(matched, in: group)
        return true
    }
}

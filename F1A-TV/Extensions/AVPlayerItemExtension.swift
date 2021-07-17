//
//  AVPlayerItemExtension.swift
//  F1A-TV
//
//  Created by Noah Fetz on 10.04.21. from https://gist.github.com/peatiscoding/4f01a64797289fd40793837fb727c9c6
//

import AVFoundation

struct MediaTrackDto {
    let displayName: String
    let propertyList: Any
}

extension AVPlayerItem {
    enum TrackType {
        case subtitle
        case audio
        case video
        /**
         Return valid AVMediaSelectionGroup is item is available.
         */
        fileprivate func characteristic(item:AVPlayerItem) -> AVMediaSelectionGroup?  {
            var str = AVMediaCharacteristic.audible
            
            switch self {
            case .subtitle:
                str = AVMediaCharacteristic.legible
                
            case .audio:
                str = AVMediaCharacteristic.audible
            
            case .video:
                str = AVMediaCharacteristic.visual
                
            }
            
            if item.asset.availableMediaCharacteristicsWithMediaSelectionOptions.contains(str) {
                return item.asset.mediaSelectionGroup(forMediaCharacteristic: str)
            }
            return nil
        }
    }
    
    func tracks(type:TrackType) -> [MediaTrackDto] {
        if let characteristic = type.characteristic(item: self) {
            return characteristic.options.map {
                MediaTrackDto(displayName: $0.displayName, propertyList: $0.propertyList())
            }
        }
        
        return [MediaTrackDto]()
    }
    
    func selected(type:TrackType) -> MediaTrackDto? {
        guard let group = type.characteristic(item: self) else {
            return nil
        }
        
        guard let selected = self.currentMediaSelection.selectedMediaOption(in: group) else {
            return nil
        }
        
        return MediaTrackDto(displayName: selected.displayName, propertyList: selected.propertyList())
    }
    
    func select(type:TrackType, item: MediaTrackDto) -> Bool {
        guard let group = type.characteristic(item: self) else {
            return false
        }
        
        let option = group.mediaSelectionOption(withPropertyList: item.propertyList);
        self.select(option, in: group)
        return true
    }
    
    func select(type:TrackType, languageDisplayName: String) -> Bool {
        guard let group = type.characteristic(item: self) else {
            return false
        }
        guard let matched = group.options.filter({ $0.displayName == languageDisplayName }).first else {
            return false
        }
        self.select(matched, in: group)
        return true
    }
}

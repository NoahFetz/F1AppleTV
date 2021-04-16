//
//  PlayerSettings.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.04.21.
//

import Foundation

struct PlayerSettings: Codable, Identifiable {
    var id: String
    var preferredChannelLanguage: [Int:String?]
    var preferredChannelVolume: [Int:Float]
    var preferredChannelMute: [Int:Bool]
    
    init() {
        self.id = UUID().uuidString
        self.preferredChannelLanguage = [Int:String]()
        self.preferredChannelVolume = [Int:Float]()
        self.preferredChannelMute = [Int:Bool]()
        
        for channelType in ChannelType.allCases {
            self.setPreferredLanugage(for: channelType, language: nil)
            self.setPreferredVolume(for: channelType, volume: 1)
            self.setPreferredMute(for: channelType, mute: false)
        }
    }
    
    init(id: String, preferredChannelLanguage: [Int:String?], preferredChannelVolume: [Int:Float], preferredChannelMute: [Int:Bool]) {
        self.id = id
        self.preferredChannelLanguage = preferredChannelLanguage
        self.preferredChannelVolume = preferredChannelVolume
        self.preferredChannelMute = preferredChannelMute
    }
    
    func getPreferredLanguage(for channelType: ChannelType) -> String? {
        let preferredLanguage = self.preferredChannelLanguage.first(where: {$0.key == channelType.getIdentifier()})?.value
        print("Preferred language for \(channelType) is \(preferredLanguage ?? "None")")
        return preferredLanguage
    }
    
    mutating func setPreferredLanugage(for channelType: ChannelType, language: String?) {
        print("Set preferred language for \(channelType) to \(language ?? "None")")
        self.preferredChannelLanguage[channelType.getIdentifier()] = language
    }
    
    func getPreferredVolume(for channelType: ChannelType) -> Float {
        let preferredVolume = self.preferredChannelVolume.first(where: {$0.key == channelType.getIdentifier()})?.value ?? 1
        print("Preferred volume for \(channelType) is \(preferredVolume)")
        return preferredVolume
    }
    
    mutating func setPreferredVolume(for channelType: ChannelType, volume: Float) {
        print("Set preferred volume for \(channelType) to \(volume)")
        self.preferredChannelVolume[channelType.getIdentifier()] = volume
    }
    
    func getPreferredMute(for channelType: ChannelType) -> Bool {
        let preferredMute = self.preferredChannelMute.first(where: {$0.key == channelType.getIdentifier()})?.value ?? false
        print("Preferred mute for \(channelType) is \(preferredMute)")
        return preferredMute
    }
    
    mutating func setPreferredMute(for channelType: ChannelType, mute: Bool) {
        print("Set preferred mute for \(channelType) to \(mute)")
        self.preferredChannelMute[channelType.getIdentifier()] = mute
    }
}

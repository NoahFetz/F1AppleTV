//
//  PlayerSettings.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.04.21.
//

import Foundation

public struct PlayerSettings: Codable, Identifiable {
    public var id: String
    public var preferredChannelLanguage: [Int:String?]
    public var preferredChannelCaptions: [Int:String?]
    public var preferredChannelVolume: [Int:Float]
    public var preferredChannelMute: [Int:Bool]
    public var driverChannelSorting: DriverChannelSortType
    public var showFunNames: Bool
    
    public var followsHeroBackground = true
    public var livePreviews = true
    public var scrubPreviews = false
    public var previewHeight = 360
    public var startupMaximumHeight: Int?
    public var liveStart = LiveStartPreference.ask
    public var defaultFeed = DefaultFeed.international
    // ISO language identifiers; "default" and "off" have explicit meanings.
    public var audioDefaults = [Int: String]()
    public var captionDefaults = [Int: String]()

    public enum CodingKeys: String, CodingKey {
        case id, preferredChannelLanguage, preferredChannelCaptions, preferredChannelVolume, preferredChannelMute
        case driverChannelSorting, showFunNames, followsHeroBackground, livePreviews, scrubPreviews, previewHeight
        case startupMaximumHeight, liveStart, defaultFeed, audioDefaults, captionDefaults
    }
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? id
        preferredChannelLanguage = try c.decodeIfPresent([Int: String?].self, forKey: .preferredChannelLanguage) ?? preferredChannelLanguage
        preferredChannelCaptions = try c.decodeIfPresent([Int: String?].self, forKey: .preferredChannelCaptions) ?? preferredChannelCaptions
        preferredChannelVolume = try c.decodeIfPresent([Int: Float].self, forKey: .preferredChannelVolume) ?? preferredChannelVolume
        preferredChannelMute = try c.decodeIfPresent([Int: Bool].self, forKey: .preferredChannelMute) ?? preferredChannelMute
        driverChannelSorting = try c.decodeIfPresent(DriverChannelSortType.self, forKey: .driverChannelSorting) ?? driverChannelSorting
        showFunNames = try c.decodeIfPresent(Bool.self, forKey: .showFunNames) ?? showFunNames
        followsHeroBackground = try c.decodeIfPresent(Bool.self, forKey: .followsHeroBackground) ?? true
        livePreviews = try c.decodeIfPresent(Bool.self, forKey: .livePreviews) ?? true
        scrubPreviews = try c.decodeIfPresent(Bool.self, forKey: .scrubPreviews) ?? false
        previewHeight = try c.decodeIfPresent(Int.self, forKey: .previewHeight) == 540 ? 540 : 360
        startupMaximumHeight = try c.decodeIfPresent(Int.self, forKey: .startupMaximumHeight)
        liveStart = try c.decodeIfPresent(LiveStartPreference.self, forKey: .liveStart) ?? .ask
        defaultFeed = (try? c.decode(DefaultFeed.self, forKey: .defaultFeed)) ?? .international
        audioDefaults = try c.decodeIfPresent([Int: String].self, forKey: .audioDefaults) ?? [:]
        captionDefaults = try c.decodeIfPresent([Int: String].self, forKey: .captionDefaults) ?? [:]
    }

    public init() {
        self.id = UUID().uuidString
        self.preferredChannelLanguage = [Int:String]()
        self.preferredChannelCaptions = [Int:String]()
        self.preferredChannelVolume = [Int:Float]()
        self.preferredChannelMute = [Int:Bool]()
        self.driverChannelSorting = DriverChannelSortType()
        self.showFunNames = false
        
        for channelType in ChannelType.allCases {
            self.setPreferredLanugage(for: channelType, language: nil)
            self.setPreferredCaptions(for: channelType, captions: nil)
            self.setPreferredVolume(for: channelType, volume: 1)
            self.setPreferredMute(for: channelType, mute: false)
        }
    }
    
    public init(id: String, preferredChannelLanguage: [Int:String?], preferredChannelCaptions: [Int:String?], preferredChannelVolume: [Int:Float], preferredChannelMute: [Int:Bool], driverChannelSorting: DriverChannelSortType, showFunNames: Bool) {
        self.id = id
        self.preferredChannelLanguage = preferredChannelLanguage
        self.preferredChannelCaptions = preferredChannelCaptions
        self.preferredChannelVolume = preferredChannelVolume
        self.preferredChannelMute = preferredChannelMute
        self.driverChannelSorting = driverChannelSorting
        self.showFunNames = showFunNames
    }
    
    public func getPreferredLanguage(for channelType: ChannelType) -> String? {
        let preferredLanguage = self.preferredChannelLanguage.first(where: {$0.key == channelType.getIdentifier()})?.value
        print("Preferred language for \(channelType) is \(preferredLanguage ?? "None")")
        return preferredLanguage
    }
    
    public mutating func setPreferredLanugage(for channelType: ChannelType, language: String?) {
        print("Set preferred language for \(channelType) to \(language ?? "None")")
        self.preferredChannelLanguage[channelType.getIdentifier()] = language
    }
    
    public func getPreferredCaptions(for channelType: ChannelType) -> String? {
        let preferredCaptions = self.preferredChannelCaptions.first(where: {$0.key == channelType.getIdentifier()})?.value
        print("Preferred captions for \(channelType) is \(preferredCaptions ?? "None")")
        return preferredCaptions
    }
    
    public mutating func setPreferredCaptions(for channelType: ChannelType, captions: String?) {
        print("Set preferred captions for \(channelType) to \(captions ?? "None")")
        self.preferredChannelCaptions[channelType.getIdentifier()] = captions
    }
    
    public func getPreferredVolume(for channelType: ChannelType) -> Float {
        let preferredVolume = self.preferredChannelVolume.first(where: {$0.key == channelType.getIdentifier()})?.value ?? 1
        print("Preferred volume for \(channelType) is \(preferredVolume)")
        return preferredVolume
    }
    
    public mutating func setPreferredVolume(for channelType: ChannelType, volume: Float) {
        print("Set preferred volume for \(channelType) to \(volume)")
        self.preferredChannelVolume[channelType.getIdentifier()] = volume
    }
    
    public func getPreferredMute(for channelType: ChannelType) -> Bool {
        let preferredMute = self.preferredChannelMute.first(where: {$0.key == channelType.getIdentifier()})?.value ?? false
        print("Preferred mute for \(channelType) is \(preferredMute)")
        return preferredMute
    }
    
    public mutating func setPreferredMute(for channelType: ChannelType, mute: Bool) {
        print("Set preferred mute for \(channelType) to \(mute)")
        self.preferredChannelMute[channelType.getIdentifier()] = mute
    }
}

public enum LiveStartPreference: String, Codable, CaseIterable { case ask, live, beginning }

//
//  DataManager.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation

class DataManager {
    static let instance = DataManager()
    
    var seasons = [SeasonDto]()
    var events = [EventDto]()
    var images = [ImageDto]()
    var sessions = [SessionDto]()
    var channels = [ChannelDto]()
    var drivers = [DriverDto]()
    var episodes = [EpisodeDto]()
    
    func loadSeasonLookup() {
        NetworkRouter.instance.getSeasonLookup(completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                case .success(let requestResult):
                    self.seasons = requestResult.resultObjects.filter({$0.hasContent && $0.year >= 2018}).sorted(by: {$0.year > $1.year})
                    
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .seasonsChanged, object: nil)
                    }
                }
            }
        })
    }
    
    func loadEvent(eventUrl: String, eventProtocol: EventLoadedProtocol) {
        NetworkRouter.instance.getEventLookup(eventUrl: eventUrl, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                case .success(let requestResult):
                    self.events.removeAll(where: {$0.uid == requestResult.uid})
                    self.events.append(requestResult)
                    
                    DispatchQueue.main.async {
                        eventProtocol.didLoadEvent(event: requestResult)
                    }
                }
            }
        })
    }
    
    func loadImage(imageUrl: String) {
        NetworkRouter.instance.getImageLookup(imageUrl: imageUrl, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                case .success(let requestResult):
                    self.images.removeAll(where: {$0.uid == requestResult.uid})
                    self.images.append(requestResult)
                    
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .imageChanged, object: nil)
                    }
                }
            }
        })
    }
    
    func loadImage(imageUrl: String, imageProtocol: ImageLoadedProtocol) {
        NetworkRouter.instance.getImageLookup(imageUrl: imageUrl, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                case .success(let requestResult):
                    self.images.removeAll(where: {$0.uid == requestResult.uid})
                    self.images.append(requestResult)
                    
                    DispatchQueue.main.async {
                        imageProtocol.didLoadImage(image: requestResult)
                    }
                }
            }
        })
    }
    
    func loadSession(sessionUrl: String, sessionProtocol: SessionLoadedProtocol) {
        NetworkRouter.instance.getSessionLookup(sessionUrl: sessionUrl, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                case .success(let requestResult):
                    self.sessions.removeAll(where: {$0.uid == requestResult.uid})
                    self.sessions.append(requestResult)
                    
                    DispatchQueue.main.async {
                        sessionProtocol.didLoadSession(session: requestResult)
                    }
                }
            }
        })
    }
    
    func loadDriver(driverUrl: String, driverProtocol: DriverLoadedProtocol) {
        NetworkRouter.instance.getDriverLookup(driverUrl: driverUrl, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                case .success(let requestResult):
                    self.drivers.removeAll(where: {$0.uid == requestResult.uid})
                    self.drivers.append(requestResult)
                    
                    DispatchQueue.main.async {
                        driverProtocol.didLoadDriver(driver: requestResult)
                    }
                }
            }
        })
    }
    
    func loadEpisode(episodeUrl: String, episodeProtocol: EpisodeLoadedProtocol) {
        NetworkRouter.instance.getEpisodeLookup(episodeUrl: episodeUrl, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                case .success(let requestResult):
                    self.episodes.removeAll(where: {$0.uid == requestResult.uid})
                    self.episodes.append(requestResult)
                    
                    DispatchQueue.main.async {
                        episodeProtocol.didLoadEpisode(episode: requestResult)
                    }
                }
            }
        })
    }
    
    func loadChannel(channelUrl: String, channelProtocol: ChannelLoadedProtocol) {
        NetworkRouter.instance.getChannelLookup(channelUrl: channelUrl, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                case .success(var requestResult):
                    switch requestResult.name.lowercased() {
                    case "wif":
                        requestResult.name = NSLocalizedString("wif", comment: "")
                        
                    case "pit lane":
                        requestResult.name = NSLocalizedString("pit_lane", comment: "")
                        
                    case "data":
                        requestResult.name = NSLocalizedString("data", comment: "")
                        
                    case "driver":
                        requestResult.name = NSLocalizedString("driver", comment: "")
                    default:
                        break
                    }
                    
                    self.channels.removeAll(where: {$0.uid == requestResult.uid})
                    self.channels.append(requestResult)
                    
                    DispatchQueue.main.async {
                        channelProtocol.didLoadChannel(channel: requestResult)
                    }
                }
            }
        })
    }
}

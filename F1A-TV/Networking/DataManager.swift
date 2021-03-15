//
//  DataManager.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation

class DataManager {
    static let instance = DataManager()
    
    var images = [ImageDto]()
    var drivers = [DriverDto]()
    var nations = [NationDto]()
    var series = [SeriesDto]()
    var teams = [TeamDto]()
    var assets = [AssetDto]()
    
    func loadSeasonLookup(returnInterface: SeasonsLoadedProtocol) {
        NetworkRouter.instance.getSeasonLookup(completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                case .success(let requestResult):
                    DispatchQueue.main.async {
                        returnInterface.didLoadSeasons(seasons: requestResult.resultObjects.filter({$0.hasContent && $0.year >= 2018}).sorted(by: {$0.year > $1.year}))
                    }
                }
            }
        })
    }
    
    func loadVodLookup(returnInterface: VodLoadedProtocol) {
        NetworkRouter.instance.getVodLookup(completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                case .success(let requestResult):
                    DispatchQueue.main.async {
                        returnInterface.didLoadVod(vods: requestResult.resultObjects.filter({!$0.contentUrls.isEmpty}).sorted(by: {$0.name < $1.name}))
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
                    DispatchQueue.main.async {
                        eventProtocol.didLoadEvent(event: requestResult)
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
                    DispatchQueue.main.async {
                        sessionProtocol.didLoadSession(session: requestResult)
                    }
                }
            }
        })
    }
    
    func loadNation(nationUrl: String, nationProtocol: NationLoadedProtocol) {
        NetworkRouter.instance.getNationLookup(nationUrl: nationUrl, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                case .success(let requestResult):
                    self.nations.removeAll(where: {$0.uid == requestResult.uid})
                    self.nations.append(requestResult)
                    
                    DispatchQueue.main.async {
                        nationProtocol.didLoadNation(nation: requestResult)
                    }
                }
            }
        })
    }
    
    func loadSeries(seriesUrl: String, seriesProtocol: SeriesLoadedProtocol) {
        NetworkRouter.instance.getSeriesLookup(seriesUrl: seriesUrl, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                case .success(let requestResult):
                    self.series.removeAll(where: {$0.uid == requestResult.uid})
                    self.series.append(requestResult)
                    
                    DispatchQueue.main.async {
                        seriesProtocol.didLoadSeries(series: requestResult)
                    }
                }
            }
        })
    }
    
    func loadAsset(assetUrl: String, assetProtocol: AssetLoadedProtocol) {
        NetworkRouter.instance.getAssetLookup(assetUrl: assetUrl, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                case .success(let requestResult):
                    self.assets.removeAll(where: {$0.uid == requestResult.uid})
                    self.assets.append(requestResult)
                    
                    DispatchQueue.main.async {
                        assetProtocol.didLoadAsset(asset: requestResult)
                    }
                }
            }
        })
    }
    
    func loadTeam(teamUrl: String, teamProtocol: TeamLoadedProtocol) {
        NetworkRouter.instance.getTeamLookup(teamUrl: teamUrl, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                case .success(let requestResult):
                    self.teams.removeAll(where: {$0.uid == requestResult.uid})
                    self.teams.append(requestResult)
                    
                    DispatchQueue.main.async {
                        teamProtocol.didLoadTeam(team: requestResult)
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
                    DispatchQueue.main.async {
                        episodeProtocol.didLoadEpisode(episode: requestResult)
                    }
                }
            }
        })
    }
    
    func loadContentPage(pageUri: String, contentPageProtocol: ContentPageLoadedProtocol) {
        NetworkRouter.instance.getContentPageLookup(pageUri: pageUri, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                case .success(let requestResult):
                    if let resultObject = requestResult.resultObj {
                        DispatchQueue.main.async {
                            contentPageProtocol.didLoadContentPage(contentPage: resultObject)
                        }
                    }
                }
            }
        })
    }
    
    func loadContentVideo(videoId: String, contentVideoProtocol: ContentVideoLoadedProtocol) {
        NetworkRouter.instance.getContentVideo(videoId: videoId, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                case .success(let requestResult):
                    if let resultObject = requestResult.resultObj {
                        DispatchQueue.main.async {
                            contentVideoProtocol.didLoadVideo(contentVideo: resultObject)
                        }
                    }
                }
            }
        })
    }
    
    func loadStreamEntitlement(contentId: String, streamEntitlementLoadedProtocol: StreamEntitlementLoadedProtocol) {
        NetworkRouter.instance.getStreamEntitlement(contentId: contentId, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error occured: \(error.localizedDescription)")
                case .success(let requestResult):
                    if let resultObject = requestResult.resultObj {
                        DispatchQueue.main.async {
                            streamEntitlementLoadedProtocol.didLoadStreamEntitlement(streamEntitlement: resultObject)
                        }
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
                    
                    DispatchQueue.main.async {
                        channelProtocol.didLoadChannel(channel: requestResult)
                    }
                }
            }
        })
    }
}

//
//  DataManager.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation

class DataManager {
    static let instance = DataManager()
    
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
}

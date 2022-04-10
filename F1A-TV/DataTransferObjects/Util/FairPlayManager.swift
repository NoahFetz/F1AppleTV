//
//  FairPlayManager.swift
//  F1A-TV
//
//  Created by Noah Fetz on 09.04.22.
//

import Foundation
import AVKit

class FairPlayManager: NSObject, AVAssetResourceLoaderDelegate {
    var streamEntitlement: StreamEntitlementDto
    var fairPlayAsset: AVURLAsset?
    
    init(streamEntitlement: StreamEntitlementDto) {
        self.streamEntitlement = streamEntitlement
    }
    
    func makeFairPlayReady() -> AVURLAsset? {
        if let url = URL(string: self.streamEntitlement.url) {
            self.fairPlayAsset = AVURLAsset(url: url)
            self.fairPlayAsset?.resourceLoader.setDelegate(self, queue: DispatchQueue(label: "VroomFairPlayManager"))
        }
        
        return self.fairPlayAsset
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if let dataRequest = loadingRequest.dataRequest, let fairPlayCertificate = DataManager.instance.fairPlayCertificate, let loadingRequestHost = loadingRequest.request.url?.host, let contentIdData = loadingRequestHost.dropFirst(2).data(using: .utf8), let laUrl = self.streamEntitlement.laUrl {
            
            guard let spcData = try? loadingRequest.streamingContentKeyRequestData(forApp: fairPlayCertificate, contentIdentifier: contentIdData, options: nil)
            else {
                UserInteractionHelper.instance.showError(title: "DRM Error", message: "SPC Data is empty")
                print("SPC Data is empty")
                loadingRequest.finishLoading()
                return false
            }
            
            DataManager.instance.getFairPlayLease(fairPlayRequestUrl: laUrl, fairPlayRequestData: spcData, assetId: loadingRequestHost) { (ckcData, error) in
                if let ckcEncodedData = ckcData, let ckc = Data(base64Encoded: ckcEncodedData) {
                    dataRequest.respond(with: ckc)
                    loadingRequest.contentInformationRequest?.contentType = AVStreamingKeyDeliveryContentKeyType
                    loadingRequest.finishLoading()
                }
            }
        }else{
            loadingRequest.finishLoading()
            UserInteractionHelper.instance.showError(title: "DRM Error", message: "Couldn't form SPC Data")
            print("Couldn't form SPC Data")
            return false
        }
        
        return true
    }
}

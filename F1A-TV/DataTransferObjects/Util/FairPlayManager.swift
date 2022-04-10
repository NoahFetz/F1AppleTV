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
        if let dataRequest = loadingRequest.dataRequest, let fairPlayCertificate = DataManager.instance.fairPlayCertificate, let contentIdData = (loadingRequest.request.url?.host ?? "").data(using: String.Encoding.utf8), let laUrl = self.streamEntitlement.laUrl, let assetId = self.getAssetId() {
            
            guard let spcData = try? loadingRequest.streamingContentKeyRequestData(forApp: fairPlayCertificate, contentIdentifier: contentIdData, options: nil)
            else {
                UserInteractionHelper.instance.showError(title: "DRM Error", message: "SPC Data is empty")
                print("SPC Data is empty")
                loadingRequest.finishLoading()
                return false
            }
            
            DataManager.instance.getFairPlayLease(fairPlayRequestUrl: laUrl, fairPlayRequestData: spcData, assetId: assetId) { (ckcData, error) in
                if let ckcEncodedData = ckcData, let ckc = Data(base64Encoded: ckcEncodedData) {
                    ///-------- Option 1 --------
                    //dataRequest.respond(with: ckc)
                    //loadingRequest.contentInformationRequest?.contentType = AVStreamingKeyDeliveryContentKeyType
                    ///----------------
                    
                    ///-------- Option 2 --------
                    var persistentKeyData: Data?
                    do {
                        persistentKeyData = try loadingRequest.persistentContentKey(fromKeyVendorResponse: ckc, options: nil)
                    } catch {
                        UserInteractionHelper.instance.showError(title: "DRM Error", message: "Persistent key error")
                        print("Persistent key error")
                        loadingRequest.finishLoading()
                        return
                    }
                    
                    loadingRequest.contentInformationRequest?.contentType = AVStreamingKeyDeliveryPersistentContentKeyType
                    
                    if let persistentKey = persistentKeyData {
                        dataRequest.respond(with: persistentKey)
                    }else{
                        UserInteractionHelper.instance.showError(title: "DRM Error", message: "Couldn't create persistent key")
                        print("Couldn't create persistent key")
                    }
                    ///----------------
                    
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
    
    func getAssetId() -> String? {
        if let fullAssetString = self.streamEntitlement.url.components(separatedBy: "+00:00").last {
            let numberToPrefix = fullAssetString.count / 5
            
            let decimalString = String(fullAssetString.prefix(numberToPrefix))
            let decimalBigInt = BigInt(decimalString)
            if let hexString = decimalBigInt?.hexString {
                return hexString
            }
        }
        
        return nil
    }
}

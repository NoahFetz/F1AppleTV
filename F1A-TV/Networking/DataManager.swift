//
//  DataManager.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation
import Alamofire

class DataManager {
    static let instance = DataManager()
    var alamofireSession = Session.default
    
    init() {
        let configuration = URLSessionConfiguration.af.default
        configuration.httpAdditionalHeaders = ["User-Agent" : "RaceControl"]
        self.alamofireSession = Session(configuration: configuration)
    }
    
    func loadAuthData(authRequest: AuthRequestDto, authDataLoadedProtocol: AuthDataLoadedProtocol) {
        self.alamofireSession.request(ConstantsUtil.authenticateUrl,
                                      method: .post,
                                      parameters: authRequest,
                                      encoder: JSONParameterEncoder.default,
                                      headers: [HTTPHeader(name: "apikey", value: ConstantsUtil.apiKey)])
            .validate()
            .responseDecodable(of: AuthResultDto.self) { response in
                
            switch response.result {
            case .success(let apiResponse):
                DispatchQueue.main.async {
                    authDataLoadedProtocol.didLoadAuthData(authResult: apiResponse)
                }
                
            case .failure(let afError):
                self.handleAFError(afError: afError)
            }
        }
    }
    
    func loadTokenRequest(tokenRequest: TokenRequestDto, authDataLoadedProtocol: AuthDataLoadedProtocol) {
        self.alamofireSession.request(ConstantsUtil.tokenUrl,
                                      method: .post,
                                      parameters: tokenRequest,
                                      encoder: JSONParameterEncoder.default)
            .validate()
            .responseDecodable(of: TokenResultDto.self) { response in
                
            switch response.result {
            case .success(let apiResponse):
                DispatchQueue.main.async {
                    authDataLoadedProtocol.didLoadToken(tokenResult: apiResponse)
                }
                
            case .failure(let afError):
                self.handleAFError(afError: afError)
            }
        }
    }
    
    func loadContentPage(pageUri: String, contentPageProtocol: ContentPageLoadedProtocol) {
        self.alamofireSession.request(ConstantsUtil.apiUrl + pageUri, method: .get)
            .validate()
            .responseDecodable(of: ApiResponseDto.self) { response in
                
            switch response.result {
            case .success(let apiResponse):
                if let resultObject = apiResponse.resultObj {
                    DispatchQueue.main.async {
                        contentPageProtocol.didLoadContentPage(contentPage: resultObject)
                    }
                }
                
            case .failure(let afError):
                self.handleAFError(afError: afError)
            }
        }
    }
    
    func loadContentVideo(videoId: String, contentVideoProtocol: ContentVideoLoadedProtocol) {
        self.alamofireSession.request("\(ConstantsUtil.apiUrl)/2.0/R/\(NSLocalizedString("api_endpoing_language_id", comment: ""))/BIG_SCREEN_HLS/ALL/CONTENT/VIDEO/\(videoId)/F1_TV_Pro_Annual/2", method: .get)
            .validate()
            .responseDecodable(of: ApiResponseDto.self) { response in
                
            switch response.result {
            case .success(let apiResponse):
                if let resultObject = apiResponse.resultObj {
                    DispatchQueue.main.async {
                        contentVideoProtocol.didLoadVideo(contentVideo: resultObject)
                    }
                }
                
            case .failure(let afError):
                self.handleAFError(afError: afError)
            }
        }
    }
    
    func loadStreamEntitlement(contentId: String, playerId: String = "", streamEntitlementLoadedProtocol: StreamEntitlementLoadedProtocol) {
        self.alamofireSession.request("\(ConstantsUtil.apiUrl)/1.0/R/\(NSLocalizedString("api_endpoing_language_id", comment: ""))/BIG_SCREEN_HLS/ALL/\(contentId)",
                                      method: .get,
                                      headers: [HTTPHeader(name: "ascendontoken", value: CredentialHelper.instance.getUserInfo().authData.subscriptionToken)])
            .validate()
            .responseDecodable(of: StreamEntitlementResultDto.self) { response in
                
            switch response.result {
            case .success(let apiResponse):
                if let resultObject = apiResponse.resultObj {
                    DispatchQueue.main.async {
                        streamEntitlementLoadedProtocol.didLoadStreamEntitlement(playerId: playerId, streamEntitlement: resultObject)
                    }
                }
                
            case .failure(let afError):
                self.handleAFError(afError: afError)
            }
        }
    }
    
    func handleAFError(afError: AFError) {
        var outputErrorMessage = ""
        
        switch afError {
        case .invalidURL(let url):
            outputErrorMessage.append("Invalid URL: \(url) - \(afError.localizedDescription)")
        case .parameterEncodingFailed(let reason):
            outputErrorMessage.append("Parameter encoding failed: \(afError.localizedDescription)")
            outputErrorMessage.append("Failure Reason: \(reason)")
        case .multipartEncodingFailed(let reason):
            outputErrorMessage.append("Multipart encoding failed: \(afError.localizedDescription)")
            outputErrorMessage.append("Failure Reason: \(reason)")
        case .responseValidationFailed(let reason):
            outputErrorMessage.append("Response validation failed: \(afError.localizedDescription)")
            outputErrorMessage.append("Failure Reason: \(reason)")
            
            switch reason {
            case .dataFileNil, .dataFileReadFailed:
                outputErrorMessage.append("Downloaded file could not be read")
            case .missingContentType(let acceptableContentTypes):
                outputErrorMessage.append("Content Type Missing: \(acceptableContentTypes)")
            case .unacceptableContentType(let acceptableContentTypes, let responseContentType):
                outputErrorMessage.append("Response content type: \(responseContentType) was unacceptable: \(acceptableContentTypes)")
            case .unacceptableStatusCode(let code):
                outputErrorMessage.append("Response status code was unacceptable: \(code)")
            case .customValidationFailed(error: let error):
                outputErrorMessage.append("Custom validation failed: \(error)")
            }
        case .responseSerializationFailed(let reason):
            outputErrorMessage.append("Response serialization failed: \(afError.localizedDescription)")
            outputErrorMessage.append("Failure Reason: \(reason)")
            
        default:
            outputErrorMessage.append("Unknown error occured: \(afError.localizedDescription)")
            outputErrorMessage.append("Full error: \(afError)")
        }
        
        print(outputErrorMessage)
        print("Underlying error: \(String(describing: afError.underlyingError))")
        SPAlert.present(title: NSLocalizedString("error", comment: ""), message: outputErrorMessage, preset: .error)
    }
}

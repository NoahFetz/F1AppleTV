//
//  DataManager.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation
import Alamofire
import SPAlert

class DataManager: RequestInterceptor {
    static let instance = DataManager()
    var alamofireSession = Session.default
    
    var apiStreamType = APIStreamType()
    var apiLanguage = APILanguageType()
    var apiVersion = APIVersionType.V3
    let sessionId = "WEB-\(UUID().uuidString)"
    
    init() {
        let configuration = URLSessionConfiguration.af.default
        configuration.httpAdditionalHeaders = ["User-Agent" : "RaceControl"]
        self.alamofireSession = Session(configuration: configuration)
        
        self.apiStreamType = CredentialHelper.getPlayerSettings().preferredCdn
        self.apiLanguage = CredentialHelper.getPlayerSettings().preferredApiLanguage
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
    
    func loadContentPage(pageUri: String, contentPageProtocol: ContentPageLoadedProtocol) {
        self.alamofireSession.request("\(ConstantsUtil.apiUrl)\(pageUri)", method: .get)
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
        self.alamofireSession.request("\(ConstantsUtil.apiUrl)/\(self.apiVersion.getVersionType())/R/\(self.apiLanguage.getAPIKey())/\(self.apiStreamType.getAPIKey())/ALL/CONTENT/VIDEO/\(videoId)/F1_TV_Pro_Annual/14",
                                      method: .get,
                                      headers: [HTTPHeader(name: "sessionid", value: self.sessionId), HTTPHeader(name: "entitlementtoken", value: CredentialHelper.instance.getUserInfo().sessionId), HTTPHeader(name: "ascendontoken", value: CredentialHelper.instance.getUserInfo().authData.subscriptionToken)])
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
        self.alamofireSession.request("\(ConstantsUtil.apiUrl)/\(APIVersionType.V2.getVersionType())/R/\(self.apiLanguage.getAPIKey())/\(self.apiStreamType.getAPIKey())/ALL/\(contentId)",
                                      method: .get,
                                      headers: [HTTPHeader(name: "sessionid", value: self.sessionId), HTTPHeader(name: "entitlementtoken", value: CredentialHelper.instance.getUserInfo().sessionId), HTTPHeader(name: "ascendontoken", value: CredentialHelper.instance.getUserInfo().authData.subscriptionToken)],
                                      interceptor: self)
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
    
    func loadM3U8Data(url: String, completion: @escaping (_ m3u8Data: String) -> Void) {
        self.alamofireSession.request(url, method: .get)
            .validate()
            .responseString() { response in
                switch response.result {
                case .success(let apiResponse):
                    DispatchQueue.main.async {
                        completion(apiResponse)
                    }
                    
                case .failure(let afError):
                    self.handleAFError(afError: afError)
                }
            }
    }
    
    func reportContentPlayTime(reportingItem: PlayTimeReportingDto, playTimeReportingProtocol: PlayTimeReportedProtocol) {
        self.alamofireSession.request("\(ConstantsUtil.apiUrl)/\(APIVersionType.V1.getVersionType())/R/\(self.apiLanguage.getAPIKey())/\(self.apiStreamType.getAPIKey())/ALL/ACTION/PLAY",
                                      method: .post,
                                      parameters: reportingItem,
                                      encoder: JSONParameterEncoder.default,
                                      headers: [HTTPHeader(name: "sessionid", value: self.sessionId), HTTPHeader(name: "entitlementtoken", value: CredentialHelper.instance.getUserInfo().sessionId), HTTPHeader(name: "ascendontoken", value: CredentialHelper.instance.getUserInfo().authData.subscriptionToken)])
            .validate()
            .responseDecodable(of: PlayTimeReportingResultDto.self) { response in
                
            switch response.result {
            case .success(let apiResponse):
                print("Reporting result: \(apiResponse.resultCode)")
                DispatchQueue.main.async {
                    playTimeReportingProtocol.didReportPlayTime()                }
                
            case .failure(let afError):
                self.handleAFError(afError: afError)
            }
        }
    }
    
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var request = urlRequest
        if(CredentialHelper.instance.getUserInfo().authData.subscriptionToken == urlRequest.headers.first(where: {$0.name == "ascendontoken"})?.value) {
            completion(.success(urlRequest))
            return
        }
        
        request.headers = [HTTPHeader(name: "ascendontoken", value: CredentialHelper.instance.getUserInfo().authData.subscriptionToken)]
        print("Adapted - Token set to the header field is: \(CredentialHelper.instance.getUserInfo().authData.subscriptionToken)")
        completion(.success(request))
    }
    
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        guard request.retryCount <= 3 else {
            completion(.doNotRetry)
            return
        }
        
        print("Retried - Retry count: \(request.retryCount)")
        self.refreshToken { isSuccess in
            isSuccess ? completion(.retry) : completion(.doNotRetry)
        }
    }
    
    func refreshToken(completion: @escaping (_ isSuccess: Bool) -> Void) {
        let authRequest = AuthRequestDto(login: CredentialHelper.instance.getUserInfo().subscriber.email, password: CredentialHelper.instance.getPassword())
        self.alamofireSession.request(ConstantsUtil.authenticateUrl,
                                      method: .post,
                                      parameters: authRequest,
                                      encoder: JSONParameterEncoder.default,
                                      headers: [HTTPHeader(name: "apikey", value: ConstantsUtil.apiKey)])
            .validate()
            .responseDecodable(of: AuthResultDto.self) { response in
                
                switch response.result {
                case .success(let apiResponse):
                    CredentialHelper.instance.setUserInfo(userInfo: apiResponse)
                    completion(true)
                    
                case .failure(let afError):
                    self.handleAFError(afError: afError)
                    completion(false)
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
        
        SPAlert.present(title: "error".localizedString, message: outputErrorMessage, preset: .error)
    }
}

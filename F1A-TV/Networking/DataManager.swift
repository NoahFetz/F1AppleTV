//
//  DataManager.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation
import Alamofire
import SPAlert

class DataManager: RequestInterceptor, @unchecked Sendable {
    static let instance = DataManager()
    var alamofireSession = Session.default
    
    var apiStreamType = APIStreamType.BigScreenHLS
    var apiLanguage = APILanguageType.fromAPIKey(apiKey: "api_endpoing_language_id".localizedString)
    var apiVersion = APIVersionType.V3
    let sessionId = "WEB-\(UUID().uuidString)"
    
    var challengeToken = ""
    var fairPlayCertificate: Data?
    
    init() {
        let configuration = URLSessionConfiguration.af.default
        configuration.httpAdditionalHeaders = ["User-Agent" : "F1TV-tvOS Darwin"]
        self.alamofireSession = Session(configuration: configuration)
        self.loadFairPlayCertificate()
    }
    
    /**
     TODO: Check for device limit  -> json looks like this
     {
         "ContextId": "74b1ec48-1a4a-4a6d-9af2-b5054f4c9a8b",
         "Fault": {
             "Code": 811,
             "Message": "The subscriber already has the limited number of active associated devices.",
             "Severity": 4
         }
     }
     */
    func performDeviceRegistration(deviceRegistrationRequest: DeviceRegistrationRequestDto, deviceRegistrationLoadedProtocol: DeviceRegistrationLoadedProtocol) {
        self.alamofireSession.request(ConstantsUtil.deviceRegistrationUrl,
                                      method: .post,
                                      parameters: deviceRegistrationRequest,
                                      encoder: JSONParameterEncoder.default,
                                      headers: [HTTPHeader(name: "apikey", value: ConstantsUtil.deviceRegistrationApiKey), HTTPHeader(name: "X-D-Token", value: self.challengeToken), HTTPHeader(name: "CD-SystemID", value: ConstantsUtil.deviceRegistrationSystemId)])
            .validate()
            .responseDecodable(of: DeviceRegistrationResultDto.self) { response in
            switch response.result {
            case .success(let apiResponse):
                DispatchQueue.main.async {
                    deviceRegistrationLoadedProtocol.didPerformDeviceRegistration(deviceRegistration: apiResponse)
                }
                
            case .failure(let afError):
                self.handleAFError(afError: afError)
            }
        }
    }
    
    func performDeviceUnregistration(deviceRegistrationLoadedProtocol: DeviceRegistrationLoadedProtocol) {
        let deviceUnregistrationRequest = DeviceUnregistrationRequestDto()
        
        self.alamofireSession.request(ConstantsUtil.deviceUnregistrationUrl,
                                      method: .post,
                                      parameters: deviceUnregistrationRequest,
                                      encoder: JSONParameterEncoder.default,
                                      headers: [HTTPHeader(name: "apikey", value: ConstantsUtil.deviceRegistrationApiKey), HTTPHeader(name: "CD-SessionID", value: CredentialHelper.instance.getDeviceRegistration().sessionId), HTTPHeader(name: "CD-SystemID", value: ConstantsUtil.deviceRegistrationSystemId)])
            .validate()
            .response() { response in
            switch response.result {
            case .success( _):
                DispatchQueue.main.async {
                    deviceRegistrationLoadedProtocol.didPerformDeviceUnregistration()
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
                                      headers: [HTTPHeader(name: "sessionid", value: self.sessionId), HTTPHeader(name: "entitlementtoken", value: CredentialHelper.instance.getDeviceRegistration().data.subscriptionToken), HTTPHeader(name: "ascendontoken", value: CredentialHelper.instance.getDeviceRegistration().data.subscriptionToken)])
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
                                      headers: [HTTPHeader(name: "sessionid", value: self.sessionId), HTTPHeader(name: "entitlementtoken", value: CredentialHelper.instance.getDeviceRegistration().sessionId), HTTPHeader(name: "ascendontoken", value: CredentialHelper.instance.getDeviceRegistration().data.subscriptionToken), HTTPHeader(name: "x-f1-device-info", value: "device=tvos;screen=bigscreen;os=tvos;model=appletv14.1;osVersion=16.4;appVersion=2.11.0;playerVersion=3.16.0")],
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
                                      headers: [HTTPHeader(name: "sessionid", value: self.sessionId), HTTPHeader(name: "entitlementtoken", value: CredentialHelper.instance.getDeviceRegistration().sessionId), HTTPHeader(name: "ascendontoken", value: CredentialHelper.instance.getDeviceRegistration().data.subscriptionToken)])
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
        if(CredentialHelper.instance.getDeviceRegistration().data.subscriptionToken == urlRequest.headers.first(where: {$0.name == "ascendontoken"})?.value) {
            completion(.success(urlRequest))
            return
        }
        
        request.headers = [HTTPHeader(name: "entitlementtoken", value: CredentialHelper.instance.getDeviceRegistration().sessionId), HTTPHeader(name: "ascendontoken", value: CredentialHelper.instance.getDeviceRegistration().data.subscriptionToken)]
        print("Adapted - Token set to the header field is: \(CredentialHelper.instance.getDeviceRegistration().data.subscriptionToken)")
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
        let authRequest = DeviceAuthenticationRequestDto()
        
        self.alamofireSession.request(ConstantsUtil.deviceAuthenticationUrl,
                                      method: .post,
                                      parameters: authRequest,
                                      encoder: JSONParameterEncoder.default,
                                      headers: [HTTPHeader(name: "apikey", value: ConstantsUtil.deviceRegistrationApiKey),])
            .validate()
            .responseDecodable(of: DeviceAuthenticationResultDto.self) { response in
                switch response.result {
                case .success(let apiResponse):
                    var deviceRegistration = CredentialHelper.instance.getDeviceRegistration()
                    
                    deviceRegistration.sessionId = apiResponse.authenticationKey
                    deviceRegistration.physicalDevice.authenticationKey = apiResponse.authenticationKey
                    deviceRegistration.data = apiResponse.data
                    deviceRegistration.sessionSummary.firstName = apiResponse.subscriber.firstName
                    deviceRegistration.sessionSummary.lastName = apiResponse.subscriber.lastName
                    deviceRegistration.sessionSummary.homeCountry = apiResponse.subscriber.homeCountry
                    deviceRegistration.sessionSummary.subscriberId = apiResponse.subscriber.id
                    deviceRegistration.sessionSummary.email = apiResponse.subscriber.email
                    deviceRegistration.sessionSummary.login = apiResponse.subscriber.login
                    
                    CredentialHelper.instance.setDeviceRegistration(deviceRegistration: deviceRegistration)
                    completion(true)
                    
                case .failure(let afError):
                    self.handleAFError(afError: afError)
                    completion(false)
                }
            }
    }
    
    func loadFairPlayCertificate() {
        self.alamofireSession.request("\(ConstantsUtil.apiUrl)/fairplay01.der",
                                      method: .get)
        .validate()
        .responseData() { certificateResponse in
            switch certificateResponse.result {
            case .success(let certificateData):
                self.fairPlayCertificate = certificateData
                
            case .failure(let afError):
                self.handleAFError(afError: afError)
            }
        }
    }
    
    func getFairPlayLease(fairPlayRequestUrl: String, fairPlayRequestData: Data, assetId: String, completion: @escaping (Data?, Error?) -> ()) {
        var request = URLRequest(url: URL(string: fairPlayRequestUrl)!)
        request.httpMethod = "POST"
        request.httpBody = "spc=\(fairPlayRequestData.base64EncodedString())&assetId=\(assetId)".data(using: .utf8)
        request.headers = [HTTPHeader(name: "entitlementtoken", value: CredentialHelper.instance.getDeviceRegistration().sessionId), HTTPHeader(name: "ascendontoken", value: CredentialHelper.instance.getDeviceRegistration().data.subscriptionToken)]
        
        self.alamofireSession.request(request)
            .validate()
            .responseData() { ckcResponse in
                switch ckcResponse.result {
                case .success(let ckcData):
                    completion(ckcData, nil)
                    
                case .failure(let afError):
                    self.handleAFError(afError: afError)
                    completion(nil, afError)
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

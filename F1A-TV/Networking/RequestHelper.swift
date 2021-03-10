//
//  RequestHelper.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation

class RequestHelper {
    class func createRequestWithoutAuthentication(restService: String, method: String) -> URLRequest {
        if (method != "GET" && method != "PUT" && method != "POST") {
            NSException(name: NSExceptionName(rawValue: "RESTException"), reason: "Invalid REST method.", userInfo: nil).raise()
        }
        
        let baseAddress = ConstantsUtil.apiUrl
        let address = String(format: "%@%@", baseAddress, restService)
        let url = URL(string: address)
        var req = URLRequest(url: url!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("en", forHTTPHeaderField: "Accept-Language")
        req.timeoutInterval = TimeInterval(300)
        return req
    }
    
    class func createCustomRequest(url: String, method: String) -> URLRequest {
        if (method != "GET" && method != "PUT" && method != "POST") {
            NSException(name: NSExceptionName(rawValue: "RESTException"), reason: "Invalid REST method.", userInfo: nil).raise()
        }
        
        let address = String(format: "%@", url)
        let url = URL(string: address)
        var req = URLRequest(url: url!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("en", forHTTPHeaderField: "Accept-Language")
        req.timeoutInterval = TimeInterval(300)
        return req
    }
    
    class func createRequestWithAuthentication(restService: String, method: String) -> URLRequest {
        var req = self.createRequestWithoutAuthentication(restService: restService, method: method)
        req = addJWTAuthentication(request: req, token: CredentialHelper.getJWTToken())
        return req
    }
    
    class func addJWTAuthentication(request: URLRequest, token: String) -> URLRequest {
        var req = request
        req.setValue("JWT " + token, forHTTPHeaderField: "Authorization")
        return req
    }
}

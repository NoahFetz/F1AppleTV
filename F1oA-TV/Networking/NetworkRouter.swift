//
//  NetworkRouter.swift
//  F1TV
//
//  Created by Noah Fetz on 24.10.20.
//

import Foundation

class NetworkRouter {
    var decoder: JSONDecoder!
    var encoder: JSONEncoder!
    var session: URLSession!
    
    static let instance = NetworkRouter()
    
    init() {
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.session = URLSession(configuration: self.getURLSessionConfiguration())
    }
    
    /*func getDateFormatter() -> DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        return df
    }*/

    
    func getURLSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = true
        return configuration
    }
    
    func handleFailure(error: APIError) {
        print("Error occured: \(error.localizedDescription)")
        /*DispatchQueue.main.async {
            switch error {
            case .authenticationError:
                UserInteractionHelper.instance.showError(message: NSLocalizedString("credentials_invalid", comment: ""))
            default:
                UserInteractionHelper.instance.showError(message: error.localizedDescription)
            }
        }*/
    }
    
    func authRequest(authRequest: AuthRequestDto, completion: @escaping(Result<AuthResultDto, APIError>) -> Void) {
        var request = RequestHelper.createCustomRequest(url: ConstantsUtil.authenticateUrl, method: "POST")
        request.setValue(ConstantsUtil.apiKey, forHTTPHeaderField: "apikey")
        
        do{
            let data = try self.encoder.encode(authRequest)
            print(String(data: data, encoding: .utf8)!)
            
            request.httpBody = data
        }catch{
            print("Error occured while encoding")
            completion(.failure(.encodingError))
        }
        
        let task = self.session.dataTask(with: request, completionHandler: {
            data, response, error in
            if(error != nil) {
                completion(.failure(.otherError))
                return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print(response!)
                if(httpStatus.statusCode == 401) {
                    completion(.failure(.authenticationError))
                    return
                }
                completion(.failure(.responseError))
                return
            }
            let requestResult: AuthResultDto
            do {
//                print(String(data: data!,encoding: .utf8)!)
                requestResult = try self.decoder.decode(AuthResultDto.self, from: data!)
                completion(.success(requestResult))
            } catch {
                completion(.failure(.decodingError))
                return
            }
        })
        task.resume()
    }
    
    func tokenRequest(tokenRequest: TokenRequestDto, completion: @escaping(Result<TokenResultDto, APIError>) -> Void) {
        var request = RequestHelper.createCustomRequest(url: ConstantsUtil.tokenUrl, method: "POST")
        
        do{
            let data = try self.encoder.encode(tokenRequest)
            print(String(data: data, encoding: .utf8)!)
            
            request.httpBody = data
        }catch{
            print("Error occured while encoding")
            completion(.failure(.encodingError))
        }
        
        let task = self.session.dataTask(with: request, completionHandler: {
            data, response, error in
            if(error != nil) {
                completion(.failure(.otherError))
                return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 201 {
                print("statusCode should be 201, but is \(httpStatus.statusCode)")
                print(response!)
                if(httpStatus.statusCode == 401) {
                    completion(.failure(.authenticationError))
                    return
                }
                completion(.failure(.responseError))
                return
            }
            let requestResult: TokenResultDto
            do {
//                print(String(data: data!,encoding: .utf8)!)
                requestResult = try self.decoder.decode(TokenResultDto.self, from: data!)
                completion(.success(requestResult))
            } catch {
                completion(.failure(.decodingError))
                return
            }
        })
        task.resume()
    }
    
    func getSeasonLookup(completion: @escaping(Result<SeasonRequestResult, APIError>) -> Void) {
        let request = RequestHelper.createRequestWithoutAuthentication(restService: "/api/race-season", method: "GET")
        
        let task = self.session.dataTask(with: request, completionHandler: {
            data, response, error in
            if(error != nil) {
                completion(.failure(.otherError))
                return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print(response!)
                if(httpStatus.statusCode == 401) {
                    completion(.failure(.authenticationError))
                    return
                }
                completion(.failure(.responseError))
                return
            }
            let requestResult: SeasonRequestResult
            do {
//                print(String(data: data!,encoding: .utf8)!)
                requestResult = try self.decoder.decode(SeasonRequestResult.self, from: data!)
                completion(.success(requestResult))
            } catch {
                completion(.failure(.decodingError))
                return
            }
        })
        task.resume()
    }
    
    func getEventLookup(eventUrl: String, completion: @escaping(Result<EventDto, APIError>) -> Void) {
        let request = RequestHelper.createRequestWithoutAuthentication(restService: eventUrl, method: "GET")
        
        let task = self.session.dataTask(with: request, completionHandler: {
            data, response, error in
            if(error != nil) {
                completion(.failure(.otherError))
                return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print(response!)
                if(httpStatus.statusCode == 401) {
                    completion(.failure(.authenticationError))
                    return
                }
                completion(.failure(.responseError))
                return
            }
            let requestResult: EventDto
            do {
                let localDecoder = JSONDecoder()
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                localDecoder.dateDecodingStrategy = .formatted(df)
                
//                print(String(data: data!,encoding: .utf8)!)
                requestResult = try localDecoder.decode(EventDto.self, from: data!)
                completion(.success(requestResult))
            } catch {
                completion(.failure(.decodingError))
                return
            }
        })
        task.resume()
    }
    
    func getImageLookup(imageUrl: String, completion: @escaping(Result<ImageDto, APIError>) -> Void) {
        let request = RequestHelper.createRequestWithoutAuthentication(restService: imageUrl, method: "GET")
        
        let task = self.session.dataTask(with: request, completionHandler: {
            data, response, error in
            if(error != nil) {
                completion(.failure(.otherError))
                return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print(response!)
                if(httpStatus.statusCode == 401) {
                    completion(.failure(.authenticationError))
                    return
                }
                completion(.failure(.responseError))
                return
            }
            let requestResult: ImageDto
            do {
//                print(String(data: data!,encoding: .utf8)!)
                requestResult = try self.decoder.decode(ImageDto.self, from: data!)
                completion(.success(requestResult))
            } catch {
                completion(.failure(.decodingError))
                return
            }
        })
        task.resume()
    }
    
    func getSessionLookup(sessionUrl: String, completion: @escaping(Result<SessionDto, APIError>) -> Void) {
        let request = RequestHelper.createRequestWithoutAuthentication(restService: sessionUrl, method: "GET")
        
        let task = self.session.dataTask(with: request, completionHandler: {
            data, response, error in
            if(error != nil) {
                completion(.failure(.otherError))
                return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print(response!)
                if(httpStatus.statusCode == 401) {
                    completion(.failure(.authenticationError))
                    return
                }
                completion(.failure(.responseError))
                return
            }
            let requestResult: SessionDto
            do {
                let localDecoder = JSONDecoder()
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                localDecoder.dateDecodingStrategy = .formatted(df)
                
//                print(String(data: data!,encoding: .utf8)!)
                requestResult = try localDecoder.decode(SessionDto.self, from: data!)
                completion(.success(requestResult))
            } catch {
                completion(.failure(.decodingError))
                return
            }
        })
        task.resume()
    }
    
    func getChannelLookup(channelUrl: String, completion: @escaping(Result<ChannelDto, APIError>) -> Void) {
        let request = RequestHelper.createRequestWithoutAuthentication(restService: channelUrl, method: "GET")
        
        let task = self.session.dataTask(with: request, completionHandler: {
            data, response, error in
            if(error != nil) {
                completion(.failure(.otherError))
                return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print(response!)
                if(httpStatus.statusCode == 401) {
                    completion(.failure(.authenticationError))
                    return
                }
                completion(.failure(.responseError))
                return
            }
            let requestResult: ChannelDto
            do {
//                print(String(data: data!,encoding: .utf8)!)
                requestResult = try self.decoder.decode(ChannelDto.self, from: data!)
                completion(.success(requestResult))
            } catch {
                completion(.failure(.decodingError))
                return
            }
        })
        task.resume()
    }
    
    func getDriverLookup(driverUrl: String, completion: @escaping(Result<DriverDto, APIError>) -> Void) {
        let request = RequestHelper.createRequestWithoutAuthentication(restService: driverUrl, method: "GET")
        
        let task = self.session.dataTask(with: request, completionHandler: {
            data, response, error in
            if(error != nil) {
                completion(.failure(.otherError))
                return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print(response!)
                if(httpStatus.statusCode == 401) {
                    completion(.failure(.authenticationError))
                    return
                }
                completion(.failure(.responseError))
                return
            }
            let requestResult: DriverDto
            do {
//                print(String(data: data!,encoding: .utf8)!)
                requestResult = try self.decoder.decode(DriverDto.self, from: data!)
                completion(.success(requestResult))
            } catch {
                completion(.failure(.decodingError))
                return
            }
        })
        task.resume()
    }
    
    func getEpisodeLookup(episodeUrl: String, completion: @escaping(Result<EpisodeDto, APIError>) -> Void) {
        let request = RequestHelper.createRequestWithoutAuthentication(restService: episodeUrl, method: "GET")
        
        let task = self.session.dataTask(with: request, completionHandler: {
            data, response, error in
            if(error != nil) {
                completion(.failure(.otherError))
                return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print(response!)
                if(httpStatus.statusCode == 401) {
                    completion(.failure(.authenticationError))
                    return
                }
                completion(.failure(.responseError))
                return
            }
            let requestResult: EpisodeDto
            do {
//                print(String(data: data!,encoding: .utf8)!)
                requestResult = try self.decoder.decode(EpisodeDto.self, from: data!)
                completion(.success(requestResult))
            } catch {
                completion(.failure(.decodingError))
                return
            }
        })
        task.resume()
    }
    
    func channelStreamTokenRequest(streamTokenRequest: ChannelStreamTokenRequestDto, completion: @escaping(Result<ChannelStreamTokenResultDto, APIError>) -> Void) {
        var request = RequestHelper.createRequestWithAuthentication(restService: "/api/viewings/", method: "POST")
        
        do{
            let data = try self.encoder.encode(streamTokenRequest)
            print(String(data: data, encoding: .utf8)!)
            
            request.httpBody = data
        }catch{
            print("Error occured while encoding")
            completion(.failure(.encodingError))
        }
        
        let task = self.session.dataTask(with: request, completionHandler: {
            data, response, error in
            if(error != nil) {
                completion(.failure(.otherError))
                return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 201 {
                print("statusCode should be 201, but is \(httpStatus.statusCode)")
                print(response!)
                if(httpStatus.statusCode == 401) {
                    completion(.failure(.authenticationError))
                    return
                }
                completion(.failure(.responseError))
                return
            }
            let requestResult: ChannelStreamTokenResultDto
            do {
//                print(String(data: data!,encoding: .utf8)!)
                requestResult = try self.decoder.decode(ChannelStreamTokenResultDto.self, from: data!)
                completion(.success(requestResult))
            } catch {
                completion(.failure(.decodingError))
                return
            }
        })
        task.resume()
    }
    
    func assetStreamTokenRequest(assetTokenRequest: AssetStreamTokenRequestDto, completion: @escaping(Result<AssetStreamTokenResultDto, APIError>) -> Void) {
        var request = RequestHelper.createRequestWithAuthentication(restService: "/api/viewings/", method: "POST")
        
        do{
            let data = try self.encoder.encode(assetTokenRequest)
            print(String(data: data, encoding: .utf8)!)
            
            request.httpBody = data
        }catch{
            print("Error occured while encoding")
            completion(.failure(.encodingError))
        }
        
        let task = self.session.dataTask(with: request, completionHandler: {
            data, response, error in
            if(error != nil) {
                completion(.failure(.otherError))
                return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 201 {
                print("statusCode should be 201, but is \(httpStatus.statusCode)")
                print(response!)
                if(httpStatus.statusCode == 401) {
                    completion(.failure(.authenticationError))
                    return
                }
                completion(.failure(.responseError))
                return
            }
            let requestResult: AssetStreamTokenResultDto
            do {
//                print(String(data: data!,encoding: .utf8)!)
                requestResult = try self.decoder.decode(AssetStreamTokenResultDto.self, from: data!)
                completion(.success(requestResult))
            } catch {
                completion(.failure(.decodingError))
                return
            }
        })
        task.resume()
    }
}

enum APIError: Error {
    case authenticationError
    case responseError
    case decodingError
    case encodingError
    case otherError
}

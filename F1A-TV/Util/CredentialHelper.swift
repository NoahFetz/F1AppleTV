//
//  CredentialHelper.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import Foundation

class CredentialHelper: AuthDataLoadedProtocol {
    static let instance = CredentialHelper()
    
    func performLoginRefresh() {
        if(self.isLoginInformationCached()) {
            DataManager.instance.loadAuthData(authRequest: AuthRequestDto(login: self.getUserInfo().subscriber.email, password: self.getPassword()), authDataLoadedProtocol: self)
        }
    }
    
    func isLoginInformationCached() -> Bool {
        return !self.getUserInfo().sessionId.isEmpty
    }
    
    func setJWTToken(jwtToken: String) {
        DataSource.instance.addKeyValue(keyValuePair: KeyValueStoreObject(id: UUID().uuidString.lowercased(), key: ConstantsUtil.jwtTokenKeyValueStorageKey, value: jwtToken))
    }
    
    func getJWTToken() -> String {
        let object = DataSource.instance.getKeyValuePair(keyString: ConstantsUtil.jwtTokenKeyValueStorageKey)
        if(object.key != ConstantsUtil.jwtTokenKeyValueStorageKey){
            self.setJWTToken(jwtToken: "")
            return self.getJWTToken()
        }
        return object.value
    }
    
    func setPassword(password: String) {
        DataSource.instance.addKeyValue(keyValuePair: KeyValueStoreObject(id: UUID().uuidString.lowercased(), key: ConstantsUtil.passwordKeyValueStorageKey, value: password))
    }
    
    func getPassword() -> String {
        let object = DataSource.instance.getKeyValuePair(keyString: ConstantsUtil.passwordKeyValueStorageKey)
        if(object.key != ConstantsUtil.passwordKeyValueStorageKey){
            self.setPassword(password: "")
            return self.getPassword()
        }
        return object.value
    }
    
    func getUserInfo() -> AuthResultDto {
        let object = DataSource.instance.getKeyValuePair(keyString: ConstantsUtil.userInfoKeyValueStorageKey)
        if(object.key != ConstantsUtil.userInfoKeyValueStorageKey){
            self.setUserInfo(userInfo: AuthResultDto())
            return self.getUserInfo()
        }
        let decoder = JSONDecoder()
//        print(object.value)
        do {
            return try decoder.decode(AuthResultDto.self, from: object.value.data(using: .utf8)!)
        }catch{
            return AuthResultDto()
        }
    }
    
    func setUserInfo(userInfo: AuthResultDto) {
        var dataString = ""
        do{
            let encoder = JSONEncoder()
            let data = try encoder.encode(userInfo)
            dataString = String(data: data, encoding: .utf8) ?? ""
//            print(dataString)
        }catch{
            print("Encoding failed")
            return
        }
        DataSource.instance.addKeyValue(keyValuePair: KeyValueStoreObject(id: UUID().uuidString.lowercased(), key: ConstantsUtil.userInfoKeyValueStorageKey, value: dataString))
    }
    
    class func getPlayerSettings() -> PlayerSettings {
        let object = DataSource.instance.getKeyValuePair(keyString: ConstantsUtil.playerSettingsKeyValueStorageKey)
        if(object.key != ConstantsUtil.playerSettingsKeyValueStorageKey){
            self.setPlayerSettings(playerSettings: PlayerSettings())
            return self.getPlayerSettings()
        }
        let decoder = JSONDecoder()
//        print(object.value)
        do {
            return try decoder.decode(PlayerSettings.self, from: object.value.data(using: .utf8)!)
        }catch{
            return PlayerSettings()
        }
    }
    
    class func setPlayerSettings(playerSettings: PlayerSettings) {
        var dataString = ""
        do{
            let encoder = JSONEncoder()
            let data = try encoder.encode(playerSettings)
            dataString = String(data: data, encoding: .utf8) ?? ""
//            print(dataString)
        }catch{
            print("Encoding failed")
            return
        }
        DataSource.instance.addKeyValue(keyValuePair: KeyValueStoreObject(id: UUID().uuidString.lowercased(), key: ConstantsUtil.playerSettingsKeyValueStorageKey, value: dataString))
    }
    
    func performAuthRequest(authRequest: AuthRequestDto) {
        DataManager.instance.loadAuthData(authRequest: authRequest, authDataLoadedProtocol: self)
    }
    
    func didLoadAuthData(authResult: AuthResultDto) {
        let tokenRequest = TokenRequestDto(accessToken: authResult.authData.subscriptionToken, identityProviderUrl: ConstantsUtil.identityProvider)
        CredentialHelper.instance.setUserInfo(userInfo: authResult)
        
        DataManager.instance.loadTokenRequest(tokenRequest: tokenRequest, authDataLoadedProtocol: self)
    }
    
    func didLoadToken(tokenResult: TokenResultDto) {
        CredentialHelper.instance.setJWTToken(jwtToken: tokenResult.token)
    }
}

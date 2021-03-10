//
//  CredentialHelper.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import Foundation

class CredentialHelper {
    static let instance = CredentialHelper()
    
    class func isLoginInformationCached() -> Bool {
        return !self.getUserInfo().sessionId.isEmpty
    }
    
    class func setJWTToken(jwtToken: String) {
        DataSource.instance.addKeyValue(keyValuePair: KeyValueStoreObject(id: UUID().uuidString.lowercased(), key: ConstantsUtil.jwtTokenKeyValueStorageKey, value: jwtToken))
    }
    
    class func getJWTToken() -> String {
        let object = DataSource.instance.getKeyValuePair(keyString: ConstantsUtil.jwtTokenKeyValueStorageKey)
        if(object.key != ConstantsUtil.jwtTokenKeyValueStorageKey){
            self.setJWTToken(jwtToken: "")
            return self.getJWTToken()
        }
        return object.value
    }
    
    class func setPassword(password: String) {
        DataSource.instance.addKeyValue(keyValuePair: KeyValueStoreObject(id: UUID().uuidString.lowercased(), key: ConstantsUtil.passwordKeyValueStorageKey, value: password))
    }
    
    class func getPassword() -> String {
        let object = DataSource.instance.getKeyValuePair(keyString: ConstantsUtil.passwordKeyValueStorageKey)
        if(object.key != ConstantsUtil.passwordKeyValueStorageKey){
            self.setPassword(password: "")
            return self.getPassword()
        }
        return object.value
    }
    
    class func getUserInfo() -> AuthResultDto {
        let object = DataSource.instance.getKeyValuePair(keyString: ConstantsUtil.userInfoKeyValueStorageKey)
        if(object.key != ConstantsUtil.userInfoKeyValueStorageKey){
            self.setUserInfo(userInfo: AuthResultDto())
            return self.getUserInfo()
        }
        let decoder = JSONDecoder()
        print(object.value)
        do {
            return try decoder.decode(AuthResultDto.self, from: object.value.data(using: .utf8)!)
        }catch{
            return AuthResultDto()
        }
    }
    
    class func setUserInfo(userInfo: AuthResultDto) {
        var dataString = ""
        do{
            let encoder = JSONEncoder()
            let data = try encoder.encode(userInfo)
            dataString = String(data: data, encoding: .utf8) ?? ""
            print(dataString)
        }catch{
            print("Encoding failed")
            return
        }
        DataSource.instance.addKeyValue(keyValuePair: KeyValueStoreObject(id: UUID().uuidString.lowercased(), key: ConstantsUtil.userInfoKeyValueStorageKey, value: dataString))
    }
}

import Foundation
import CoreFoundation

// Deterministic substitutes for Security and CoreData. No real credentials are used.
typealias OSStatus = Int32
let errSecSuccess: OSStatus = 0
let errSecItemNotFound: OSStatus = -25300
let errSecDuplicateItem: OSStatus = -25299
let errSecDecode: OSStatus = -26275
let storageFailure: OSStatus = -25291
let kSecClass = "class"
let kSecClassGenericPassword = "generic"
let kSecAttrService = "service"
let kSecAttrAccount = "account"
let kSecValueData = "data"
let kSecAttrAccessible = "accessible"
let kSecAttrAccessibleWhenUnlockedThisDeviceOnly = "unlocked-device-only"
let kSecReturnData = "return-data"
let kSecMatchLimit = "limit"
let kSecMatchLimitOne = "one"

enum FakeSecurity {
    static var items: [String: Data] = [:]
    static var failUpdate = false
    static var failAdd = false
    static var failRead = false
    static var failDelete = false
    static var insertDuringAdd = false
    static var deleteCount = 0
    static func reset() {
        items = [:]
        failUpdate = false; failAdd = false; failRead = false; failDelete = false
        insertDuringAdd = false; deleteCount = 0
    }
}
func account(_ query: CFDictionary) -> String {
    return (query as NSDictionary)[kSecAttrAccount] as! String
}
func SecItemUpdate(_ query: CFDictionary, _ attributes: CFDictionary) -> OSStatus {
    if FakeSecurity.failUpdate { return storageFailure }
    let key = account(query)
    guard FakeSecurity.items[key] != nil else { return errSecItemNotFound }
    FakeSecurity.items[key] = (attributes as NSDictionary)[kSecValueData] as? Data
    return errSecSuccess
}
func SecItemAdd(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
    if FakeSecurity.failAdd { return storageFailure }
    let key = account(query)
    if FakeSecurity.insertDuringAdd {
        FakeSecurity.insertDuringAdd = false
        FakeSecurity.items[key] = Data("concurrent insert".utf8)
    }
    if FakeSecurity.items[key] != nil { return errSecDuplicateItem }
    FakeSecurity.items[key] = (query as NSDictionary)[kSecValueData] as? Data
    return errSecSuccess
}
func SecItemCopyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<AnyObject?>) -> OSStatus {
    if FakeSecurity.failRead { return storageFailure }
    guard let data = FakeSecurity.items[account(query)] else { return errSecItemNotFound }
    result.pointee = data as NSData
    return errSecSuccess
}
func SecItemDelete(_ query: CFDictionary) -> OSStatus {
    FakeSecurity.deleteCount += 1
    if FakeSecurity.failDelete { return storageFailure }
    if let key = (query as NSDictionary)[kSecAttrAccount] as? String {
        FakeSecurity.items.removeValue(forKey: key)
    } else {
        FakeSecurity.items.removeAll()
    }
    return errSecSuccess
}

struct DeviceRegistrationResultDto: Codable { var sessionId = "" }
struct PlayerSettings: Codable {}
struct KeyValueStoreObject {
    var id = ""
    var key = ""
    var value = ""
}
enum ConstantsUtil {
    static let passwordKeyValueStorageKey = "old-password"
    static let deviceRegistrationKeyValueStorageKey = "old-registration"
    static let playerSettingsKeyValueStorageKey = "player-settings"
    static let keychainPasswordKey = "password"
    static let keychainDeviceRegistrationKey = "registration"
}
enum StorageTestError: Error { case failure }
final class DataSource {
    static let instance = DataSource()
    var values: [String: String] = [:]
    var failClear = false
    func getKeyValuePair(keyString: String) -> KeyValueStoreObject {
        guard let value = values[keyString] else { return KeyValueStoreObject() }
        return KeyValueStoreObject(id: "test", key: keyString, value: value)
    }
    func addKeyValue(keyValuePair: KeyValueStoreObject) { values[keyValuePair.key] = keyValuePair.value }
    func clearCredentialValues(keys: [String]) throws {
        if failClear { throw StorageTestError.failure }
        for key in keys where values[key] != nil { values[key] = "" }
    }
}

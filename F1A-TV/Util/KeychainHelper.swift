//
//  KeychainHelper.swift
//  F1TV
//
//  Created by Rob Mulder on 12.03.26.
//

import Foundation
import Security

enum KeychainError: Error, CustomNSError {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case readFailed(OSStatus)
    case encodingFailed
    static var errorDomain: String { NSOSStatusErrorDomain }
    var errorCode: Int {
        switch self {
        case .saveFailed(let status), .deleteFailed(let status), .readFailed(let status): return Int(status)
        case .encodingFailed: return Int(errSecDecode)
        }
    }
    var errorUserInfo: [String: Any] { [:] }

}

struct KeychainHelper {
    private static let service = "com.f1atv.credentials"

    // MARK: - String operations

    static func saveString(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try saveData(data, forKey: key)
    }

    static func readString(forKey key: String) throws -> String? {
        guard let data = try readData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Codable operations

    static func saveCodable<T: Encodable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        try saveData(data, forKey: key)
    }

    static func readCodable<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = try readData(forKey: key) else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    // MARK: - Delete operations

    static func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    static func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    // MARK: - Private

    private static func saveData(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            // Another caller may have inserted the item after our update attempt.
            if addStatus == errSecDuplicateItem {
                let retryStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
                guard retryStatus == errSecSuccess else {
                    throw KeychainError.saveFailed(retryStatus)
                }
            } else if addStatus != errSecSuccess {
                throw KeychainError.saveFailed(addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.saveFailed(status)
        }
    }

    private static func readData(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.readFailed(status) }
        guard let data = result as? Data else { throw KeychainError.readFailed(errSecDecode) }
        return data
    }
}

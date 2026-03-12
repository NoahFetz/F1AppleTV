//
//  CredentialHelper.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import Foundation

class CredentialHelper {
    static let instance = CredentialHelper()

    private init() {
        migrateFromCoreDataIfNeeded()
    }

    func isLoginInformationCached() -> Bool {
        return !self.getDeviceRegistration().sessionId.isEmpty
    }

    // MARK: - Password (Keychain)

    func setPassword(password: String) {
        try? KeychainHelper.saveString(password, forKey: ConstantsUtil.keychainPasswordKey)
    }

    func getPassword() -> String {
        return KeychainHelper.readString(forKey: ConstantsUtil.keychainPasswordKey) ?? ""
    }

    // MARK: - Device Registration (Keychain)

    func getDeviceRegistration() -> DeviceRegistrationResultDto {
        return KeychainHelper.readCodable(DeviceRegistrationResultDto.self, forKey: ConstantsUtil.keychainDeviceRegistrationKey) ?? DeviceRegistrationResultDto()
    }

    func setDeviceRegistration(deviceRegistration: DeviceRegistrationResultDto) {
        try? KeychainHelper.saveCodable(deviceRegistration, forKey: ConstantsUtil.keychainDeviceRegistrationKey)
    }

    // MARK: - Player Settings (CoreData — not sensitive)

    class func getPlayerSettings() -> PlayerSettings {
        let object = DataSource.instance.getKeyValuePair(keyString: ConstantsUtil.playerSettingsKeyValueStorageKey)
        if object.key != ConstantsUtil.playerSettingsKeyValueStorageKey {
            self.setPlayerSettings(playerSettings: PlayerSettings())
            return PlayerSettings()
        }
        guard let data = object.value.data(using: .utf8) else {
            return PlayerSettings()
        }
        do {
            return try JSONDecoder().decode(PlayerSettings.self, from: data)
        } catch {
            return PlayerSettings()
        }
    }

    class func setPlayerSettings(playerSettings: PlayerSettings) {
        do {
            let data = try JSONEncoder().encode(playerSettings)
            let dataString = String(data: data, encoding: .utf8) ?? ""
            DataSource.instance.addKeyValue(keyValuePair: KeyValueStoreObject(id: UUID().uuidString.lowercased(), key: ConstantsUtil.playerSettingsKeyValueStorageKey, value: dataString))
        } catch {
            print("Encoding failed")
        }
    }

    // MARK: - Logout

    func clearCredentials() {
        try? KeychainHelper.deleteAll()
    }

    // MARK: - One-time migration from CoreData to Keychain

    private func migrateFromCoreDataIfNeeded() {
        let passwordObject = DataSource.instance.getKeyValuePair(keyString: ConstantsUtil.passwordKeyValueStorageKey)
        if passwordObject.key == ConstantsUtil.passwordKeyValueStorageKey, !passwordObject.value.isEmpty {
            try? KeychainHelper.saveString(passwordObject.value, forKey: ConstantsUtil.keychainPasswordKey)
            DataSource.instance.addKeyValue(keyValuePair: KeyValueStoreObject(id: UUID().uuidString.lowercased(), key: ConstantsUtil.passwordKeyValueStorageKey, value: ""))
        }

        let regObject = DataSource.instance.getKeyValuePair(keyString: ConstantsUtil.deviceRegistrationKeyValueStorageKey)
        if regObject.key == ConstantsUtil.deviceRegistrationKeyValueStorageKey, !regObject.value.isEmpty {
            if let data = regObject.value.data(using: .utf8),
               let registration = try? JSONDecoder().decode(DeviceRegistrationResultDto.self, from: data) {
                try? KeychainHelper.saveCodable(registration, forKey: ConstantsUtil.keychainDeviceRegistrationKey)
                DataSource.instance.addKeyValue(keyValuePair: KeyValueStoreObject(id: UUID().uuidString.lowercased(), key: ConstantsUtil.deviceRegistrationKeyValueStorageKey, value: ""))
            }
        }
    }
}

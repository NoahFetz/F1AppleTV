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
        do {
            try migrateFromCoreDataIfNeeded()
        } catch {
            // Keep legacy values intact. The session storage adapter retries migration
            // and delivers its final failure to the owning account operation.
        }
    }

    func isLoginInformationCached() -> Bool {
        return !self.getDeviceRegistration().sessionId.isEmpty
    }

    // MARK: - Password (Keychain)

    func setPassword(password: String) throws {
        try KeychainHelper.saveString(password, forKey: ConstantsUtil.keychainPasswordKey)
    }

    func getPassword() -> String {
        do { return try KeychainHelper.readString(forKey: ConstantsUtil.keychainPasswordKey) ?? "" }
        catch { AppErrorStore.shared.record(error, operation: .credentials); return "" }
    }

    // MARK: - Device Registration (Keychain)

    func getDeviceRegistration() -> DeviceRegistrationResultDto {
        do { return try KeychainHelper.readCodable(DeviceRegistrationResultDto.self, forKey: ConstantsUtil.keychainDeviceRegistrationKey) ?? DeviceRegistrationResultDto() }
        catch { AppErrorStore.shared.record(error, operation: .credentials); return DeviceRegistrationResultDto() }
    }

    func setDeviceRegistration(deviceRegistration: DeviceRegistrationResultDto) throws {
        try KeychainHelper.saveCodable(deviceRegistration, forKey: ConstantsUtil.keychainDeviceRegistrationKey)
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

    func clearCredentials() throws {
        // Remove any legacy leftovers first, or next launch could migrate them back.
        try DataSource.instance.clearCredentialValues(keys: [
            ConstantsUtil.passwordKeyValueStorageKey,
            ConstantsUtil.deviceRegistrationKeyValueStorageKey
        ])
        try KeychainHelper.deleteAll()
    }

    // MARK: - One-time migration from CoreData to Keychain

    // Internal for regression tests; production invokes this during initialization.
    func migrateFromCoreDataIfNeeded() throws {
        let passwordObject = DataSource.instance.getKeyValuePair(keyString: ConstantsUtil.passwordKeyValueStorageKey)
        if passwordObject.key == ConstantsUtil.passwordKeyValueStorageKey, !passwordObject.value.isEmpty {
            // A previous run may have saved successfully but failed to clear CoreData.
            if try KeychainHelper.readString(forKey: ConstantsUtil.keychainPasswordKey) == nil {
                try KeychainHelper.saveString(passwordObject.value, forKey: ConstantsUtil.keychainPasswordKey)
            }
            try DataSource.instance.clearCredentialValues(keys: [ConstantsUtil.passwordKeyValueStorageKey])
        }

        let regObject = DataSource.instance.getKeyValuePair(keyString: ConstantsUtil.deviceRegistrationKeyValueStorageKey)
        if regObject.key == ConstantsUtil.deviceRegistrationKeyValueStorageKey, !regObject.value.isEmpty {
            if try KeychainHelper.readCodable(DeviceRegistrationResultDto.self, forKey: ConstantsUtil.keychainDeviceRegistrationKey) == nil {
                let registration = try JSONDecoder().decode(DeviceRegistrationResultDto.self, from: Data(regObject.value.utf8))
                try KeychainHelper.saveCodable(registration, forKey: ConstantsUtil.keychainDeviceRegistrationKey)
            }
            try DataSource.instance.clearCredentialValues(keys: [ConstantsUtil.deviceRegistrationKeyValueStorageKey])
        }
    }
}

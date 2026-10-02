import Foundation

/// Existing storage keys and registration encoding remain unchanged.
@MainActor
final class KeychainSessionStore: SessionCredentialStore {
    init() { _ = CredentialHelper.instance }
    func load() async throws -> DeviceRegistrationResultDto? {
        try CredentialHelper.instance.migrateFromCoreDataIfNeeded()
        return try KeychainHelper.readCodable(DeviceRegistrationResultDto.self, forKey: ConstantsUtil.keychainDeviceRegistrationKey)
    }
    func save(_ registration: DeviceRegistrationResultDto) async throws {
        try KeychainHelper.saveCodable(registration, forKey: ConstantsUtil.keychainDeviceRegistrationKey)
    }
    func clear() async throws { try CredentialHelper.instance.clearCredentials() }
}


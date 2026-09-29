import Foundation

func expect(_ message: String, _ condition: @autoclosure () throws -> Bool) throws {
    guard try condition() else { fatalError(message) }
}
func expectFailure(_ operation: () throws -> Void) {
    do { try operation() } catch { return }
    fatalError("Expected a storage error to reach the caller")
}
let credentials = CredentialHelper.instance
let legacy = DataSource.instance
let oldPassword = ConstantsUtil.passwordKeyValueStorageKey
let oldRegistration = ConstantsUtil.deviceRegistrationKeyValueStorageKey
let password = ConstantsUtil.keychainPasswordKey
let registration = ConstantsUtil.keychainDeviceRegistrationKey
func reset() { FakeSecurity.reset(); legacy.values = [:]; legacy.failClear = false }
func seedLegacy() {
    legacy.values[oldPassword] = "old-secret"
    legacy.values[oldRegistration] = "{\"sessionId\":\"old-session\"}"
}

reset(); seedLegacy()
try credentials.migrateFromCoreDataIfNeeded()
try expect("Password must migrate", credentials.getPassword() == "old-secret")
try expect("Session must migrate", credentials.getDeviceRegistration().sessionId == "old-session")
try expect("Legacy values must be cleared", legacy.values[oldPassword] == "" && legacy.values[oldRegistration] == "")
print("PASS: successful migration")

reset(); seedLegacy(); FakeSecurity.failAdd = true
expectFailure { try credentials.migrateFromCoreDataIfNeeded() }
try expect("Failed migration must preserve legacy password", legacy.values[oldPassword] == "old-secret")
try expect("Failed migration must preserve legacy registration", legacy.values[oldRegistration] != "")
FakeSecurity.failAdd = false
try credentials.migrateFromCoreDataIfNeeded()
try expect("Migration must be retryable", credentials.getDeviceRegistration().sessionId == "old-session")
print("PASS: failed write preserves migration source and permits retry")

reset(); seedLegacy(); legacy.values[oldPassword] = ""
FakeSecurity.failAdd = true
expectFailure { try credentials.migrateFromCoreDataIfNeeded() }
try expect("Registration write failure must retain its source", legacy.values[oldRegistration] != "")
print("PASS: registration migration failure")

reset(); seedLegacy(); legacy.failClear = true
expectFailure { try credentials.migrateFromCoreDataIfNeeded() }
try credentials.setPassword(password: "new-secret")
try credentials.setDeviceRegistration(deviceRegistration: DeviceRegistrationResultDto(sessionId: "new-session"))
legacy.failClear = false
try credentials.migrateFromCoreDataIfNeeded()
try expect("Stale CoreData must not replace newer Keychain password", credentials.getPassword() == "new-secret")
try expect("Stale CoreData must not replace newer Keychain session", credentials.getDeviceRegistration().sessionId == "new-session")
print("PASS: cleanup failure and retry preserve newer credentials")

reset(); seedLegacy(); FakeSecurity.failRead = true
expectFailure { try credentials.migrateFromCoreDataIfNeeded() }
try expect("Read failure must not trigger an overwrite", FakeSecurity.items.isEmpty)
try expect("Read failure must preserve source", legacy.values[oldPassword] == "old-secret")
print("PASS: unavailable Keychain is not treated as missing")

reset(); legacy.values[oldRegistration] = "invalid JSON"
expectFailure { try credentials.migrateFromCoreDataIfNeeded() }
try expect("Invalid migration data must not be erased", legacy.values[oldRegistration] == "invalid JSON")
print("PASS: malformed migration data retained")

reset()
try credentials.setDeviceRegistration(deviceRegistration: DeviceRegistrationResultDto(sessionId: "original"))
FakeSecurity.failUpdate = true
expectFailure { try credentials.setDeviceRegistration(deviceRegistration: DeviceRegistrationResultDto(sessionId: "replacement")) }
FakeSecurity.failUpdate = false
try expect("Failed update must preserve existing registration", credentials.getDeviceRegistration().sessionId == "original")
try expect("Saving must never delete the current item", FakeSecurity.deleteCount == 0)
print("PASS: failed update preserves existing credentials and reports failure")

reset(); FakeSecurity.insertDuringAdd = true
try credentials.setPassword(password: "winner")
try expect("Concurrent insert must be handled by updating", credentials.getPassword() == "winner")
print("PASS: insert race")

reset(); seedLegacy()
try credentials.setPassword(password: "new-secret")
legacy.failClear = true
expectFailure { try credentials.clearCredentials() }
try expect("Failed legacy cleanup must not pretend logout succeeded", credentials.getPassword() == "new-secret")
legacy.failClear = false; FakeSecurity.failDelete = true
expectFailure { try credentials.clearCredentials() }
try expect("Deletion error must retain item", credentials.getPassword() == "new-secret")
FakeSecurity.failDelete = false
try credentials.clearCredentials()
try credentials.migrateFromCoreDataIfNeeded()
try expect("Logout must not resurrect legacy data", credentials.getPassword().isEmpty && !credentials.isLoginInformationCached())
print("PASS: logout errors propagate; retry removes legacy and Keychain credentials")
print("All credential regression tests passed.")

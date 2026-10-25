import XCTest
@testable import F1Core

final class AccountLocalizationTests: XCTestCase {
    func testSubscriptionStatesUseDisplayTranslationsWithoutChangingEntitlements() {
        for (value, key) in [("active", "active"), ("inactive", "inactive"), ("expired", "expired"),
                             ("suspended", "suspended"), ("cancelled", "cancelled"), ("canceled", "cancelled"),
                             ("ACTIVE", "active"), ("", "unknown"), ("future-server-value", "unknown")] {
            let profile = AccountProfile(firstName: "", lastName: "", email: "", country: "", subscriberID: 1, subscriptionStatus: value)
            XCTAssertEqual(profile.localizedSubscriptionStatus, CoreLocalization.string("account_status_" + key))
            XCTAssertEqual(profile.hasSubscription, value == "active")
            XCTAssertFalse(profile.localizedSubscriptionStatus.hasPrefix("account_status_"))
        }
    }
    func testLoginMessagesAndCountryNamesUseTheSharedResourceLanguage() {
        for key in ["oauth_login_button", "oauth_login_loading", "oauth_login_finishing", "oauth_login_completing", "oauth_login_failed",
                    "oauth_login_page_failed", "account_storage_failed", "account_sign_out_failed", "account_renewal_sign_in_prompt"] {
            XCTAssertNotEqual(CoreLocalization.string(key), key)
            XCTAssertFalse(CoreLocalization.string(key).isEmpty)
        }
        XCTAssertTrue(["en", "de", "es", "fr", "nl", "pt-PT"].contains(CoreLocalization.locale.identifier))
        XCTAssertNotNil(CoreLocalization.locale.localizedString(forRegionCode: "CH"))
    }
}

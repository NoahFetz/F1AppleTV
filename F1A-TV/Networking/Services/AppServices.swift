#if canImport(F1Core)
import F1Core
#endif
import UIKit

/// Created once per scene and passed to controllers before their views load.
@MainActor
final class AppServices {
    let catalog: any CatalogService
    let auth: any AuthService
    let playback: any PlaybackService
    let fairPlay: any FairPlayService
    let language: String
    let playerController: PlayerController
    init(catalog: any CatalogService, auth: any AuthService, playback: any PlaybackService, fairPlay: any FairPlayService, language: String, playerController: PlayerController? = nil) {
        self.catalog = catalog; self.auth = auth; self.playback = playback; self.fairPlay = fairPlay; self.language = language
        self.playerController = playerController ?? PlayerController()
    }
    func page(uri: String, destination: ContentItem? = nil) -> PageOverviewCollectionViewController {
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: ConstantsUtil.pageOverviewCollectionViewController) as! PageOverviewCollectionViewController
        controller.services = self
        if let destination { controller.initialize(pageUri: uri, destination: destination) }
        else { controller.initialize(pageUri: uri) }
        return controller
    }
    func accountController() -> AccountOverviewViewController {
        let controller = AccountOverviewViewController(); controller.services = self; return controller
    }
    func loginController() -> LoginViewController {
        let controller = LoginViewController(); controller.services = self; return controller
    }
    func viewer(channels: [ContentItem], fromBeginning: Bool, sessionItem: ContentItem? = nil) -> PlayerCollectionViewController {
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: ConstantsUtil.playerCollectionViewController) as! PlayerCollectionViewController
        controller.services = self
        controller.initialize(channelItems: channels, playFromStart: fromBeginning, sessionItem: sessionItem)
        return controller
    }
    static func live() -> AppServices {
        var endpoints = APIEndpoints(); endpoints.language = APILanguageType.fromAPIKey(apiKey: "api_endpoing_language_id".localizedString).getAPIKey()
        let client = APIClient(transport: AlamofireHTTPTransport())
        let legacy = F1AuthService(client: client, endpoints: endpoints, storage: KeychainSessionStore())
        let auth = F1DeviceAuthService(client: client, fallback: legacy, store: KeychainDeviceSessionStore())
        return AppServices(catalog: F1CatalogService(client: client, endpoints: endpoints), auth: auth, playback: F1PlaybackService(endpoints: endpoints, auth: auth), fairPlay: F1FairPlayService(client: client, endpoints: endpoints, auth: auth), language: endpoints.language)
    }
}

/// The phone/TV session is separate from the legacy registration so existing
/// installations can keep playing until they choose to sign out or sign in.
@MainActor
final class KeychainDeviceSessionStore: DeviceSessionCredentialStore {
    private let key = "F1ATV_DeviceCodeSession.v1"
    func load() async throws -> DeviceAccountSession? {
        try KeychainHelper.readCodable(DeviceAccountSession.self, forKey: key)
    }
    func save(_ session: DeviceAccountSession) async throws {
        try KeychainHelper.saveCodable(session, forKey: key)
    }
    func clear() async throws { try KeychainHelper.delete(forKey: key) }
}

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
    init(catalog: any CatalogService, auth: any AuthService, playback: any PlaybackService, fairPlay: any FairPlayService, language: String) {
        self.catalog = catalog; self.auth = auth; self.playback = playback; self.fairPlay = fairPlay; self.language = language
        playerController = PlayerController()
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
    func viewer(channels: [ContentItem], fromBeginning: Bool) -> PlayerCollectionViewController {
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: ConstantsUtil.playerCollectionViewController) as! PlayerCollectionViewController
        controller.services = self
        controller.initialize(channelItems: channels, playFromStart: fromBeginning)
        return controller
    }
    static func live() -> AppServices {
        var endpoints = APIEndpoints(); endpoints.language = APILanguageType.fromAPIKey(apiKey: "api_endpoing_language_id".localizedString).getAPIKey()
        let client = APIClient(transport: AlamofireHTTPTransport())
        let auth = F1AuthService(client: client, endpoints: endpoints, storage: KeychainSessionStore())
        return AppServices(catalog: F1CatalogService(client: client, endpoints: endpoints), auth: auth, playback: F1PlaybackService(endpoints: endpoints, auth: auth), fairPlay: F1FairPlayService(client: client, endpoints: endpoints, auth: auth), language: endpoints.language)
    }
}

/// Keeps the existing hidden-browser challenge mechanism, with ownership and cancellation scoped to Login.
@MainActor
final class BrowserLoginChallengeProvider: LoginChallengeProviding {
    private weak var host: UIView?
    init(host: UIView) { self.host = host }
    func prepare() async throws -> LoginChallenge {
        guard let host, let type = NSClassFromString("UIWebView") as? NSObject.Type else { throw APIError.authentication }
        HTTPCookieStorage.shared.cookies?.filter { $0.domain.contains("formula1.com") && $0.name == "reese84" }.forEach(HTTPCookieStorage.shared.deleteCookie)
        let browser: AnyObject = type.init()
        guard let view = browser as? UIView else { throw APIError.authentication }
        browser.loadRequest(URLRequest(url: URL(string: "https://account.formula1.com/#/login")!))
        view.frame = host.bounds; view.alpha = 0; host.addSubview(view)
        defer { view.removeFromSuperview() }
        for attempt in 0..<11 {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            if attempt == 0 { view.removeFromSuperview() }
            try Task.checkCancellation()
            if let cookie = HTTPCookieStorage.shared.cookies?.first(where: { $0.domain.contains("formula1.com") && $0.name == "reese84" && !$0.value.isEmpty }) {
                return LoginChallenge(cookie.value)
            }
        }
        throw APIError.authentication
    }
}

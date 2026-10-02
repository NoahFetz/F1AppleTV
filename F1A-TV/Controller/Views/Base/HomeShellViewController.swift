import UIKit
import Kingfisher

final class TVActionButton: UIButton {
    var onFocus: ((Bool) -> Void)?
    var accent = ConstantsUtil.brandingRed
    var restingColor = ConstantsUtil.brandingItemColor
    var showsSelection = false { didSet { updateStyle() } }
    func updateStyle() {
        backgroundColor = isFocused ? .white : restingColor
        configuration?.baseForegroundColor = isFocused ? .black : .white
        setTitleColor(isFocused ? .black : .white, for: .normal)
        tintColor = isFocused ? .black : .white
        layer.borderWidth = 0
        layer.borderColor = (isFocused ? UIColor.white : accent).cgColor
    }
    override var canBecomeFocused: Bool { isEnabled }
    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel?.font = .systemFont(ofSize: 26, weight: .medium)
        titleLabel?.numberOfLines = 2
        setTitleColor(.white, for: .normal)
        backgroundColor = ConstantsUtil.brandingItemColor
        layer.cornerRadius = 12
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.systemFont(ofSize: 26, weight: .medium)
            return attributes
        }
        self.configuration = configuration
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations {
            self.updateStyle()
        }
        onFocus?(isFocused)
    }
}

private final class TVPanelScrollView: UIScrollView {
    override var canBecomeFocused: Bool { false }
}

@MainActor
enum TVDesign {
    static func label(_ text: String, size: CGFloat = 28, bold: Bool = false) -> UILabel {
        let label = FontAdjustedUILabel()
        label.text = text
        label.textColor = .white
        label.font = bold ? TVTypography.heading(size) : .systemFont(ofSize: size)
        label.numberOfLines = 0
        return label
    }
    static func button(_ title: String, action: @escaping () -> Void) -> TVActionButton {
        let button = TVActionButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        return button
    }
    static func stack(in view: UIView, title: String) -> UIStackView {
        let scroll = TVPanelScrollView()
        scroll.backgroundColor = ConstantsUtil.brandingBackgroundColor.withAlphaComponent(0.88)
        scroll.layer.cornerRadius = 20
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 64), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -64),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 36), scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -36),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24), stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
        let heading = label(title, size: 44, bold: true)
        heading.textColor = .white
        stack.addArrangedSubview(heading)
        return stack
    }
}

final class HomeShellViewController: UIViewController {
    var services: AppServices!
    private var menuTask: Task<Void, Never>?
    private let background = UIImageView()
    private let eventShade = CatalogGradientView()
    private let content = UIView()
    private let rail = UITableView(frame: .zero, style: .plain)
    private let railPanel = UIView()
    private var railWidth: NSLayoutConstraint!
    private var railLeading: NSLayoutConstraint!
    private var railTrailing: NSLayoutConstraint!
    private var entries = [CatalogMenuEntry]()
    private var railItems = [(title: String, icon: String, id: String)]()
    private var pages = [String: UIViewController]()
    private var pageStacks = [String: [UIViewController]]()
    private var current: UIViewController?
    private var selectedID: String?
    private var expanded = false
    private var preferredTarget: UIFocusEnvironment?
    private var awaitingPageFocus: String?
    private var isRefreshing = false
    private var imageRequest = UUID()
    private var artworkID: String?
    private var language: String { services.language }
    private let menuCache = CatalogMenuCache(defaults: .standard)

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if let preferredTarget { return [preferredTarget] }
        return current.map { [$0] } ?? Optional(rail).map { [$0] } ?? super.preferredFocusEnvironments
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ConstantsUtil.brandingBackgroundColor
        background.contentMode = .scaleAspectFill
        background.image = CatalogBackdropArtwork.placeholder
        background.alpha = 0.22
        eventShade.backgroundColor = .black.withAlphaComponent(0.25)
        eventShade.isHidden = true
        [background, eventShade, content, railPanel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; view.addSubview($0) }
        let material = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        material.frame = view.bounds; material.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        railPanel.addSubview(material)
        railPanel.clipsToBounds = true
        rail.backgroundColor = .clear; rail.overrideUserInterfaceStyle = .dark; rail.tintColor = .white
        rail.contentInsetAdjustmentBehavior = .never
        rail.insetsContentViewsToSafeArea = false
        rail.insetsLayoutMarginsFromSafeArea = false
        rail.cellLayoutMarginsFollowReadableWidth = false
        rail.directionalLayoutMargins = .zero
        rail.rowHeight = 76
        rail.delegate = self; rail.dataSource = self
        rail.remembersLastFocusedIndexPath = true
        rail.register(UITableViewCell.self, forCellReuseIdentifier: "navigation")
        rail.translatesAutoresizingMaskIntoConstraints = false
        railPanel.addSubview(rail)
        railWidth = railPanel.widthAnchor.constraint(equalToConstant: 96)
        railLeading = rail.leadingAnchor.constraint(equalTo: railPanel.leadingAnchor, constant: 8)
        railTrailing = rail.trailingAnchor.constraint(equalTo: railPanel.trailingAnchor, constant: -8)
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: view.leadingAnchor), background.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            background.topAnchor.constraint(equalTo: view.topAnchor), background.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            eventShade.leadingAnchor.constraint(equalTo: view.leadingAnchor), eventShade.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            eventShade.topAnchor.constraint(equalTo: view.topAnchor), eventShade.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 96), content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.topAnchor.constraint(equalTo: view.topAnchor), content.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            railPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor), railPanel.topAnchor.constraint(equalTo: view.topAnchor), railPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor), railWidth,
            railLeading, railTrailing, rail.centerYAnchor.constraint(equalTo: railPanel.centerYAnchor), rail.heightAnchor.constraint(equalToConstant: 650)
        ])
        entries = menuCache.load(language: language)
        rebuildRail()
        if let first = entries.first { open(first) }
        NotificationCenter.default.addObserver(self, selector: #selector(refreshMenu), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: .tvSettingsChanged, object: nil)
        refreshMenu()
    }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        let inRail = context.nextFocusedView?.isDescendant(of: railPanel) == true
        if inRail && context.focusHeading != [] { awaitingPageFocus = nil }
        setExpanded(inRail && awaitingPageFocus == nil)
        preferredTarget = nil
    }
    private func setExpanded(_ value: Bool) {
        guard expanded != value else { return }
        expanded = value
        railWidth.constant = value ? 360 : 96
        // A collapsed native pill needs enough width for its rounded ends and the icon.
        railLeading.constant = value ? 24 : 8
        railTrailing.constant = value ? -24 : -8
        UIView.animate(withDuration: 0.22) { self.view.layoutIfNeeded(); self.refreshVisibleRows() }
    }
    private func icon(for entry: CatalogMenuEntry) -> String {
        let href = entry.href.lowercased()
        if href == "/" { return "house.fill" }
        if href.contains("season") { return "flag.checkered" }
        if href.contains("archive") { return "archivebox.fill" }
        if href.contains("documentar") { return "film.stack.fill" }
        if href.contains("shows") { return "tv.fill" }
        return "rectangle.stack.fill"
    }
    private func rebuildRail() {
        railItems = entries.map { ($0.title, icon(for: $0), $0.identity) }
            + (entries.isEmpty ? [("action_retry".localizedString, "arrow.clockwise", "retry")] : [])
            + [("account_title".localizedString, "person.crop.circle", "account"), ("settings_title".localizedString, "gearshape.fill", "settings")]
        rail.reloadData()
    }
    private func refreshVisibleRows() {
        for index in rail.indexPathsForVisibleRows ?? [] {
            if let cell = rail.cellForRow(at: index) { configure(cell, at: index) }
        }
    }
    private func configure(_ cell: UITableViewCell, at index: IndexPath) {
        let item = railItems[index.row]
        var config = cell.defaultContentConfiguration()
        config.text = expanded ? item.title : nil
        config.image = UIImage(systemName: item.icon)
        config.textProperties.font = .systemFont(ofSize: 22, weight: .medium)
        config.textProperties.numberOfLines = 2
        config.textProperties.adjustsFontSizeToFitWidth = true
        config.textProperties.minimumScaleFactor = 0.9
        config.imageToTextPadding = 12
        config.imageProperties.maximumSize = CGSize(width: 28, height: 28)
        config.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 8)
        cell.viewWithTag(921)?.removeFromSuperview()
        cell.configurationUpdateHandler = nil
        cell.contentConfiguration = expanded ? config : nil
        if !expanded {
            // Native list content has generous horizontal insets on tvOS. Keep the compact symbol centered in the icon rail.
            let symbol = UIImageView(image: UIImage(systemName: item.icon)); symbol.tag = 921
            symbol.contentMode = .scaleAspectFit; symbol.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(symbol)
            NSLayoutConstraint.activate([symbol.centerXAnchor.constraint(equalTo: cell.centerXAnchor), symbol.centerYAnchor.constraint(equalTo: cell.centerYAnchor), symbol.widthAnchor.constraint(equalToConstant: 28), symbol.heightAnchor.constraint(equalToConstant: 28)])
            symbol.tintColor = cell.isFocused ? .black : .white
            cell.configurationUpdateHandler = { [weak symbol] _, state in symbol?.tintColor = state.isFocused ? .black : .white }
        }
        cell.viewWithTag(922)?.removeFromSuperview()
        if index.row == railItems.count - 2 {
            let separator = UIView(); separator.tag = 922; separator.backgroundColor = .white.withAlphaComponent(0.15)
            separator.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview(separator)
            NSLayoutConstraint.activate([separator.topAnchor.constraint(equalTo: cell.topAnchor), separator.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 16), separator.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -16), separator.heightAnchor.constraint(equalToConstant: 1)])
        }
        cell.accessibilityLabel = item.title
        cell.accessibilityTraits = selectedID == item.id ? [.button, .selected] : .button
        cell.backgroundColor = .clear
        cell.viewWithTag(920)?.removeFromSuperview()
        if selectedID == item.id {
            let marker = UIView(); marker.tag = 920; marker.backgroundColor = ConstantsUtil.brandingRed
            marker.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview(marker)
            NSLayoutConstraint.activate([marker.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2), marker.widthAnchor.constraint(equalToConstant: 3), marker.heightAnchor.constraint(equalToConstant: 24), marker.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
        }
    }
    @objc private func refreshMenu() {
        guard !isRefreshing else { return }
        isRefreshing = true
        let requestedLanguage = language
        let catalog = services.catalog
        menuTask = Task { [weak self] in
            do {
                let entries = try await catalog.menu()
                try Task.checkCancellation()
                guard let self else { return }
                self.isRefreshing = false; self.entries = entries
                self.menuCache.store(entries, language: requestedLanguage)
                self.rebuildRail()
                if self.current == nil, let first = entries.first { self.open(first) }
            } catch {
                guard let self, !(error is CancellationError) else { return }
                self.isRefreshing = false; recordServiceFailure(error, operation: .menu)
                if self.entries.isEmpty { self.rebuildRail() }
            }
        }
    }

    private func activate(_ id: String) {
        if id == "retry" { refreshMenu(); return }
        if let entry = entries.first(where: { $0.identity == id }) { open(entry) }
        else {
            let controller = pages[id] ?? (id == "account" ? services.accountController() : SettingsOverviewTableViewController())
            if let account = controller as? AccountOverviewViewController { account.services = services }
            pages[id] = controller
            show(controller, id: id)
        }
        awaitingPageFocus = (current as? PageOverviewCollectionViewController).flatMap { $0.contentSections == nil ? id : nil }
        preferredTarget = current
        setExpanded(false)
        setNeedsFocusUpdate(); updateFocusIfNeeded()
    }
    private func open(_ entry: CatalogMenuEntry) {
        let controller: UIViewController
        if let cached = pageStacks[entry.identity]?.last ?? pages[entry.identity] { controller = cached }
        else {
            let page = services.page(uri: entry.uri)
            connect(page, topic: entry.identity)
            controller = page; pages[entry.identity] = page; pageStacks[entry.identity] = [page]
        }
        show(controller, id: entry.identity)
        artworkID = (controller as? PageOverviewCollectionViewController)?.activeHeroArtwork
        updateBackground()
    }
    private func connect(_ page: PageOverviewCollectionViewController, topic: String) {
        page.services = services
        page.onHeroArtworkChange = { [weak self, weak page] picture in
            guard let self, self.current === page else { return }
            self.artworkID = picture; self.updateBackground()
        }
        page.onReady = { [weak self, weak page] in
            guard let self, let page, self.current === page, self.awaitingPageFocus == topic else { return }
            self.awaitingPageFocus = nil; self.focusContent()
        }
        page.onOpenDestination = { [weak self] destination in self?.push(destination, topic: topic) }
        page.onNavigateBack = { [weak self] in self?.navigateBack() ?? false }
    }
    private func push(_ page: PageOverviewCollectionViewController, topic: String) {
        guard selectedID == topic, let root = pages[topic] else { return }
        connect(page, topic: topic)
        pageStacks[topic, default: [root]].append(page)
        awaitingPageFocus = page.contentSections == nil ? topic : nil
        show(page, id: topic)
        artworkID = page.activeHeroArtwork; updateBackground(); focusContent()
    }
    private func focusContent() {
        preferredTarget = current; setExpanded(false)
        setNeedsFocusUpdate(); updateFocusIfNeeded()
    }
    @discardableResult private func navigateBack() -> Bool {
        if expanded { focusContent(); return true }
        guard let topic = selectedID, var stack = pageStacks[topic], stack.count > 1 else { return false }
        stack.removeLast(); pageStacks[topic] = stack
        awaitingPageFocus = nil
        if let previous = stack.last {
            show(previous, id: topic)
            artworkID = (previous as? PageOverviewCollectionViewController)?.activeHeroArtwork
            updateBackground(); focusContent()
        }
        return true
    }
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .menu }), navigateBack() { return }
        super.pressesBegan(presses, with: event)
    }
    private func show(_ controller: UIViewController, id: String) {
        guard current !== controller else { return }
        current?.willMove(toParent: nil); current?.view.removeFromSuperview(); current?.removeFromParent()
        addChild(controller); content.addSubview(controller.view)
        controller.view.frame = content.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        controller.didMove(toParent: self)
        current = controller; selectedID = id
        refreshVisibleRows()
        if !(controller is PageOverviewCollectionViewController) { artworkID = nil; updateBackground() }
    }
    @objc private func settingsChanged() { updateBackground() }
    private func updateBackground() {
        let identity = UUID(); imageRequest = identity
        let eventBackground = (current as? PageOverviewCollectionViewController)?.usesEventBackground == true
        background.alpha = eventBackground ? 0.7 : 0.22
        eventShade.isHidden = !eventBackground
        guard let screen = view.window?.screen else { return }
        let size = background.bounds.isEmpty ? screen.bounds.size : background.bounds.size
        guard eventBackground || CredentialHelper.getPlayerSettings().followsHeroBackground,
              let request = CatalogArtworkRequest(pictureID: artworkID, size: size, scale: max(screen.scale, screen.nativeScale)) else {
            background.image = CatalogBackdropArtwork.placeholder; return
        }
        let processor = DownsamplingImageProcessor(size: request.processingSize).append(another: BlurImageProcessor(blurRadius: 2))
        KingfisherManager.shared.retrieveImage(with: request.url, options: [.processor(processor), .scaleFactor(request.scale)]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.imageRequest == identity, case .success(let value) = result else { return }
                CatalogBackdropArtwork.remember(value.image)
                UIView.transition(with: self.background, duration: 0.35, options: .transitionCrossDissolve) { self.background.image = value.image }
            }
        }
    }
    deinit { menuTask?.cancel(); NotificationCenter.default.removeObserver(self) }
}

extension Notification.Name { static let tvSettingsChanged = Notification.Name("TVSettingsChanged") }

extension HomeShellViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { railItems.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "navigation", for: indexPath)
        configure(cell, at: indexPath); return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { activate(railItems[indexPath.row].id) }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 0 }

}

enum TVTypography {
    static func heading(_ size: CGFloat) -> UIFont { UIFont(name: "Formula1-Display-Bold", size: size) ?? .systemFont(ofSize: size, weight: .bold) }
}

/// Public catalog artwork only; the fallback is local and never starts an extra request.
@MainActor
enum CatalogBackdropArtwork {
    private static let file = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("CatalogBackdrop.jpg")
    private static let writes = DispatchQueue(label: "CatalogBackdropCache", qos: .utility)
    private static var cached = file.flatMap { UIImage(contentsOfFile: $0.path) }
    static var placeholder: UIImage { cached ?? branding }
    static func remember(_ image: UIImage) {
        cached = image
        guard let file, let data = image.jpegData(compressionQuality: 0.8) else { return }
        writes.async {
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
        }
    }
    private static let branding: UIImage = {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 960, height: 540), format: format).image { renderer in
            let context = renderer.cgContext
            let colors = [UIColor(red: 0.09, green: 0.15, blue: 0.23, alpha: 1).cgColor, UIColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1).cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 960, y: 540), options: [])
            }
            for index in 0..<5 {
                context.setStrokeColor(UIColor(red: 0.75, green: 0.09, blue: 0.12, alpha: 0.3 - CGFloat(index) * 0.04).cgColor)
                context.setLineWidth(index == 0 ? 20 : 3)
                context.move(to: CGPoint(x: 460 + index * 45, y: 540))
                context.addLine(to: CGPoint(x: 800 + index * 45, y: 0)); context.strokePath()
            }
        }
    }()
}

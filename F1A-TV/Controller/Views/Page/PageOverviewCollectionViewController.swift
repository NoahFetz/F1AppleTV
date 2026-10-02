import UIKit
import Kingfisher

class PageOverviewCollectionViewController: BaseCollectionViewController {
    var services: AppServices!
    private var pageTask: Task<Void, Never>?
    private var videoTask: Task<Void, Never>?
    private var videoRequestID = UUID()
    var contentSections: [ContentSection]?
    var pageUri: String?
    private var destinationItem: ContentItem?
    var onHeroArtworkChange: ((String?) -> Void)?
    var onReady: (() -> Void)?
    var onOpenDestination: ((PageOverviewCollectionViewController) -> Void)?
    var onNavigateBack: (() -> Bool)?
    private(set) var activeHeroArtwork: String?
    var usesEventBackground: Bool { CatalogPresentation.eventArtwork(destinationItem, sections: contentSections ?? []) != nil }
    private var floatingEventHeader: Bool { CatalogPresentation.isEventDestination(destinationItem, sections: contentSections ?? []) }
    private var viewAllVisibility = [Int: Bool]()
    private var heroIndices = [Int: Int]()
    private var rowFocus = [Int: IndexPath]()
    private let statusStack = UIStackView()
    private let statusMessage = TVDesign.label("", size: 26)
    private let retryButton = TVActionButton(type: .custom)
    private let loadingSpinner = UIActivityIndicatorView(style: .large)
    private var isLoading = false
    private var loadFailed = false
    private var scheduleStates = [Int: CatalogScheduleState]()
    private weak var lastFocusedView: UIView?
    private var redirectingFocus = false
    private var artworkPrefetchers = [IndexPath: ImagePrefetcher]()

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.register(CatalogCardCell.self, forCellWithReuseIdentifier: CatalogCardCell.reuseID)
        collectionView.register(CatalogDestinationCell.self, forCellWithReuseIdentifier: CatalogDestinationCell.reuseID)
        collectionView.register(CatalogBannerCell.self, forCellWithReuseIdentifier: CatalogBannerCell.reuseID)
        collectionView.register(CatalogScheduleView.self, forSupplementaryViewOfKind: CatalogScheduleView.elementKind, withReuseIdentifier: CatalogScheduleView.reuseID)
        collectionView.register(CatalogHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: CatalogHeaderView.reuseID)
        collectionView.register(CatalogHeroDots.self, forSupplementaryViewOfKind: CatalogHeroDots.kind, withReuseIdentifier: CatalogHeroDots.reuseID)
        let loading = UIView()
        if destinationItem != nil && onOpenDestination == nil {
            let background = UIImageView(image: CatalogBackdropArtwork.placeholder); background.contentMode = .scaleAspectFill; background.alpha = 0.15
            background.frame = view.bounds; background.autoresizingMask = [.flexibleWidth, .flexibleHeight]; loading.addSubview(background)
            view.backgroundColor = ConstantsUtil.brandingBackgroundColor
        }
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        loading.addSubview(loadingSpinner)
        NSLayoutConstraint.activate([loadingSpinner.centerXAnchor.constraint(equalTo: loading.centerXAnchor), loadingSpinner.centerYAnchor.constraint(equalTo: loading.centerYAnchor)])
        collectionView.backgroundView = loading
        statusStack.axis = .vertical; statusStack.spacing = 24; statusStack.alignment = .center
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusMessage.textAlignment = .center
        retryButton.setTitle("action_retry".localizedString, for: .normal)
        retryButton.addAction(UIAction { [weak self] _ in self?.loadPage() }, for: .primaryActionTriggered)
        statusStack.addArrangedSubview(statusMessage); statusStack.addArrangedSubview(retryButton)
        collectionView.addSubview(statusStack)
        NSLayoutConstraint.activate([statusStack.centerXAnchor.constraint(equalTo: collectionView.frameLayoutGuide.centerXAnchor), statusStack.centerYAnchor.constraint(equalTo: collectionView.frameLayoutGuide.centerYAnchor), statusStack.widthAnchor.constraint(equalToConstant: 900), statusMessage.widthAnchor.constraint(equalTo: statusStack.widthAnchor)])
        updateStatus()
        collectionView.remembersLastFocusedIndexPath = true
        collectionView.prefetchDataSource = self
        collectionView.setCollectionViewLayout(makeLayout(), animated: false)
    }

    func initialize(pageUri: String) { self.pageUri = pageUri }
    func initialize(pageUri: String, destination: ContentItem) {
        self.pageUri = pageUri; self.destinationItem = destination
        activeHeroArtwork = CatalogPresentation.eventArtwork(destination, sections: [])
    }
    func initialize(contentSections: [ContentSection]) { self.contentSections = contentSections }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Retain cells and orthogonal row offsets when returning from a destination or playback.
        if contentSections == nil && !isLoading { loadPage() }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .menu }), onNavigateBack?() == true { return }
        super.pressesBegan(presses, with: event)
    }

    private func updateStatus() {
        statusStack.isHidden = isLoading || !(loadFailed || contentSections?.isEmpty == true)
        statusMessage.text = (loadFailed ? "catalog_retry" : "catalog_empty").localizedString
        retryButton.isHidden = pageUri == nil
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelPendingPlayback()
        cancelArtworkPrefetching()
    }
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil { cancelPendingPlayback() }
    }
    private func cancelPendingPlayback() {
        videoTask?.cancel(); videoTask = nil; videoRequestID = UUID()
        services?.playerController.cancelPending(for: self)
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if !statusStack.isHidden && !retryButton.isHidden { return [retryButton] }
        if let lastFocusedView, lastFocusedView.window != nil, lastFocusedView.isDescendant(of: view) {
            return [lastFocusedView]
        }
        if let schedule = collectionView.visibleSupplementaryViews(ofKind: CatalogScheduleView.elementKind).first {
            return schedule.preferredFocusEnvironments
        }
        return super.preferredFocusEnvironments
    }

    override func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext,
                                 with coordinator: UIFocusAnimationCoordinator) {
        if let focused = context.nextFocusedView, focused.isDescendant(of: collectionView) { lastFocusedView = focused }
        if let index = context.nextFocusedIndexPath { rowFocus[index.section] = index }
        if let previous = context.previouslyFocusedIndexPath, let header = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: previous.section)) as? CatalogHeaderView {
            header.returnTarget = collectionView.cellForItem(at: rowFocus[previous.section] ?? previous)
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if let focused = context.nextFocusedView, focused.isDescendant(of: collectionView) {
            lastFocusedView = focused
            if let index = itemIndex(for: focused) { rowFocus[index.section] = index }
        }
    }

    override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
        routeFocus(context) && super.shouldUpdateFocus(in: context)
    }

    override func collectionView(_ collectionView: UICollectionView, shouldUpdateFocusIn context: UICollectionViewFocusUpdateContext) -> Bool {
        routeFocus(context)
    }

    private func itemIndex(for focused: UIView?) -> IndexPath? {
        var candidate = focused
        while let view = candidate, view !== collectionView {
            if let cell = view as? UICollectionViewCell {
                return collectionView.indexPath(for: cell) ?? collectionView.indexPathsForVisibleItems.first { collectionView.cellForItem(at: $0) === cell }
            }
            candidate = view.superview
        }
        return nil
    }

    private func routeFocus(_ context: UIFocusUpdateContext) -> Bool {
        guard !redirectingFocus else { return true }
        if floatingEventHeader, context.focusHeading.contains(.up), let previous = context.previouslyFocusedView,
           previous.isDescendant(of: collectionView) {
            // The focus engine cannot discover controls in a schedule that has scrolled out of view.
            if context.nextFocusedView?.isDescendant(of: collectionView) != true, let index = itemIndex(for: previous),
               let layout = contentSections?[index.section].layoutType, ![.GpBanner, .PageHeader].contains(layout) {
                if let sections = contentSections,
                   let preceding = sections[..<index.section].lastIndex(where: { $0.layoutType == .Schedule || (!$0.items.isEmpty && ![.GpBanner, .PageHeader].contains($0.layoutType)) }) {
                    if sections[preceding].layoutType == .Schedule,
                       let target = revealSchedule(at: preceding)?.preferredFocusEnvironments.first {
                        redirectFocus(to: target); return false
                    }
                    let target = rowFocus[preceding] ?? IndexPath(item: 0, section: preceding)
                    collectionView.scrollToItem(at: target, at: .centeredVertically, animated: false)
                    collectionView.layoutIfNeeded()
                    if let cell = collectionView.cellForItem(at: target) { redirectFocus(to: cell); return false }
                }
                if revealEventHeader() { return false }
            }
        }
        if context.focusHeading.contains(.up) || context.focusHeading.contains(.down),
           let previous = itemIndex(for: context.previouslyFocusedView), let source = context.previouslyFocusedView,
           let next = context.nextFocusedView,
           let header = collectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
            .compactMap({ $0 as? CatalogHeaderView }).first(where: { next.isDescendant(of: $0) }),
           !CatalogPresentation.verticallyAligned(source: source.convert(source.bounds, to: view), action: header.actionButton.convert(header.actionButton.bounds, to: view)) {
            let direction = context.focusHeading.contains(.down) ? 1 : -1
            var section = previous.section + direction
            while let sections = contentSections, sections.indices.contains(section) {
                let content = sections[section]
                if !content.items.isEmpty && ![.GpBanner, .PageHeader].contains(content.layoutType) {
                    let candidates = collectionView.indexPathsForVisibleItems.filter { $0.section == section }
                    let x = source.convert(source.bounds, to: view).midX
                    let index = candidates.min { lhs, rhs in
                        let left = collectionView.cellForItem(at: lhs).map { $0.convert($0.bounds, to: view).midX } ?? x
                        let right = collectionView.cellForItem(at: rhs).map { $0.convert($0.bounds, to: view).midX } ?? x
                        return abs(left - x) < abs(right - x)
                    } ?? rowFocus[section] ?? IndexPath(item: 0, section: section)
                    collectionView.scrollToItem(at: index, at: .centeredVertically, animated: false); collectionView.layoutIfNeeded()
                    if let cell = collectionView.cellForItem(at: index) { redirectFocus(to: cell); return false }
                } else if content.layoutType == .Schedule,
                          let schedule = revealSchedule(at: section),
                          let target = schedule.preferredFocusEnvironments.first { redirectFocus(to: target); return false }
                section += direction
            }
            return false
        }
        if context.focusHeading.contains(.down), let previous = context.previouslyFocusedView,
           let header = collectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
            .compactMap({ $0 as? CatalogHeaderView }).first(where: { previous.isDescendant(of: $0) }),
           let section = collectionView.indexPathsForVisibleSupplementaryElements(ofKind: UICollectionView.elementKindSectionHeader)
            .first(where: { collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: $0) === header })?.section,
           let content = contentSections?[section], !content.items.isEmpty {
            let index = rowFocus[section] ?? IndexPath(item: 0, section: section)
            if itemIndex(for: context.nextFocusedView) == index { return true }
            if rowFocus[section] == nil, itemIndex(for: context.nextFocusedView)?.section == section { return true }
            redirectingFocus = true
            collectionView.scrollToItem(at: index, at: .centeredVertically, animated: false)
            collectionView.layoutIfNeeded()
            if let cell = collectionView.cellForItem(at: index) { redirectFocus(to: cell) }
            else { redirectingFocus = false }
            return false
        }
        return true
    }

    private func revealSchedule(at section: Int) -> CatalogScheduleView? {
        let index = IndexPath(item: 0, section: section)
        if let schedule = collectionView.supplementaryView(forElementKind: CatalogScheduleView.elementKind, at: index) as? CatalogScheduleView { return schedule }
        if let attributes = collectionView.collectionViewLayout.layoutAttributesForSupplementaryView(ofKind: CatalogScheduleView.elementKind, at: index) {
            let y = max(-collectionView.adjustedContentInset.top, attributes.frame.minY - collectionView.adjustedContentInset.top)
            collectionView.setContentOffset(CGPoint(x: collectionView.contentOffset.x, y: y), animated: false)
            collectionView.layoutIfNeeded()
        }
        return collectionView.supplementaryView(forElementKind: CatalogScheduleView.elementKind, at: index) as? CatalogScheduleView
    }

    private func revealEventHeader() -> Bool {
        // Focus the floating header itself so tvOS reveals its full bounds instead of recentering a lower control.
        guard let section = contentSections?.firstIndex(where: { [.GpBanner, .PageHeader].contains($0.layoutType) }) else { return false }
        let index = IndexPath(item: 0, section: section)
        if collectionView.cellForItem(at: index) == nil {
            collectionView.scrollToItem(at: index, at: .top, animated: false)
            collectionView.layoutIfNeeded()
        }
        guard let cell = collectionView.cellForItem(at: index) else { return false }
        redirectFocus(to: cell)
        return true
    }

    private func redirectFocus(to environment: UIFocusEnvironment) {
        let target = (environment as? UICollectionViewCell)?.preferredFocusEnvironments.first ?? environment
        redirectingFocus = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastFocusedView = target as? UIView
            let system = UIFocusSystem.focusSystem(for: self.view)
            // Request from the environment that owns current focus; its preferred environment supplies the destination.
            system?.requestFocusUpdate(to: self); system?.updateFocusIfNeeded()
            self.redirectingFocus = false
        }
    }

    private func loadPage() {
        guard let pageUri, !isLoading else { return }
        isLoading = true
        loadingSpinner.startAnimating()
        loadFailed = false
        updateStatus()
        let catalog = services.catalog
        pageTask = Task { [weak self] in
            do {
                let document = try await catalog.page(CatalogDestination(uri: pageUri))
                try Task.checkCancellation()
                self?.applyContentPage(document)
            } catch {
                guard let self, !Task.isCancelled, !(error is CancellationError) else { return }
                recordServiceFailure(error, operation: .page)
                self.didFailContentPage(error: error)
            }
        }
    }

    private func applyContentPage(_ document: CatalogDocument) {
        cancelArtworkPrefetching()
        contentSections = CatalogPresentation.sections(document.sections, destination: destinationItem)
        loadingSpinner.stopAnimating()
        activeHeroArtwork = CatalogPresentation.eventArtwork(destinationItem, sections: contentSections ?? [])
            ?? contentSections?.first(where: { $0.layoutType == .Hero })?.items.first?.pictureUrl
        onHeroArtworkChange?(activeHeroArtwork)
        isLoading = false
        loadFailed = false
        updateStatus()
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        // Nested schedule controls finish laying out after the collection reload.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.view.window != nil else { return }
            self.collectionView.layoutIfNeeded()
            if let schedule = self.collectionView.visibleSupplementaryViews(ofKind: CatalogScheduleView.elementKind).first,
               let target = schedule.preferredFocusEnvironments.first,
               let system = UIFocusSystem.focusSystem(for: self.view) {
                self.lastFocusedView = target as? UIView
                system.requestFocusUpdate(to: self)
                system.updateFocusIfNeeded()
            } else {
                self.setNeedsFocusUpdate()
                self.updateFocusIfNeeded()
            }
            self.onReady?()
        }
    }

    private func cancelArtworkPrefetching() {
        artworkPrefetchers.values.forEach { $0.stop() }
        artworkPrefetchers.removeAll()
    }

    func didFailContentPage(error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.loadingSpinner.stopAnimating()
            self.isLoading = false
            self.loadFailed = true
            self.updateStatus()
            self.collectionView.reloadData()
            self.onReady?()
        }
    }

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] index, environment in
            guard let self else { return nil }
            let section = self.contentSections?.indices.contains(index) == true ? self.contentSections?[index] : nil
            let type = section?.layoutType ?? .ContentItem
            let availableWidth = max(300, environment.container.effectiveContentSize.width - 64)
            let showsViewAll = section.map { CatalogPresentation.showsViewAll($0, availableWidth: availableWidth, availableHeight: environment.container.effectiveContentSize.height) } ?? false
            self.viewAllVisibility[index] = showsViewAll
            let isHorizontal = type.isHorizontal
            let isPoster = type.isPoster
            let width: CGFloat
            let height: CGFloat
            let group: NSCollectionLayoutGroup
            switch type {
            case .Hero:
                width = availableWidth
                height = min(620, max(400, width * 9 / 16))
            case .PageHeader:
                width = availableWidth
                height = section?.items.first.map { CatalogDestinationCell.height(for: $0, floating: self.floatingEventHeader) } ?? 180
            case .GpBanner:
                width = availableWidth
                height = self.floatingEventHeader ? 260 : section?.items.first?.pictureUrl?.isEmpty == false ? 420 : 260
            case .Schedule:
                width = availableWidth
                height = 1
            case .Title, .Subtitle:
                width = availableWidth
                height = 1
            default:
                width = CatalogPresentation.cardWidth(layout: type, availableWidth: availableWidth)
                let simplePoster = [.HorizontalSimplePoster, .VerticalSimplePoster].contains(type)
                height = width * (isPoster ? 1.5 : 9 / 16) + (simplePoster ? 0 : isPoster ? 144 : 160)
            }
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(width), heightDimension: .absolute(height)))
            if isHorizontal || [.Hero, .GpBanner, .PageHeader, .Schedule, .Title, .Subtitle].contains(type) {
                group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(width), heightDimension: .absolute(height)), subitems: [item])
            } else {
                group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(height)),
                                                          repeatingSubitem: item, count: isPoster ? 4 : 3)
                group.interItemSpacing = .fixed(24)
            }
            let layout = NSCollectionLayoutSection(group: group)
            layout.contentInsets = NSDirectionalEdgeInsets(top: [.Title, .Subtitle].contains(type) ? 8 : 16, leading: 32, bottom: [.Title, .Subtitle].contains(type) ? 8 : 24, trailing: 32)
            layout.interGroupSpacing = 24
            if isHorizontal { layout.orthogonalScrollingBehavior = type == .Hero ? .groupPaging : .continuousGroupLeadingBoundary }
            if type == .Hero, let section {
                layout.boundarySupplementaryItems = [NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(52)),
                    elementKind: CatalogHeroDots.kind, alignment: .bottom)]
                layout.visibleItemsInvalidationHandler = { [weak self] items, offset, environment in
                    guard let self, let centered = items.filter({ $0.representedElementCategory == .cell }).min(by: {
                        abs($0.frame.midX - offset.x - environment.container.effectiveContentSize.width / 2) < abs($1.frame.midX - offset.x - environment.container.effectiveContentSize.width / 2)
                    }) else { return }
                    let itemIndex = centered.indexPath.item
                    self.heroIndices[index] = itemIndex
                    (self.collectionView.supplementaryView(forElementKind: CatalogHeroDots.kind, at: IndexPath(item: 0, section: index)) as? CatalogHeroDots)?.configure(count: section.items.count, index: itemIndex)
                    let picture = section.items[itemIndex].pictureUrl
                    if !self.floatingEventHeader && picture != self.activeHeroArtwork {
                        self.activeHeroArtwork = picture
                        DispatchQueue.main.async { [weak self] in self?.onHeroArtworkChange?(picture) }
                    }
                }
            } else if type == .Schedule, let section {
                let scheduleHeight = CatalogScheduleView.height(schedule: section.schedule ?? CatalogSchedule(groups: []),
                                                                 state: self.scheduleStates[index] ?? CatalogScheduleState())
                layout.boundarySupplementaryItems = [NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(scheduleHeight)),
                    elementKind: CatalogScheduleView.elementKind, alignment: .top)]
            } else if let section, !section.title.isEmpty || showsViewAll {
                let headerHeight: CGFloat = [.Title, .Subtitle].contains(type) ? CatalogHeaderView.height(for: section, width: availableWidth) : 72
                layout.boundarySupplementaryItems = [NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(headerHeight)),
                    elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)]
            }
            return layout
        }
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int { max(1, contentSections?.count ?? 0) }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let contentSections, !contentSections.isEmpty else { return 0 }
        let content = contentSections[section]
        if content.layoutType == .Schedule { return 0 }
        if content.layoutType == .GpBanner { return 1 }
        return content.items.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let contentSections, !contentSections.isEmpty else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CatalogCardCell.reuseID, for: indexPath) as! CatalogCardCell
            let title = loadFailed ? "catalog_retry" : contentSections == nil ? "catalog_loading" : "catalog_empty"
            cell.configure(item: nil, style: .thumbnail, loadingTitle: title.localizedString)
            cell.onAction = { [weak self] in self?.loadPage() }
            return cell
        }
        let section = contentSections[indexPath.section]
        if section.layoutType == .PageHeader {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CatalogDestinationCell.reuseID, for: indexPath) as! CatalogDestinationCell
            let item = section.items[0]; cell.configure(item, floating: floatingEventHeader)
            cell.onMore = { [weak self] in self?.presentFullscreen(viewController: CatalogTextViewController(title: item.title ?? "", text: item.longDescription ?? "")) }
            return cell
        }
        if section.layoutType == .GpBanner {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CatalogBannerCell.reuseID, for: indexPath) as! CatalogBannerCell
            let item = section.items[0]; cell.configure(item, floating: floatingEventHeader)
            cell.onMore = { [weak self] in self?.presentFullscreen(viewController: CatalogTextViewController(title: item.title ?? "", text: item.longDescription ?? "")) }
            return cell
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CatalogCardCell.reuseID, for: indexPath) as! CatalogCardCell
        let style: CatalogCardCell.Style = section.layoutType == .Hero ? .hero : section.layoutType.isPoster ? .poster : .thumbnail
        let item = section.items[indexPath.item]
        cell.configure(item: item, style: style, artworkOnly: [.HorizontalSimplePoster, .VerticalSimplePoster].contains(section.layoutType))
        cell.onAction = { [weak self] in self?.openItem(item) }
        cell.onMore = { [weak self] in self?.presentFullscreen(viewController: CatalogTextViewController(title: item.title ?? "", text: item.longDescription ?? "")) }
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                                 at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == CatalogHeroDots.kind, let section = contentSections?[indexPath.section] {
            let dots = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: CatalogHeroDots.reuseID, for: indexPath) as! CatalogHeroDots
            dots.configure(count: section.items.count, index: heroIndices[indexPath.section] ?? 0)
            return dots
        }
        if kind == CatalogScheduleView.elementKind, let section = contentSections?[indexPath.section] {
            let schedule = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: CatalogScheduleView.reuseID,
                                                                           for: indexPath) as! CatalogScheduleView
            schedule.configure(schedule: section.schedule ?? CatalogSchedule(groups: []), state: scheduleStates[indexPath.section] ?? CatalogScheduleState())
            schedule.onStateChange = { [weak self] state in
                self?.scheduleStates[indexPath.section] = state
                self?.collectionView.collectionViewLayout.invalidateLayout()
            }
            schedule.onSelect = { [weak self] event in self?.openItem(event) }
            return schedule
        }
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: CatalogHeaderView.reuseID, for: indexPath) as! CatalogHeaderView
        if let section = contentSections?[indexPath.section] {
            header.configure(title: section.title, layout: section.layoutType, hasAction: viewAllVisibility[indexPath.section] == true, subtitle: [.Title, .Subtitle].contains(section.layoutType) ? section.subtitle : nil)
            header.onAction = { [weak self] in self?.openViewAll(section) }
            if let index = rowFocus[indexPath.section] { header.returnTarget = collectionView.cellForItem(at: index) }
        }
        return header
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let contentSections, !contentSections.isEmpty else {
            if !isLoading { loadPage() }
            return
        }
        let section = contentSections[indexPath.section]
        guard ![.GpBanner, .PageHeader, .Schedule].contains(section.layoutType) else { return }
        if section.items.indices.contains(indexPath.item) { openItem(section.items[indexPath.item]) }
    }

    private func openViewAll(_ section: ContentSection) {
        guard let action = section.viewAllAction else { return }
        var item = ContentItem(); item.id = section.id; item.objectType = .Bundle
        item.title = section.title; item.pictureUrl = section.artwork
        openPage(uri: action.uri, item: item)
    }

    private func openPage(uri: String, item: ContentItem) {
        let page = services.page(uri: uri, destination: item)
        if let onOpenDestination { onOpenDestination(page) }
        else { presentFullscreen(viewController: page) }
    }

    private func openItem(_ item: ContentItem) {
        switch item.action {
        case .destination(let destination): openPage(uri: destination.uri, item: item)
        case .playback(let target):
            guard item.canPlay else { return }
            videoTask?.cancel(); let requestID = UUID(); videoRequestID = requestID
            let services = services!
            videoTask = Task { [weak self] in
                do {
                    guard let profile = try await services.auth.account(), profile.hasSubscription else { throw APIError.authentication }
                    try Task.checkCancellation()
                    guard let self, self.videoRequestID == requestID, self.view.window != nil else { return }
                    if target.requiresVideoDetails, let id = item.contentId {
                        let video = try await services.playback.video(id)
                        try Task.checkCancellation()
                        guard self.videoRequestID == requestID, self.view.window != nil else { return }
                        self.offerPlayback(video)
                    } else { services.playerController.playStream(contentId: target.uri, services: services, owner: self) }
                } catch {
                    guard let self, self.videoRequestID == requestID, self.view.window != nil, !Task.isCancelled, !(error is CancellationError) else { return }
                    recordServiceFailure(error, operation: .video)
                    if error as? APIError == .authentication {
                        UserInteractionHelper.instance.showError(title: "account_no_subscription_title".localizedString, message: "account_no_subscription_message".localizedString, recordsError: false)
                    } else {
                        UserInteractionHelper.instance.showError(title: "error".localizedString, message: "diagnostics_summary_operation".localizedString, recordsError: false, retry: { [weak self] in self?.openItem(item) })
                    }
                }
            }
        case nil: break
        }
    }
    private func offerPlayback(_ video: VideoDetails) {
        guard video.isLive else { prepareToStartStream(video, playFromStart: false); return }
        switch CredentialHelper.getPlayerSettings().liveStart {
        case .live: prepareToStartStream(video, playFromStart: false)
        case .beginning: prepareToStartStream(video, playFromStart: true)
        case .ask:
            let alert = UIAlertController(title: "stream_start_live_or_from_start_title".localizedString, message: "stream_start_live_or_from_start_message".localizedString, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "stream_start_live_or_from_start_live".localizedString, style: .default) { [weak self] _ in self?.prepareToStartStream(video, playFromStart: false) })
            alert.addAction(UIAlertAction(title: "stream_start_live_or_from_start_start".localizedString, style: .default) { [weak self] _ in self?.prepareToStartStream(video, playFromStart: true) })
            present(alert, animated: true)
        }
    }
    private func prepareToStartStream(_ video: VideoDetails, playFromStart: Bool) {
        guard video.channels.count > 1 else {
            if let channel = PlaybackSelection.initialChannel(in: video.channels, preference: CredentialHelper.getPlayerSettings().defaultFeed) {
                services.playerController.playStream(contentId: channel.target.uri, playFromStart: playFromStart, services: services, owner: self, channel: channel.kind, isLive: video.isLive)
            }
            return
        }
        let settings = CredentialHelper.getPlayerSettings()
        let items = video.channels.map { channel -> ContentItem in
            var item = channel.displayItem
            if channel.kind == .MainFeed { item.title = "international_feed_title".localizedString }
            else if channel.kind == .OnBoardCamera {
                let name = [channel.driverFirstName, channel.driverLastName].compactMap { $0 }.joined(separator: " ")
                let alternate = AlternateUniverseDrivers.fromOriginalName(originalName: name)
                item.title = settings.showFunNames && alternate != .None ? alternate.getAlternateName() : name.isEmpty ? channel.title : name
            } else {
                let keys = ["TRACKER": "tracker_feed_title", "PIT LANE": "pit_lane_feed_title", "DATA": "data_feed_title", "F1 LIVE": "f1_live_feed_title"]
                item.title = keys[channel.title].map { $0.localizedString } ?? channel.title
            }
            return item
        }.sorted {
            let lhs = $0.channelType ?? .MainFeed, rhs = $1.channelType ?? .MainFeed
            if lhs != rhs { return lhs.getIdentifier() < rhs.getIdentifier() }
            if settings.driverChannelSorting == .DriverNumber { return ($0.channel?.racingNumber ?? 0) < ($1.channel?.racingNumber ?? 0) }
            return ($0.channel?.title ?? "") < ($1.channel?.title ?? "")
        }
        let player = services.viewer(channels: items, fromBeginning: playFromStart)
        presentFullscreen(viewController: player)
    }
    deinit { pageTask?.cancel(); videoTask?.cancel() }
}

extension PageOverviewCollectionViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        guard let screen = view.window?.screen else { return }
        for index in indexPaths {
            guard artworkPrefetchers[index] == nil, let sections = contentSections,
                  sections.indices.contains(index.section), sections[index.section].items.indices.contains(index.item),
                  let attributes = collectionView.collectionViewLayout.layoutAttributesForItem(at: index) else { continue }
            let section = sections[index.section]
            guard ![.Title, .Subtitle, .Schedule, .PageHeader, .GpBanner].contains(section.layoutType) else { continue }
            let hero = section.layoutType == .Hero
            let width = attributes.size.width
            let size = hero ? attributes.size : CGSize(width: width, height: width * (section.layoutType.isPoster ? 1.5 : 9 / 16))
            guard let request = CatalogArtworkRequest(pictureID: section.items[index.item].pictureUrl, size: size,
                                                      scale: max(screen.scale, screen.nativeScale), focusScale: hero ? 1 : 1.025) else { continue }
            let prefetcher = ImagePrefetcher(urls: [request.url], options: [
                .processor(DownsamplingImageProcessor(size: request.processingSize)), .scaleFactor(request.scale), .alsoPrefetchToMemory
            ])
            artworkPrefetchers[index] = prefetcher
            prefetcher.start()
        }
    }
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        for index in indexPaths { artworkPrefetchers.removeValue(forKey: index)?.stop() }
    }
}

#if canImport(F1Core)
import F1Core
#endif
import UIKit
import AVKit

class ChannelSelectorOverlayViewController: BaseViewController {
    @IBOutlet weak var contentStackView: UIStackView!
    var channelsTableView: UITableView?
    var channelItems = [ContentItem]()
    weak var selectionReturnProtocol: ChannelSelectionProtocol?
    var activeChannelKeys = Set<String>()
    weak var referencePlayer: AVPlayer?
    var referencePlayerProvider: (() -> AVPlayer?)?
    var services: AppServices!
    private lazy var previewFeeds = PreviewFeedLoader { [playback = self.services.playback as? any PreviewFeedBundleLoading] id in
        try await playback?.previewFeedBundle(contentID: id)
    }
    private lazy var previews = StreamPreviewCoordinator(makeSession: { [services = self.services!, previewFeeds = self.previewFeeds] in
        StreamPreviewSession(services: services, previewFeeds: previewFeeds)
    })
    private let compositePreview = TVCompositePreviewCoordinator()
    private var previewUpdate: DispatchWorkItem?
    private var previewsActive = false

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        channelsTableView.map { [$0] } ?? super.preferredFocusEnvironments
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(closePicker))
        swipe.direction = .right
        view.addGestureRecognizer(swipe)
        let menu = UITapGestureRecognizer(target: self, action: #selector(closePicker))
        menu.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        view.addGestureRecognizer(menu)
        setupSidebar()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPreview()

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        channelsTableView?.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let settings = CredentialHelper.getPlayerSettings()
        if settings.livePreviews {
            previewsActive = true
            previews.configure(items: channelItems, reference: referencePlayer, maximumHeight: settings.previewHeight, referenceProvider: referencePlayerProvider)
            previews.onReady = { [weak self] _, _ in self?.attachPreviews() }
            compositePreview.onChanged = { [weak self] in self?.updatePreviews() }
            compositePreview.onFrame = { [weak self] in
                self?.channelsTableView?.visibleCells.forEach { ($0 as? ChannelPreviewCell)?.drawCompositePreview() }
            }
            compositePreview.start(items: channelItems, loader: previewFeeds) { [weak self] in
                self?.referencePlayerProvider?() ?? self?.referencePlayer
            }
            updatePreviews()
        }
    }

    func initialize(channelItems: [ContentItem], selectionReturnProtocol: ChannelSelectionProtocol) {
        self.channelItems = channelItems
        self.selectionReturnProtocol = selectionReturnProtocol
    }

    private func setupSidebar() {
        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        contentStackView.axis = .horizontal
        contentStackView.alignment = .fill
        contentStackView.layoutMargins = UIEdgeInsets(top: 36, left: 48, bottom: 36, right: 48)
        contentStackView.isLayoutMarginsRelativeArrangement = true
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        contentStackView.addArrangedSubview(spacer)
        let material = PlayerMaterial.makeView(cornerRadius: 28)
        material.translatesAutoresizingMaskIntoConstraints = false
        material.widthAnchor.constraint(equalToConstant: 520).isActive = true
        contentStackView.addArrangedSubview(material)
        let title = UILabel()
        title.text = "manage_streams".localizedString
        title.font = .systemFont(ofSize: 34, weight: .bold)
        title.textColor = .white
        title.numberOfLines = 2
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear
        table.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 294
        table.remembersLastFocusedIndexPath = true
        table.register(ChannelPreviewCell.self, forCellReuseIdentifier: ChannelPreviewCell.reuseIdentifier)
        table.delegate = self
        table.dataSource = self
        channelsTableView = table
        [title, table].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; material.contentView.addSubview($0) }
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: material.contentView.leadingAnchor, constant: 28),
            title.trailingAnchor.constraint(equalTo: material.contentView.trailingAnchor, constant: -28),
            title.topAnchor.constraint(equalTo: material.contentView.topAnchor, constant: 24),
            table.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 18),
            table.leadingAnchor.constraint(equalTo: material.contentView.leadingAnchor, constant: 16),
            table.trailingAnchor.constraint(equalTo: material.contentView.trailingAnchor, constant: -16),
            table.bottomAnchor.constraint(equalTo: material.contentView.bottomAnchor)
        ])
    }

    private func stopPreview() {
        previewsActive = false
        previewUpdate?.cancel(); previewUpdate = nil
        compositePreview.stop()
        previews.stop()
        previewFeeds.reset()
        channelsTableView?.visibleCells.compactMap { $0 as? ChannelPreviewCell }.forEach { $0.clearPreview() }
    }
    private func updatePreviews() {
        guard previewsActive, view.window != nil, !compositePreview.isLoading else { return }
        let indices = Set((channelsTableView?.indexPathsForVisibleRows ?? []).map(\.row))
        let covered = Set(channelItems.filter { compositePreview.tile(for: $0) != nil }.map(\.previewIdentity))
        previews.update(visibleIndices: indices, excluding: covered)
        attachPreviews()
    }
    private func attachPreviews() {
        guard previewsActive, let table = channelsTableView else { return }
        for index in table.indexPathsForVisibleRows ?? [] where channelItems.indices.contains(index.row) {
            guard let cell = table.cellForRow(at: index) as? ChannelPreviewCell else { continue }
            let item = channelItems[index.row]
            let tile = compositePreview.tile(for: item)
            cell.setCompositePreview(tile)
            if tile == nil { cell.setPreviewPlayer(previews.player(for: ChannelPreviewCell.channelKey(item))) }
        }
    }
    private func schedulePreviewUpdate() {
        previewUpdate?.cancel()
        let update = DispatchWorkItem { [weak self] in self?.updatePreviews() }
        previewUpdate = update
        DispatchQueue.main.async(execute: update)
    }
    @objc private func closePicker() { dismiss(animated: true) }
}

extension ChannelSelectorOverlayViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { channelItems.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChannelPreviewCell.reuseIdentifier, for: indexPath) as! ChannelPreviewCell
        let item = channelItems[indexPath.row]
        cell.configure(item: item, added: activeChannelKeys.contains(ChannelPreviewCell.channelKey(item)))
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) { schedulePreviewUpdate() }
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) { schedulePreviewUpdate() }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = channelItems[indexPath.row]
        let key = ChannelPreviewCell.channelKey(item)
        if activeChannelKeys.remove(key) != nil {
            selectionReturnProtocol?.didRemoveChannel(channelItem: item)
        } else {
            activeChannelKeys.insert(key)
            selectionReturnProtocol?.didSelectChannel(channelItem: item)
        }
        (tableView.cellForRow(at: indexPath) as? ChannelPreviewCell)?.setAdded(activeChannelKeys.contains(key))
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? ChannelPreviewCell)?.clearPreview()
        schedulePreviewUpdate()
    }
}

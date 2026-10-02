import UIKit
import AVKit

class ChannelSelectorOverlayViewController: BaseViewController {
    @IBOutlet weak var contentStackView: UIStackView!
    var channelsTableView: UITableView?
    var channelItems = [ContentItem]()
    var selectionReturnProtocol: ChannelSelectionProtocol?
    var activeChannelKeys = Set<String>()
    weak var referencePlayer: AVPlayer?
    var referencePlayerProvider: (() -> AVPlayer?)?
    var services: AppServices!
    private lazy var previews = StreamPreviewCoordinator(makeSession: { [services = self.services!] in StreamPreviewSession(services: services) })
    private var previewUpdate: DispatchWorkItem?

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
            previews.configure(items: channelItems, reference: referencePlayer, maximumHeight: settings.previewHeight, referenceProvider: referencePlayerProvider)
            previews.onReady = { [weak self] _, _ in self?.attachPreviews() }
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
        title.text = "multiplayer_channel_selector_add_channel_title".localizedString
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
        previewUpdate?.cancel(); previewUpdate = nil
        previews.stop()
        channelsTableView?.visibleCells.compactMap { $0 as? ChannelPreviewCell }.forEach { $0.setPreviewPlayer(nil) }
    }
    private func updatePreviews() {
        guard view.window != nil, CredentialHelper.getPlayerSettings().livePreviews else { return }
        let indices = Set((channelsTableView?.indexPathsForVisibleRows ?? []).map(\.row))
        previews.update(visibleIndices: indices)
        attachPreviews()
    }
    private func attachPreviews() {
        guard let table = channelsTableView else { return }
        for index in table.indexPathsForVisibleRows ?? [] {
            let key = ChannelPreviewCell.channelKey(channelItems[index.row])
            (table.cellForRow(at: index) as? ChannelPreviewCell)?.setPreviewPlayer(previews.player(for: key))
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
        guard activeChannelKeys.insert(ChannelPreviewCell.channelKey(item)).inserted else { return }
        (tableView.cellForRow(at: indexPath) as? ChannelPreviewCell)?.setAdded(true)
        selectionReturnProtocol?.didSelectChannel(channelItem: item)
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? ChannelPreviewCell)?.setPreviewPlayer(nil)
        schedulePreviewUpdate()
    }
}

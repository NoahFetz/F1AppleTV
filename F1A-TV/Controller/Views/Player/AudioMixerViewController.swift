import UIKit
import F1Core

final class AudioMixerRow: UITableViewCell {
    static let reuseID = "AudioMixerRow"
    private(set) var stream: AudioMixStreamState?
    var onVolume: ((String, Float) -> Void)?
    private let nameLabel = UILabel()
    private let levelLabel = UILabel()
    private let speaker = UIImageView()
    private let level = UIProgressView(progressViewStyle: .default)
    private var input: HorizontalRemoteInput!
    private var repeatTimer: Timer?
    private var panValue: Float = 0

    override var canBecomeFocused: Bool { stream?.isAvailable == true }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        focusStyle = .custom
        contentView.layer.cornerRadius = 8
        nameLabel.font = .systemFont(ofSize: 26, weight: .semibold)
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = .byTruncatingTail
        levelLabel.font = .monospacedDigitSystemFont(ofSize: 24, weight: .medium)
        levelLabel.textAlignment = .right
        speaker.contentMode = .scaleAspectFit
        level.progressTintColor = .white
        level.trackTintColor = UIColor.white.withAlphaComponent(0.24)
        [nameLabel, levelLabel, speaker, level].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview($0) }
        NSLayoutConstraint.activate([
            speaker.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            speaker.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            speaker.widthAnchor.constraint(equalToConstant: 36), speaker.heightAnchor.constraint(equalToConstant: 36),
            nameLabel.leadingAnchor.constraint(equalTo: speaker.trailingAnchor, constant: 18),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: levelLabel.leadingAnchor, constant: -18),
            levelLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            levelLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor), levelLabel.widthAnchor.constraint(equalToConstant: 88),
            level.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            level.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            level.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 14),
            level.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        ])
        accessibilityTraits = [.adjustable, .button]
        input = HorizontalRemoteInput(view: self)
        input.onStep = { [weak self] in self?.adjust($0) }
        input.onHold = { [weak self] direction, began in
            guard let self else { return }
            self.stopRepeating()
            guard began else { return }
            self.adjust(direction)
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.isFocused else { self?.stopRepeating(); return }
                    self.adjust(direction)
                }
            }
            self.repeatTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        input.onPan = { [weak self] delta in
            guard let self, let stream = self.stream, stream.isAvailable else { return }
            self.panValue = min(max(self.panValue + Float(delta), 0), 1)
            self.onVolume?(stream.id, self.panValue)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { repeatTimer?.invalidate() }

    func apply(_ stream: AudioMixStreamState) {
        self.stream = stream
        panValue = stream.volume
        nameLabel.text = stream.title
        levelLabel.text = stream.isAvailable ? "\(Int((stream.volume * 100).rounded()))%" : "--"
        speaker.image = UIImage(systemName: stream.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
        level.progress = stream.volume
        accessibilityIdentifier = "multiview.audio.\(stream.id)"
        accessibilityLabel = stream.title
        accessibilityValue = stream.isAvailable ? "\(levelLabel.text ?? ""), \((stream.isMuted ? "multiview_muted" : "multiview_unmuted").localizedString)" : "multiview_unavailable".localizedString
        updateAppearance()
    }

    func adjust(_ direction: TransportDirection) {
        guard let stream, stream.isAvailable else { return }
        let volume = min(max((stream.volume * 100 + Float(direction.rawValue) * 5).rounded() / 100, 0), 1)
        onVolume?(stream.id, volume)
    }

    func stopRepeating() { repeatTimer?.invalidate(); repeatTimer = nil }
    override func prepareForReuse() { super.prepareForReuse(); stopRepeating(); stream = nil }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if !isFocused { stopRepeating() }
        coordinator.addCoordinatedAnimations { self.updateAppearance() }
    }

    override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
        let vertical = context.focusHeading.contains(.up) || context.focusHeading.contains(.down)
        if context.previouslyFocusedView === self && !vertical && (context.focusHeading.contains(.left) || context.focusHeading.contains(.right)) { return false }
        return super.shouldUpdateFocus(in: context)
    }

    private func updateAppearance() {
        let color: UIColor = isFocused ? .black : .white
        contentView.backgroundColor = isFocused ? .white : .clear
        [nameLabel, levelLabel].forEach { $0.textColor = color }
        speaker.tintColor = color
        level.progressTintColor = color
        level.trackTintColor = color.withAlphaComponent(0.24)
        contentView.alpha = stream?.isAvailable == true ? 1 : 0.45
    }

    override func accessibilityIncrement() { adjust(.forward) }
    override func accessibilityDecrement() { adjust(.backward) }
}

final class AudioMixerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var snapshot: (() -> [AudioMixStreamState])?
    var onVolume: ((String, Float) -> Void)?
    var onMute: ((String, Bool) -> Void)?
    var onPlayPause: (() -> Void)?
    var onDismiss: (() -> Void)?
    var selectedStreamID: String?
    private(set) var streams = [AudioMixStreamState]()
    let tableView = UITableView(frame: .zero, style: .plain)
    private var refreshTimer: Timer?
    private var lastFocusedID: String?
    private var notifiedDismissal = false
    private var isClosing = false
    private var backgroundObserver: NSObjectProtocol?

    override var preferredFocusEnvironments: [UIFocusEnvironment] { [tableView] }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        let panel = PlayerMaterial.makeView(cornerRadius: 28)
        let title = UILabel()
        title.text = "multiview_audio_mixer_title".localizedString
        title.textColor = .white
        title.font = .systemFont(ofSize: 34, weight: .semibold)
        tableView.backgroundColor = .clear
        tableView.rowHeight = 128
        tableView.dataSource = self
        tableView.delegate = self
        tableView.remembersLastFocusedIndexPath = false
        tableView.register(AudioMixerRow.self, forCellReuseIdentifier: AudioMixerRow.reuseID)
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        [title, tableView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; panel.contentView.addSubview($0) }
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: view.centerXAnchor), panel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: 760),
            panel.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.85),
            title.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 32),
            title.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -32),
            title.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 28),
            tableView.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 24),
            tableView.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -24),
            tableView.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -24)
        ])
        let back = UITapGestureRecognizer(target: self, action: #selector(close))
        back.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        view.addGestureRecognizer(back)
        let playPause = UITapGestureRecognizer(target: self, action: #selector(togglePlayback))
        playPause.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        view.addGestureRecognizer(playPause)
        backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tableView.visibleCells.compactMap { $0 as? AudioMixerRow }.forEach { $0.stopRepeating() }
            }
        }
        refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        refreshTimer?.invalidate(); refreshTimer = nil
        tableView.visibleCells.compactMap { $0 as? AudioMixerRow }.forEach { $0.stopRepeating() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !isClosing && (isBeingDismissed || presentingViewController == nil) {
            DispatchQueue.main.async { [weak self] in self?.notifyDismissal() }
        }
    }

    deinit {
        refreshTimer?.invalidate()
        if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
    }

    func refresh() {
        let next = snapshot?() ?? []
        let changed = streams.map(\.id) != next.map(\.id) || streams.map(\.isAvailable) != next.map(\.isAvailable)
        let previousIndex = streams.firstIndex { $0.id == lastFocusedID } ?? 0
        streams = next
        if changed {
            if lastFocusedID == nil && streams.contains(where: { $0.id == selectedStreamID && $0.isAvailable }) {
                lastFocusedID = selectedStreamID
            } else if !streams.contains(where: { $0.id == lastFocusedID && $0.isAvailable }) {
                lastFocusedID = streams.isEmpty ? nil : streams[min(previousIndex, streams.count - 1)].id
            }
            tableView.reloadData()
            if view.window != nil { setNeedsFocusUpdate(); updateFocusIfNeeded() }
        } else {
            for case let cell as AudioMixerRow in tableView.visibleCells {
                if let stream = streams.first(where: { $0.id == cell.stream?.id }) { cell.apply(stream) }
            }
        }
        if streams.isEmpty && view.window != nil { close() }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { streams.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AudioMixerRow.reuseID, for: indexPath) as! AudioMixerRow
        cell.apply(streams[indexPath.row])
        cell.onVolume = { [weak self] id, value in self?.onVolume?(id, value); self?.refresh() }
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let stream = streams[indexPath.row]
        guard stream.isAvailable else { return }
        onMute?(stream.id, !stream.isMuted)
        refresh()
    }
    func indexPathForPreferredFocusedView(in tableView: UITableView) -> IndexPath? {
        let id = lastFocusedID ?? selectedStreamID
        let index = streams.firstIndex { $0.id == id && $0.isAvailable } ?? streams.firstIndex { $0.isAvailable }
        return index.map { IndexPath(row: $0, section: 0) }
    }
    func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let index = context.nextFocusedIndexPath, streams.indices.contains(index.row) { lastFocusedID = streams[index.row].id }
    }
    @objc private func togglePlayback() { onPlayPause?() }
    private func notifyDismissal() {
        guard !notifiedDismissal else { return }
        notifiedDismissal = true
        onDismiss?()
    }
    @objc func close() {
        guard !isClosing else { return }
        isClosing = true
        dismiss(animated: true) { [weak self] in self?.notifyDismissal() }
    }
}

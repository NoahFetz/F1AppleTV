#if canImport(F1Core)
import F1Core
#endif
//
//  ControlStripOverlayViewController.swift
//  F1A-TV
//
//  Created by Noah Fetz on 07.04.21.
//

import UIKit
import AVKit

class ControlStripOverlayViewController: BaseViewController {
    @IBOutlet weak var contentStackView: UIStackView!

    var controlsBarView: UIStackView?

    weak var controlStripActionProtocol: ControlStripActionProtocol?
    var playerItem: PlayerItem?
    var playerCount: Int = 1
    var onDismiss: (() -> Void)?

    var removeChannelButton: UIButton?
    var addChannelButton: UIButton?
    var swapToMainButton: UIButton?
    var audioMixerButton: UIButton?
    var enterFullScreenButton: UIButton?
    var rewindButton: UIButton?
    var playPauseButton: UIButton?
    var forwardButton: UIButton?
    var languageSelectorButton: UIButton?
    var captionSelectorButton: UIButton?
    var resolutionSelectorButton: UIButton?
    private var lastFocusedControl: UIView?
    private var hasFocusedControls = false
    private var liveButton: UIButton?
    var isLiveSession = false
    private var resolutionObserver: NSObjectProtocol?
    private var mediaMenuTask: Task<Void, Never>?

    private var titleLabel: UILabel?
    private var subtitleLabel: UILabel?
    private var editingLabel: UILabel?
    private var elapsedTimeLabel: UILabel?
    private var remainingTimeLabel: UILabel?
    private(set) var timelineSlider: RemoteTimelineControl?
    private var timelineStackView: UIStackView?
    private var scrubPreviewView: UIView?
    private var scrubPreviewImageView: UIImageView?
    private var scrubPreviewVideoView: ScrubVideoPreviewView?
    private var scrubPreviewTimeLabel: UILabel?
    private var scrubPreviewStatusLabel: UILabel?
    private var scrubPreviewSpinner: UIActivityIndicatorView?
    private var scrubPreviewCenterXConstraint: NSLayoutConstraint?
    private var scrubPreviewHideTimer: Timer?
    private var thumbnailProvider: StreamThumbnailProvider?
    private var previewImageRequestId: UUID?
    private var requestedPreviewTime: Double?
    private var timeObserverToken: Any?
    private var timelineStartTime: Float64 = 0
    private var timelineDuration: Float64 = 0
    private var hasNotifiedDismissal = false
    private(set) var transport = MultiviewTransportState()
    private var scrubSession: MultiviewScrubSession?
    private var scanTimer: Timer?
    private var scanTick: CFTimeInterval = 0
    private var refreshTimer: Timer?
    private var observedPlayer: AVPlayer?
    private var timelineReferenceID: String?
    private var backgroundObserver: NSObjectProtocol?

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if let lastFocusedControl, lastFocusedControl.window != nil { return [lastFocusedControl] }
        if let playPauseButton = playPauseButton {
            return [playPauseButton]
        }

        return super.preferredFocusEnvironments
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupViewController()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if context.previouslyFocusedView === timelineSlider && context.nextFocusedView !== timelineSlider {
            cancelTimelinePreview()
        }
        if hasFocusedControls, let next = context.nextFocusedView, next.isDescendant(of: view) {
            lastFocusedControl = next
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasFocusedControls {
            hasFocusedControls = true
            DispatchQueue.main.async { [weak self] in self?.focusControl(self?.playPauseButton) }
        }
        if timeObserverToken == nil { addPeriodicTimeObserver() }
        observeThumbnailState()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateTimeline() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelTimelinePreview()
        refreshTimer?.invalidate(); refreshTimer = nil
        if isBeingDismissed { notifyDismissal() }
        self.removeTimeObserver()
        self.previewImageRequestId = nil
        self.thumbnailProvider?.onNativeState = nil
        self.thumbnailProvider?.suspend()
        self.scrubPreviewVideoView?.install(nil)
        self.scrubPreviewView?.isHidden = true
        self.scrubPreviewView?.alpha = 0
        self.scrubPreviewImageView?.isHidden = true
        self.scrubPreviewVideoView?.isHidden = true
        self.setPreviewStatus(nil)
        self.scrubPreviewHideTimer?.invalidate()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if self.isBeingDismissed || presentingViewController == nil {
            self.notifyDismissal()
        }
    }

    deinit {
        mediaMenuTask?.cancel()
        scanTimer?.invalidate()
        refreshTimer?.invalidate()
        if let observer = backgroundObserver { NotificationCenter.default.removeObserver(observer) }
        if let observer = resolutionObserver { NotificationCenter.default.removeObserver(observer) }
        self.removeTimeObserver()
    }

    func initialize(playerItem: PlayerItem, playerCount: Int, controlStripActionProtocol: ControlStripActionProtocol, isLiveSession: Bool, onDismiss: @escaping () -> Void) {
        self.controlStripActionProtocol = controlStripActionProtocol
        self.playerItem = playerItem
        self.playerCount = playerCount
        self.isLiveSession = isLiveSession
        self.onDismiss = onDismiss
    }

    func setupViewController() {
        self.view.backgroundColor = UIColor.black.withAlphaComponent(0.12)

        let back = UITapGestureRecognizer(target: self, action: #selector(self.backPressed))
        back.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        self.view.addGestureRecognizer(back)
        backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.cancelTimelinePreview(restorePlayback: false) }
        }

        let playPauseGesture = UITapGestureRecognizer(target: self, action: #selector(self.playPausePressed))
        playPauseGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        self.view.addGestureRecognizer(playPauseGesture)

        self.setupOverlayLayout()
        self.addPeriodicTimeObserver()
        if let player = self.playerItem?.player {
            self.resolutionObserver = NotificationCenter.default.addObserver(forName: FairPlayer.resolutionDidChange, object: player, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self = self else { return }
                    self.updateResolutionMenu()
                    self.previewImageRequestId = nil
                    self.scrubPreviewImageView?.image = nil
                    self.scrubPreviewImageView?.isHidden = true
                    self.hideScrubPreview()
                    self.updateTimeline()
                }
            }
        }
    }

    private func observeThumbnailState() {
        self.thumbnailProvider?.onNativeState = { [weak self] state in
            guard let self, self.previewImageRequestId != nil else { return }
            switch state {
            case .loading(let layer): self.showNativePreview(layer, loading: true)
            case .ready(let layer): self.showNativePreview(layer, loading: false)
            case .unavailable:
                self.scrubPreviewVideoView?.install(nil)
                self.scrubPreviewVideoView?.isHidden = true
                self.setPreviewStatus("Preview unavailable")
            case .idle: break
            }
        }
    }

    func setupOverlayLayout() {
        self.contentStackView.arrangedSubviews.forEach({ $0.removeFromSuperview() })
        self.contentStackView.axis = .vertical
        self.contentStackView.alignment = .fill
        self.contentStackView.distribution = .fill
        self.contentStackView.spacing = 22
        self.contentStackView.layoutMargins = UIEdgeInsets(top: 42, left: 64, bottom: 42, right: 64)
        self.contentStackView.isLayoutMarginsRelativeArrangement = true

        self.setupMetadataHeader()

        let spaceTakingView = UIView()
        spaceTakingView.backgroundColor = .clear
        self.contentStackView.addArrangedSubview(spaceTakingView)

        self.setupControlPanel()
        self.updateTimeline()
    }

    func setupMetadataHeader() {
        let headerStackView = UIStackView()
        headerStackView.axis = .vertical
        headerStackView.alignment = .leading
        headerStackView.spacing = 6

        let editingLabel = UILabel()
        editingLabel.text = "multiview_selected_stream".localizedString
        editingLabel.textColor = ConstantsUtil.brandingRed
        editingLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        editingLabel.backgroundShadow()

        let channelTitleLabel = UILabel()
        channelTitleLabel.text = self.playerItem?.player?.playbackMetadata?.title ?? self.playerItem?.contentItem.title
        channelTitleLabel.textColor = .white
        channelTitleLabel.font = UIFont.preferredFont(forTextStyle: .title1)
        channelTitleLabel.adjustsFontForContentSizeCategory = true
        channelTitleLabel.numberOfLines = 2
        channelTitleLabel.lineBreakMode = .byTruncatingTail
        channelTitleLabel.backgroundShadow()

        let channelSubtitleLabel = UILabel()
        channelSubtitleLabel.text = self.playerItem?.player?.playbackMetadata?.subtitle ?? self.channelSubtitle()
        channelSubtitleLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        channelSubtitleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        channelSubtitleLabel.adjustsFontForContentSizeCategory = true
        channelSubtitleLabel.numberOfLines = 2
        channelSubtitleLabel.lineBreakMode = .byTruncatingTail
        channelSubtitleLabel.backgroundShadow()
        channelSubtitleLabel.isHidden = channelSubtitleLabel.text?.isEmpty ?? true

        self.titleLabel = channelTitleLabel
        self.subtitleLabel = channelSubtitleLabel
        self.editingLabel = editingLabel

        headerStackView.addArrangedSubview(editingLabel)
        headerStackView.addArrangedSubview(channelTitleLabel)
        headerStackView.addArrangedSubview(channelSubtitleLabel)
        self.contentStackView.addArrangedSubview(headerStackView)
    }

    func setupControlPanel() {
        let blurBackgroundView = PlayerMaterial.makeView(cornerRadius: 28)
        blurBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        blurBackgroundView.layer.cornerRadius = 28
        blurBackgroundView.clipsToBounds = true
        blurBackgroundView.backgroundShadow()

        NSLayoutConstraint.activate([
            blurBackgroundView.heightAnchor.constraint(equalToConstant: 286)
        ])

        let panelStackView = UIStackView()
        panelStackView.axis = .vertical
        panelStackView.alignment = .fill
        panelStackView.distribution = .fill
        panelStackView.spacing = 18
        panelStackView.translatesAutoresizingMaskIntoConstraints = false

        blurBackgroundView.contentView.addSubview(panelStackView)
        NSLayoutConstraint.activate([
            panelStackView.leadingAnchor.constraint(equalTo: blurBackgroundView.contentView.leadingAnchor, constant: 36),
            panelStackView.trailingAnchor.constraint(equalTo: blurBackgroundView.contentView.trailingAnchor, constant: -36),
            panelStackView.topAnchor.constraint(equalTo: blurBackgroundView.contentView.topAnchor, constant: 26),
            panelStackView.bottomAnchor.constraint(equalTo: blurBackgroundView.contentView.bottomAnchor, constant: -26)
        ])

        panelStackView.addArrangedSubview(self.makeSessionActions())
        panelStackView.addArrangedSubview(self.makeTimelineStackView())

        self.controlsBarView = UIStackView()
        self.controlsBarView?.axis = .horizontal
        self.controlsBarView?.alignment = .center
        self.controlsBarView?.distribution = .fill
        self.controlsBarView?.spacing = 18

        panelStackView.addArrangedSubview(self.controlsBarView ?? UIView())
        self.addContentToControlsBar()

        self.contentStackView.addArrangedSubview(blurBackgroundView)
        self.setupScrubPreview(above: blurBackgroundView)
    }

    private func makeSessionActions() -> UIStackView {
        let actions = UIStackView()
        actions.axis = .horizontal
        actions.alignment = .center
        actions.spacing = 18
        actions.addArrangedSubview(makeSessionButton(title: "layouts".localizedString, symbol: "rectangle.3.group") { [weak self] in
            self?.controlStripActionProtocol?.showLayoutPicker()
        })
        actions.addArrangedSubview(makeSessionButton(title: "saved_setups".localizedString, symbol: "bookmark") { [weak self] in
            self?.controlStripActionProtocol?.showSetupPicker()
        })
        actions.addArrangedSubview(makeSessionButton(title: "restart_streams".localizedString, symbol: "arrow.clockwise") { [weak self] in
            guard let self else { return }
            self.dismiss(animated: true) { [weak self] in
                self?.notifyDismissal()
                self?.controlStripActionProtocol?.restartStreams()
            }
        })
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        actions.addArrangedSubview(spacer)
        let scope = UILabel()
        scope.text = "multiview_all_streams".localizedString
        scope.font = .systemFont(ofSize: 22, weight: .medium)
        scope.textColor = UIColor.white.withAlphaComponent(0.8)
        actions.addArrangedSubview(scope)
        return actions
    }

    private func makeSessionButton(title: String, symbol: String, action: @escaping () -> Void) -> UIButton {
        // The panel supplies the glass material, just as it does for transport controls.
        // Native buttons supply focus highlighting without another opaque pill.
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .medium))
        configuration.imagePadding = 12
        configuration.baseForegroundColor = .white
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .systemFont(ofSize: 24, weight: .medium)
            return attributes
        }
        let button = UIButton(configuration: configuration, primaryAction: UIAction { _ in action() })
        button.tintColor = .white
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }

    func makeTimelineStackView() -> UIStackView {
        let timelineStackView = UIStackView()
        timelineStackView.axis = .horizontal
        timelineStackView.alignment = .center
        timelineStackView.distribution = .fill
        timelineStackView.spacing = 18

        let elapsedLabel = self.makeTimeLabel(text: "--:--", alignment: .left)
        let remainingLabel = self.makeTimeLabel(text: "--:--", alignment: .right)

        let slider = RemoteTimelineControl()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.value = 0
        slider.onStep = { [weak self] in self?.timelineStep($0) }
        slider.onHold = { [weak self] in self?.timelineHold($0) }
        slider.onPanSeconds = { [weak self] in self?.timelinePan(seconds: $0) }
        slider.onConfirm = { [weak self] in self?.playPausePressed() }
        slider.accessibilityLabel = "multiview_playback_position".localizedString

        NSLayoutConstraint.activate([
            elapsedLabel.widthAnchor.constraint(equalToConstant: 112),
            remainingLabel.widthAnchor.constraint(equalToConstant: 112),
            slider.heightAnchor.constraint(equalToConstant: 60)
        ])

        self.elapsedTimeLabel = elapsedLabel
        self.remainingTimeLabel = remainingLabel
        self.timelineSlider = slider
        self.timelineStackView = timelineStackView

        timelineStackView.addArrangedSubview(elapsedLabel)
        timelineStackView.addArrangedSubview(slider)
        timelineStackView.addArrangedSubview(remainingLabel)
        if isLiveSession {
            let button = UIButton(type: .system)
            button.tintColor = .white
            button.setTitle("go_live".localizedString, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 24, weight: .semibold)
            button.addAction(UIAction { [weak self] _ in self?.controlStripActionProtocol?.goLive() }, for: .primaryActionTriggered)
            timelineStackView.addArrangedSubview(button); liveButton = button
        }

        return timelineStackView
    }

    func addContentToControlsBar() {
        self.controlsBarView?.arrangedSubviews.forEach({ $0.removeFromSuperview() })

        if self.playerCount > 1, self.playerItem?.position != 0 { self.setupSwapToMainButton() }
        self.setupFullScreenButton()
        self.setupAddChannelButton()
        self.setupRemoveChannelButton()

        self.setupFlexibleSpacerView()

        self.setupRewindButton()
        self.setupPlayPauseButton()
        self.setupForwardButton()

        self.setupFlexibleSpacerView()

        self.setupAudioMixerButton()
        self.setupLanguageSelectorButton()
        self.setupCaptionSelectorButton()
        self.setupResolutionSelectorButton()
    }

    func setupFlexibleSpacerView() {
        let spacerView = UIView()
        spacerView.backgroundColor = .clear
        spacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        self.controlsBarView?.addArrangedSubview(spacerView)
    }

    func setupRewindButton() {
        self.rewindButton = self.makeControlButton(normalSymbolName: "gobackward.10", focusedSymbolName: "gobackward.10", accessibilityLabel: "Rewind 10 seconds")
        self.rewindButton?.addTarget(self, action: #selector(self.rewindPressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.rewindButton ?? UIView())
    }

    func setupPlayPauseButton() {
        self.playPauseButton = self.makeControlButton(normalSymbolName: "pause.fill", focusedSymbolName: "pause.fill", accessibilityLabel: "Play or pause", pointSize: 38)
        self.updatePlayPauseButtonStatus(paused: self.controlStripActionProtocol?.transportIsPlaying != true)
        self.playPauseButton?.addTarget(self, action: #selector(self.playPausePressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.playPauseButton ?? UIView())
    }

    func updatePlayPauseButtonStatus(paused: Bool) {
        let symbolName = paused ? "play.fill" : "pause.fill"
        let image = UIImage(systemName: symbolName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 38, weight: .semibold))
        self.playPauseButton?.setImage(image, for: .normal)
        self.playPauseButton?.setImage(image, for: .focused)
    }

    func setupForwardButton() {
        self.forwardButton = self.makeControlButton(normalSymbolName: "goforward.10", focusedSymbolName: "goforward.10", accessibilityLabel: "Forward 10 seconds")
        self.forwardButton?.addTarget(self, action: #selector(self.forwardPressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.forwardButton ?? UIView())
    }

    func setupRemoveChannelButton() {
        self.removeChannelButton = self.makeControlButton(normalSymbolName: "xmark", focusedSymbolName: "xmark", accessibilityLabel: "Remove channel")
        self.removeChannelButton?.addTarget(self, action: #selector(self.removeChannelPressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.removeChannelButton ?? UIView())
    }

    func setupAddChannelButton() {
        self.addChannelButton = self.makeControlButton(normalSymbolName: "plus", focusedSymbolName: "plus", accessibilityLabel: "Add channel")
        self.addChannelButton?.addTarget(self, action: #selector(self.addChannelPressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.addChannelButton ?? UIView())
    }

    func setupSwapToMainButton() {
        self.swapToMainButton = self.makeControlButton(normalSymbolName: "arrow.up.arrow.down", focusedSymbolName: "arrow.up.arrow.down", accessibilityLabel: "Swap to main")
        self.swapToMainButton?.addTarget(self, action: #selector(self.swapToMainPressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.swapToMainButton ?? UIView())
    }

    func setupAudioMixerButton() {
        let button = self.makeControlButton(normalSymbolName: "speaker.wave.2.fill", focusedSymbolName: "speaker.wave.2.fill", accessibilityLabel: "multiview_audio_mixer_title".localizedString)
        button.accessibilityIdentifier = "multiview.audioMixer"
        button.addTarget(self, action: #selector(showAudioMixer), for: .primaryActionTriggered)
        audioMixerButton = button
        controlsBarView?.addArrangedSubview(button)
    }

    @objc func showAudioMixer() {
        cancelTimelinePreview()
        focusControl(audioMixerButton)
        let mixer = AudioMixerViewController()
        mixer.modalPresentationStyle = .overCurrentContext
        mixer.selectedStreamID = playerItem?.id
        mixer.snapshot = { [weak self] in self?.controlStripActionProtocol?.audioMixSnapshot() ?? [] }
        mixer.onVolume = { [weak self] id, volume in self?.controlStripActionProtocol?.setStreamVolume(id: id, volume: volume) }
        mixer.onMute = { [weak self] id, muted in self?.controlStripActionProtocol?.setStreamMuted(id: id, muted: muted) }
        mixer.onPlayPause = { [weak self] in self?.controlStripActionProtocol?.playPausePlayer() }
        mixer.onDismiss = { [weak self] in
            DispatchQueue.main.async { [weak self] in self?.focusControl(self?.audioMixerButton) }
        }
        lastFocusedControl = audioMixerButton
        present(mixer, animated: true)
    }

    func setupLanguageSelectorButton() {
        self.languageSelectorButton = self.makeControlButton(normalSymbolName: "ear", focusedSymbolName: "ear.fill", accessibilityLabel: "Audio language")
        self.languageSelectorButton?.addTarget(self, action: #selector(self.languageSelectPressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.languageSelectorButton ?? UIView())
    }

    func setupCaptionSelectorButton() {
        self.captionSelectorButton = self.makeControlButton(normalSymbolName: "captions.bubble", focusedSymbolName: "captions.bubble.fill", accessibilityLabel: "Captions")
        self.captionSelectorButton?.addTarget(self, action: #selector(self.captionSelectPressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.captionSelectorButton ?? UIView())
    }

    func setupFullScreenButton() {
        self.enterFullScreenButton = self.makeControlButton(normalSymbolName: "arrow.up.left.and.arrow.down.right", focusedSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityLabel: "Fullscreen")
        self.enterFullScreenButton?.addTarget(self, action: #selector(self.enterFullScreenPressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.enterFullScreenButton ?? UIView())
    }

    func setupResolutionSelectorButton() {
        let button = self.makeControlButton(normalSymbolName: "slider.horizontal.3", focusedSymbolName: "slider.horizontal.3", accessibilityLabel: "Resolution")
        button.showsMenuAsPrimaryAction = true
        self.resolutionSelectorButton = button
        self.updateResolutionMenu()
        self.controlsBarView?.addArrangedSubview(button)
    }

    func updateResolutionMenu() {
        guard let player = self.playerItem?.player else { return }
        self.resolutionSelectorButton?.menu = player.resolutionMenu()
        let value = player.selectedResolution?.label(in: player.availableResolutions) ?? "Default"
        self.resolutionSelectorButton?.accessibilityValue = value
    }

    func makeControlButton(normalSymbolName: String, focusedSymbolName: String, accessibilityLabel: String, pointSize: CGFloat = 28) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        button.setImage(UIImage(systemName: normalSymbolName, withConfiguration: configuration), for: .normal)
        button.setImage(UIImage(systemName: focusedSymbolName, withConfiguration: configuration), for: .focused)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        button.layer.cornerRadius = 34
        button.clipsToBounds = true
        button.accessibilityLabel = accessibilityLabel
        button.imageView?.contentMode = .scaleAspectFit
        button.backgroundColor = .clear
        button.layer.cornerRadius = 0
        button.clipsToBounds = false
        var buttonConfiguration = UIButton.Configuration.plain()
        buttonConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        buttonConfiguration.baseForegroundColor = .white
        button.configuration = buttonConfiguration
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 68),
            button.heightAnchor.constraint(equalToConstant: 68)
        ])

        return button
    }

    func makeTimeLabel(text: String, alignment: NSTextAlignment) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.textColor = UIColor.white.withAlphaComponent(0.82)
        label.textAlignment = alignment
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 26, weight: .medium)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        return label
    }

    func channelSubtitle() -> String {
        guard let additionalStream = self.playerItem?.contentItem.channel else {
            return ""
        }

        return additionalStream.teamName
    }

    @objc func removeChannelPressed() {
        if let playerId = self.playerItem?.id {
            self.controlStripActionProtocol?.willClosePlayer(id: playerId)
        }
        self.swipeDownRegognized()
    }

    @objc func addChannelPressed() {
        self.swipeDownRegognized()
        self.controlStripActionProtocol?.showChannelSelectorOverlay()
    }

    @objc func swapToMainPressed() {
        if let playerId = self.playerItem?.id {
            self.controlStripActionProtocol?.swapToMainPlayer(id: playerId)
        }
        self.swipeDownRegognized()
    }

    func timelineStep(_ direction: TransportDirection) {
        updateTimeline()
        guard timelineDuration > 0 else { return }
        if transport.phase == .scanning {
            if transport.changeScanSpeed(direction) { commitTimelinePreview() }
            else { renderTimelineTarget() }
            return
        }
        let playing = controlStripActionProtocol?.transportIsPlaying ?? false
        if !playing, !ensurePreviewSession() { return }
        transport.step(direction, playing: playing)
        if transport.isPreviewing { renderTimelineTarget() }
        else if let target = transport.target {
            controlStripActionProtocol?.seekPlayersTo(time: target)
            renderTimelineTarget()
        }
    }

    func timelinePan(seconds: Double) {
        guard seconds != 0, controlStripActionProtocol?.transportIsPlaying != true || transport.isPreviewing else { return }
        guard ensurePreviewSession() else { return }
        scanTimer?.invalidate(); scanTimer = nil
        transport.pan(seconds: seconds)
        renderTimelineTarget()
    }

    func timelineHold(_ direction: TransportDirection) {
        updateTimeline()
        guard ensurePreviewSession() else { return }
        transport.startScan(direction)
        scanTimer?.invalidate()
        scanTick = CACurrentMediaTime()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let now = CACurrentMediaTime()
                self.transport.advanceScan(seconds: now - self.scanTick)
                self.scanTick = now
                self.renderTimelineTarget()
                if self.transport.phase != .scanning { self.scanTimer?.invalidate(); self.scanTimer = nil }
            }
        }
        scanTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        renderTimelineTarget()
    }

    private func ensurePreviewSession() -> Bool {
        guard timelineDuration > 0 else { return false }
        if scrubSession == nil { scrubSession = controlStripActionProtocol?.beginTransportPreview() }
        if scrubSession != nil { focusControl(timelineSlider) }
        return scrubSession != nil
    }

    func focusControl(_ control: UIView?) {
        guard let control, control.window != nil else { return }
        lastFocusedControl = control
        setNeedsFocusUpdate(); updateFocusIfNeeded()
        let system = UIFocusSystem.focusSystem(for: control)
        system?.requestFocusUpdate(to: control)
        system?.updateFocusIfNeeded()
    }

    func commitTimelinePreview() {
        guard let session = scrubSession, let time = transport.target else { return }
        scanTimer?.invalidate(); scanTimer = nil
        scrubSession = nil
        transport.markSeeking()
        controlStripActionProtocol?.commitTransportPreview(session, time: time)
        hideScrubPreview()
        updateTimeline()
    }

    @discardableResult
    func cancelTimelinePreview(restorePlayback: Bool = true) -> Bool {
        let hadPreview = scrubSession != nil || transport.isPreviewing
        guard hadPreview else { return false }
        scanTimer?.invalidate(); scanTimer = nil
        if let session = scrubSession { controlStripActionProtocol?.cancelTransportPreview(session, restorePlayback: restorePlayback) }
        scrubSession = nil
        transport.cancel()
        hideScrubPreview()
        return true
    }

    private func renderTimelineTarget() {
        guard timelineDuration > 0 else { return }
        let progress = Float((transport.displayTime - timelineStartTime) / timelineDuration)
        timelineSlider?.value = min(max(progress, 0), 1)
        timelineSlider?.accessibilityValue = formatTime(max(0, transport.displayTime - timelineStartTime))
        updateTimelineLabels(currentTime: transport.displayTime)
        if transport.isPreviewing { showScrubPreview(at: transport.displayTime, sliderValue: progress) }
    }

    @objc func backPressed() {
        if cancelTimelinePreview() { updateTimeline(); return }
        swipeDownRegognized()
    }

    @objc func enterFullScreenPressed() {
        if let playerId = self.playerItem?.id {
            self.controlStripActionProtocol?.enterFullScreenPlayer(id: playerId)
        }
        self.swipeDownRegognized()
    }

    @objc func rewindPressed() {
        timelineStep(.backward)
    }

    @objc func playPausePressed() {
        if transport.isPreviewing { commitTimelinePreview(); return }
        self.controlStripActionProtocol?.playPausePlayer()
        self.updateTimeline()
        if controlStripActionProtocol?.transportIsPlaying == false {
            focusControl(timelineSlider)
        }
    }

    @objc func forwardPressed() {
        timelineStep(.forward)
    }

    @objc func languageSelectPressed() { showMediaSelectMenu(type: .audio) }

    @objc func captionSelectPressed() { showMediaSelectMenu(type: .subtitle) }

    private func showMediaSelectMenu(type: AVPlayerItem.TrackType) {
        mediaMenuTask?.cancel()
        guard let item = playerItem?.player?.currentItem else { return }
        mediaMenuTask = Task { @MainActor [weak self] in
            do {
                let tracks = try await item.tracks(type: type)
                guard let self, !Task.isCancelled, self.playerItem?.player?.currentItem === item,
                      self.viewIfLoaded?.window != nil else { return }
                let alert = UIAlertController(title: "select".localizedString, message: nil, preferredStyle: .alert)
                for track in tracks {
                    alert.addAction(UIAlertAction(title: track.displayName, style: .default) { [weak self] _ in
                        guard self?.playerItem?.player?.currentItem === item else { return }
                        // Overrides affect only this stream, never the startup defaults.
                        item.select(track: track)
                    })
                }
                alert.addAction(UIAlertAction(title: "cancel".localizedString, style: .cancel))
                UserInteractionHelper.instance.getPresentingViewController()?.present(alert, animated: true)
            } catch {
                guard let self, !Task.isCancelled, !(error is CancellationError),
                      self.playerItem?.player?.currentItem === item, self.viewIfLoaded?.window != nil else { return }
                UserInteractionHelper.instance.showError(title: "error".localizedString, message: "diagnostics_summary_operation".localizedString)
            }
        }
    }

    @objc func swipeDownRegognized() {
        cancelTimelinePreview()
        self.dismiss(animated: true) { [weak self] in
            self?.notifyDismissal()
        }
    }

    func notifyDismissal() {
        mediaMenuTask?.cancel()
        guard !self.hasNotifiedDismissal else { return }
        self.hasNotifiedDismissal = true
        self.onDismiss?()
    }
}

// MARK: - Scrub Preview
extension ControlStripOverlayViewController {
    func setupScrubPreview(above controlPanel: UIView) {
        let previewView = UIView()
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.backgroundColor = .clear
        previewView.alpha = 0
        previewView.isHidden = true
        previewView.backgroundShadow()

        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = .clear
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        imageView.layer.borderWidth = 1
        imageView.isHidden = true

        let timeMaterial = PlayerMaterial.makeView(cornerRadius: 22)
        timeMaterial.translatesAutoresizingMaskIntoConstraints = false

        let timeLabel = UILabel()
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.textColor = .white
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .bold)
        timeLabel.textAlignment = .center
        timeLabel.adjustsFontSizeToFitWidth = true
        timeLabel.minimumScaleFactor = 0.7
        timeLabel.backgroundColor = .clear

        let videoView = ScrubVideoPreviewView()
        videoView.translatesAutoresizingMaskIntoConstraints = false
        videoView.clipsToBounds = true
        videoView.layer.cornerRadius = 8
        videoView.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        videoView.layer.borderWidth = 1
        videoView.isHidden = true
        previewView.addSubview(imageView)
        previewView.addSubview(videoView)
        let statusLabel = UILabel()
        statusLabel.font = .systemFont(ofSize: 19)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.hidesWhenStopped = true
        let statusStack = UIStackView(arrangedSubviews: [spinner, statusLabel])
        statusStack.axis = .vertical; statusStack.spacing = 8
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusStack.isUserInteractionEnabled = false
        previewView.addSubview(statusStack)
        previewView.addSubview(timeMaterial)
        timeMaterial.contentView.addSubview(timeLabel)
        self.view.addSubview(previewView)

        let centerXConstraint = previewView.centerXAnchor.constraint(equalTo: self.view.leadingAnchor, constant: self.view.bounds.midX)
        NSLayoutConstraint.activate([
            previewView.widthAnchor.constraint(equalToConstant: 256),
            previewView.heightAnchor.constraint(equalToConstant: CredentialHelper.getPlayerSettings().scrubPreviews ? 196 : 44),
            centerXConstraint,
            previewView.bottomAnchor.constraint(equalTo: controlPanel.topAnchor, constant: -18),
            imageView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: previewView.topAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 144),
            videoView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            videoView.topAnchor.constraint(equalTo: imageView.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            statusStack.centerXAnchor.constraint(equalTo: videoView.centerXAnchor),
            statusStack.centerYAnchor.constraint(equalTo: videoView.centerYAnchor),
            timeMaterial.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            timeMaterial.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
            timeMaterial.widthAnchor.constraint(equalToConstant: 220),
            timeMaterial.heightAnchor.constraint(equalToConstant: 44),
            timeLabel.leadingAnchor.constraint(equalTo: timeMaterial.contentView.leadingAnchor, constant: 8),
            timeLabel.trailingAnchor.constraint(equalTo: timeMaterial.contentView.trailingAnchor, constant: -8),
            timeLabel.topAnchor.constraint(equalTo: timeMaterial.contentView.topAnchor),
            timeLabel.bottomAnchor.constraint(equalTo: timeMaterial.contentView.bottomAnchor)
        ])

        self.scrubPreviewView = previewView
        self.scrubPreviewImageView = imageView
        self.scrubPreviewVideoView = videoView
        self.scrubPreviewTimeLabel = timeLabel
        self.scrubPreviewStatusLabel = statusLabel
        self.scrubPreviewSpinner = spinner
        self.scrubPreviewCenterXConstraint = centerXConstraint
    }

    func showScrubPreview(at time: Float64, sliderValue: Float) {
        guard let scrubPreviewView = self.scrubPreviewView else { return }

        self.scrubPreviewHideTimer?.invalidate()
        self.scrubPreviewTimeLabel?.text = self.formatTime(max(0, time - self.timelineStartTime)) + (transport.scanLabel.map { "  " + $0 } ?? "")
        self.updateScrubPreviewPosition(for: sliderValue)

        if scrubPreviewView.isHidden {
            scrubPreviewView.isHidden = false
            scrubPreviewView.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            UIView.animate(withDuration: 0.16) {
                scrubPreviewView.alpha = 1
                scrubPreviewView.transform = .identity
            }
        }

        self.scheduleScrubPreviewHide(after: 18)
        self.requestScrubPreviewImage(at: time)
    }

    private func scheduleScrubPreviewHide(after delay: TimeInterval) {
        self.scrubPreviewHideTimer?.invalidate()
        guard !transport.isPreviewing else { return }
        self.scrubPreviewHideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.hideScrubPreview()
        }
    }

    func hideScrubPreview() {
        guard let scrubPreviewView = self.scrubPreviewView, !scrubPreviewView.isHidden else { return }

        self.previewImageRequestId = nil
        self.requestedPreviewTime = nil
        self.thumbnailProvider?.suspend()
        self.scrubPreviewVideoView?.install(nil)
        self.scrubPreviewVideoView?.isHidden = true
        self.scrubPreviewImageView?.isHidden = true
        self.setPreviewStatus(nil)
        UIView.animate(withDuration: 0.16, animations: {
            scrubPreviewView.alpha = 0
        }, completion: { [weak self] _ in
            guard self?.previewImageRequestId == nil else { return }
            scrubPreviewView.isHidden = true
            scrubPreviewView.transform = .identity
        })
    }

    func updateScrubPreviewPosition(for sliderValue: Float) {
        guard let slider = self.timelineSlider, let centerXConstraint = self.scrubPreviewCenterXConstraint else { return }

        self.view.layoutIfNeeded()
        let sliderFrame = slider.convert(slider.bounds, to: self.view)
        let proposedCenterX = sliderFrame.minX + (sliderFrame.width * CGFloat(sliderValue))
        let horizontalInset: CGFloat = 148
        centerXConstraint.constant = min(max(proposedCenterX, horizontalInset), self.view.bounds.width - horizontalInset)
        self.view.layoutIfNeeded()
    }

    func requestScrubPreviewImage(at time: Float64) {
        guard let thumbnailProvider else { self.scheduleScrubPreviewHide(after: 1.25); return }
        if requestedPreviewTime == time && previewImageRequestId != nil { return }
        requestedPreviewTime = time
        let requestId = UUID()
        self.previewImageRequestId = requestId
        if self.scrubPreviewVideoView?.isHidden != false && self.scrubPreviewImageView?.isHidden != false {
            self.setPreviewStatus("Loading preview…", loading: true)
        }
        thumbnailProvider.request(at: time) { [weak self] preview in
            guard let self = self, self.previewImageRequestId == requestId else { return }
            self.scrubPreviewImageView?.isHidden = true
            self.scrubPreviewVideoView?.isHidden = true
            switch preview {
            case .image(let image):
                self.setPreviewStatus(nil)
                self.scrubPreviewVideoView?.install(nil)
                self.scrubPreviewImageView?.image = UIImage(cgImage: image)
                self.scrubPreviewImageView?.isHidden = false
            case .video(let layer):
                self.showNativePreview(layer, loading: false)
            case nil:
                self.scrubPreviewVideoView?.install(nil)
                self.setPreviewStatus("Preview unavailable")
            }
            self.scheduleScrubPreviewHide(after: 1.25)
        }
    }

    private func showNativePreview(_ layer: AVPlayerLayer, loading: Bool) {
        scrubPreviewImageView?.isHidden = true
        scrubPreviewVideoView?.install(layer)
        scrubPreviewVideoView?.isHidden = false
        setPreviewStatus(loading ? "Loading preview…" : nil, loading: loading)
    }

    private func setPreviewStatus(_ text: String?, loading: Bool = false) {
        scrubPreviewStatusLabel?.text = text
        scrubPreviewStatusLabel?.isHidden = text == nil
        if loading { scrubPreviewSpinner?.startAnimating() } else { scrubPreviewSpinner?.stopAnimating() }
    }
}

// MARK: - Timeline
extension ControlStripOverlayViewController {
    func addPeriodicTimeObserver() {
        guard timeObserverToken == nil, let player = observedPlayer else { return }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            self?.updateTimeline()
        }
    }

    func removeTimeObserver() {
        guard let token = timeObserverToken else { return }
        observedPlayer?.removeTimeObserver(token)
        timeObserverToken = nil
    }

    private func bindTimelineReference(_ reference: PlayerItem?) {
        removeTimeObserver()
        thumbnailProvider?.onNativeState = nil
        thumbnailProvider?.suspend()
        timelineReferenceID = reference?.id
        observedPlayer = reference?.player
        thumbnailProvider = CredentialHelper.getPlayerSettings().scrubPreviews ? reference?.thumbnails : nil
        observeThumbnailState()
        addPeriodicTimeObserver()
    }

    func updateTimeline() {
        let reference = controlStripActionProtocol?.transportReference
        if timelineReferenceID != reference?.id || observedPlayer !== reference?.player {
            cancelTimelinePreview()
            bindTimelineReference(reference)
        }
        guard let reference, let player = reference.player else {
            transport.synchronize(referenceID: nil, position: 0, lower: 0, upper: 0, seeking: false)
            timelineSlider?.isEnabled = false
            return
        }
        if let range = player.currentItem?.seekableTimeRanges.last?.timeRangeValue {
            liveButton?.isEnabled = LiveTimeline.target(start: range.start.seconds, end: CMTimeRangeGetEnd(range).seconds) != nil
            liveButton?.setTitle((LiveTimeline.isAtLive(position: player.currentTime().seconds, end: CMTimeRangeGetEnd(range).seconds) ? "live_status" : "go_live").localizedString, for: .normal)
        } else { liveButton?.isEnabled = false }
        let seeking = controlStripActionProtocol?.isSeekingPlayer(id: reference.id) == true
        if !transport.isPreviewing && !(transport.phase == .seeking && seeking) {
            let bounds = timelineBounds(for: player)
            timelineStartTime = bounds.start
            timelineDuration = bounds.duration
        }
        transport.synchronize(referenceID: reference.id, position: player.currentTime().seconds,
                              lower: timelineStartTime, upper: max(timelineStartTime, timelineStartTime + timelineDuration - 0.1), seeking: seeking)
        timelineSlider?.isEnabled = timelineDuration > 0
        updatePlayPauseButtonStatus(paused: controlStripActionProtocol?.transportIsPlaying != true)
        if timelineDuration > 0 { renderTimelineTarget() }
        else { elapsedTimeLabel?.text = "--:--"; remainingTimeLabel?.text = "--:--" }
    }

    func updateTimelineLabels(currentTime: Float64) {
        let elapsed = max(0, currentTime - self.timelineStartTime)
        let remaining = max(0, self.timelineDuration - elapsed)

        self.elapsedTimeLabel?.text = self.formatTime(elapsed)
        self.remainingTimeLabel?.text = "-\(self.formatTime(remaining))"
    }

    func timelineBounds(for player: AVPlayer) -> (start: Float64, duration: Float64) {
        if let duration = player.currentItem?.duration {
            let durationSeconds = CMTimeGetSeconds(duration)
            if durationSeconds.isFinite && durationSeconds > 0 {
                return (0, durationSeconds)
            }
        }

        if let seekableRange = player.currentItem?.seekableTimeRanges.last?.timeRangeValue {
            let start = CMTimeGetSeconds(seekableRange.start)
            let duration = CMTimeGetSeconds(seekableRange.duration)
            if start.isFinite && duration.isFinite && duration > 0 {
                return (start, duration)
            }
        }

        return (0, 0)
    }

    func formatTime(_ seconds: Float64) -> String {
        guard seconds.isFinite else { return "--:--" }

        let roundedSeconds = max(0, Int(seconds.rounded()))
        let hours = roundedSeconds / 3600
        let minutes = (roundedSeconds % 3600) / 60
        let seconds = roundedSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}

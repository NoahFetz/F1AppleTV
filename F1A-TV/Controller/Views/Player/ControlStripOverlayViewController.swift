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
    var muteChannelButton: UIButton?
    var volumeSlider: TvOSSlider?
    var enterFullScreenButton: UIButton?
    var rewindButton: UIButton?
    var playPauseButton: UIButton?
    var forwardButton: UIButton?
    var languageSelectorButton: UIButton?
    var captionSelectorButton: UIButton?
    var resolutionSelectorButton: UIButton?
    private var lastFocusedControl: UIView?
    private var liveButton: UIButton?
    var isLiveSession = false
    private var resolutionObserver: NSObjectProtocol?
    private var mediaMenuTask: Task<Void, Never>?

    private var titleLabel: UILabel?
    private var subtitleLabel: UILabel?
    private var editingLabel: UILabel?
    private var elapsedTimeLabel: UILabel?
    private var remainingTimeLabel: UILabel?
    private var timelineSlider: TvOSSlider?
    private var timelineStackView: UIStackView?
    private var scrubPreviewView: UIView?
    private var scrubPreviewImageView: UIImageView?
    private var scrubPreviewTimeLabel: UILabel?
    private var scrubPreviewCenterXConstraint: NSLayoutConstraint?
    private var scrubPreviewHideTimer: Timer?
    private var thumbnailProvider: StreamThumbnailProvider?
    private var previewImageRequestId: UUID?
    private var timeObserverToken: Any?
    private var timelineStartTime: Float64 = 0
    private var timelineDuration: Float64 = 0
    private var hasNotifiedDismissal = false

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if let lastFocusedControl, lastFocusedControl.window != nil { return [lastFocusedControl] }
        if let timelineSlider = timelineSlider {
            return [timelineSlider]
        }

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
        if let next = context.nextFocusedView, next.isDescendant(of: view) { lastFocusedControl = next }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if timeObserverToken == nil { addPeriodicTimeObserver() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed { notifyDismissal() }
        self.removeTimeObserver()
        self.thumbnailProvider?.cancel()
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

        let swipeDownRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeDownRegognized))
        swipeDownRecognizer.direction = .down
        self.view.addGestureRecognizer(swipeDownRecognizer)

        let playPauseGesture = UITapGestureRecognizer(target: self, action: #selector(self.playPausePressed))
        playPauseGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        self.view.addGestureRecognizer(playPauseGesture)

        self.setupOverlayLayout()
        self.addPeriodicTimeObserver()
        if let player = self.playerItem?.player {
            self.thumbnailProvider = StreamThumbnailProvider(player: player)
            self.resolutionObserver = NotificationCenter.default.addObserver(forName: FairPlayer.resolutionDidChange, object: player, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self = self else { return }
                    self.updateResolutionMenu()
                    self.thumbnailProvider?.cancel()
                    self.previewImageRequestId = nil
                    self.scrubPreviewImageView?.image = nil
                    self.scrubPreviewImageView?.isHidden = true
                    self.hideScrubPreview()
                    self.updateTimeline()
                }
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
        editingLabel.text = "EDITING SELECTED STREAM"
        editingLabel.textColor = ConstantsUtil.brandingRed
        editingLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        editingLabel.backgroundShadow()

        let channelTitleLabel = UILabel()
        channelTitleLabel.text = self.playerItem?.contentItem.title
        channelTitleLabel.textColor = .white
        channelTitleLabel.font = UIFont.preferredFont(forTextStyle: .title1)
        channelTitleLabel.adjustsFontForContentSizeCategory = true
        channelTitleLabel.backgroundShadow()

        let channelSubtitleLabel = UILabel()
        channelSubtitleLabel.text = self.channelSubtitle()
        channelSubtitleLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        channelSubtitleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        channelSubtitleLabel.adjustsFontForContentSizeCategory = true
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
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        actions.addArrangedSubview(spacer)
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

        let slider = TvOSSlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = 0
        slider.expectedLayoutWidth = 1200
        slider.stepValue = 1 / 120
        slider.focusScaleFactor = 1.04
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.28)
        slider.thumbTintColor = .white
        slider.addTarget(self, action: #selector(self.timelineSliderChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(self.timelineSeekingFinished), for: .editingDidEnd)

        NSLayoutConstraint.activate([
            elapsedLabel.widthAnchor.constraint(equalToConstant: 112),
            remainingLabel.widthAnchor.constraint(equalToConstant: 112),
            slider.heightAnchor.constraint(equalToConstant: 44)
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

        self.setupMuteButton()
        self.setupVolumeSlider()
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
        self.rewindButton = self.makeControlButton(normalSymbolName: "gobackward.15", focusedSymbolName: "gobackward.15", accessibilityLabel: "Rewind 15 seconds")
        self.rewindButton?.addTarget(self, action: #selector(self.rewindPressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.rewindButton ?? UIView())
    }

    func setupPlayPauseButton() {
        self.playPauseButton = self.makeControlButton(normalSymbolName: "pause.fill", focusedSymbolName: "pause.fill", accessibilityLabel: "Play or pause", pointSize: 38)
        self.updatePlayPauseButtonStatus(paused: self.playerItem?.player?.timeControlStatus == .paused)
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
        self.forwardButton = self.makeControlButton(normalSymbolName: "goforward.15", focusedSymbolName: "goforward.15", accessibilityLabel: "Forward 15 seconds")
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

    func setupMuteButton() {
        self.muteChannelButton = self.makeControlButton(normalSymbolName: "speaker.wave.2.fill", focusedSymbolName: "speaker.wave.2.fill", accessibilityLabel: "Mute channel")
        self.updateMuteButtonStatus()
        self.muteChannelButton?.addTarget(self, action: #selector(self.muteChannelPressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.muteChannelButton ?? UIView())
    }

    func setupVolumeSlider() {
        let sliderWidth: CGFloat = 220

        self.volumeSlider = TvOSSlider()
        self.volumeSlider?.translatesAutoresizingMaskIntoConstraints = false
        self.volumeSlider?.requiresSelectToAdjust = true
        self.volumeSlider?.stepValue = 1 / 16
        self.volumeSlider?.focusScaleFactor = 1.04
        self.volumeSlider?.minimumTrackTintColor = .white
        self.volumeSlider?.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.28)
        self.volumeSlider?.thumbTintColor = .white
        self.volumeSlider?.expectedLayoutWidth = sliderWidth
        self.volumeSlider?.value = self.playerItem?.player?.volume ?? 0

        NSLayoutConstraint.activate([
            (self.volumeSlider ?? UIView()).widthAnchor.constraint(equalToConstant: sliderWidth),
            (self.volumeSlider ?? UIView()).heightAnchor.constraint(equalToConstant: 44)
        ])

        self.volumeSlider?.addTarget(self, action: #selector(self.volumeSliderChanged), for: .valueChanged)
        self.volumeSlider?.adjustmentStateDidChange = { [weak self] isAdjusting in
            self?.updateVolumeAdjustmentPresentation(isAdjusting: isAdjusting)
        }
        self.controlsBarView?.addArrangedSubview(self.volumeSlider ?? UIView())
    }

    func updateVolumeAdjustmentPresentation(isAdjusting: Bool) {
        let inactiveAlpha: CGFloat = isAdjusting ? 0.42 : 1

        UIView.animate(withDuration: 0.18) {
            self.timelineStackView?.alpha = inactiveAlpha
            self.controlsBarView?.arrangedSubviews.forEach { view in
                if let volumeSlider = self.volumeSlider, view !== volumeSlider {
                    view.alpha = inactiveAlpha
                }
            }
        }
    }

    func updateMuteButtonStatus() {
        let symbolName = (self.playerItem?.player?.isMuted ?? true) ? "speaker.slash.fill" : "speaker.wave.2.fill"
        let image = UIImage(systemName: symbolName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold))
        self.muteChannelButton?.setImage(image, for: .normal)
        self.muteChannelButton?.setImage(image, for: .focused)
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

    @objc func muteChannelPressed() {
        let muted = !(self.playerItem?.player?.isMuted ?? false)
        self.playerItem?.player?.isMuted = muted
        self.updateMuteButtonStatus()

        var playerSettings = CredentialHelper.getPlayerSettings()
        playerSettings.setPreferredMute(for: self.playerItem?.contentItem.channelType ?? ChannelType(), mute: muted)
        CredentialHelper.setPlayerSettings(playerSettings: playerSettings)
    }

    @objc func volumeSliderChanged(slider: TvOSSlider) {
        let newVolume = slider.value
        self.playerItem?.player?.volume = newVolume

        var playerSettings = CredentialHelper.getPlayerSettings()
        playerSettings.setPreferredVolume(for: self.playerItem?.contentItem.channelType ?? ChannelType(), volume: newVolume)
        CredentialHelper.setPlayerSettings(playerSettings: playerSettings)

        print("Setting player volume to \(newVolume)")
    }

    @objc func timelineSliderChanged(slider: TvOSSlider) {
        guard self.timelineDuration > 0 else { return }

        let targetTime = self.timelineStartTime + (Float64(slider.value) * self.timelineDuration)
        self.controlStripActionProtocol?.seekPlayersTo(time: targetTime)
        self.updateTimelineLabels(currentTime: targetTime)
        self.showScrubPreview(at: targetTime, sliderValue: slider.value)
    }

    @objc func timelineSeekingFinished() {
        self.controlStripActionProtocol?.didFinishSeeking()
    }

    @objc func enterFullScreenPressed() {
        if let playerId = self.playerItem?.id {
            self.controlStripActionProtocol?.enterFullScreenPlayer(id: playerId)
        }
        self.swipeDownRegognized()
    }

    @objc func rewindPressed() {
        self.controlStripActionProtocol?.rewindPlayer()
        self.updateTimeline()
    }

    @objc func playPausePressed() {
        self.updatePlayPauseButtonStatus(paused: self.playerItem?.player?.timeControlStatus != .paused)
        self.controlStripActionProtocol?.playPausePlayer()
    }

    @objc func forwardPressed() {
        self.controlStripActionProtocol?.forwardPlayer()
        self.updateTimeline()
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
        timeLabel.backgroundColor = .clear

        previewView.addSubview(imageView)
        previewView.addSubview(timeMaterial)
        timeMaterial.contentView.addSubview(timeLabel)
        self.view.addSubview(previewView)

        let centerXConstraint = previewView.centerXAnchor.constraint(equalTo: self.view.leadingAnchor, constant: self.view.bounds.midX)
        NSLayoutConstraint.activate([
            previewView.widthAnchor.constraint(equalToConstant: 256),
            previewView.heightAnchor.constraint(equalToConstant: 196),
            centerXConstraint,
            previewView.bottomAnchor.constraint(equalTo: controlPanel.topAnchor, constant: -18),
            imageView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: previewView.topAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 144),
            timeMaterial.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            timeMaterial.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
            timeMaterial.widthAnchor.constraint(equalToConstant: 140),
            timeMaterial.heightAnchor.constraint(equalToConstant: 44),
            timeLabel.leadingAnchor.constraint(equalTo: timeMaterial.contentView.leadingAnchor, constant: 8),
            timeLabel.trailingAnchor.constraint(equalTo: timeMaterial.contentView.trailingAnchor, constant: -8),
            timeLabel.topAnchor.constraint(equalTo: timeMaterial.contentView.topAnchor),
            timeLabel.bottomAnchor.constraint(equalTo: timeMaterial.contentView.bottomAnchor)
        ])

        self.scrubPreviewView = previewView
        self.scrubPreviewImageView = imageView
        self.scrubPreviewTimeLabel = timeLabel
        self.scrubPreviewCenterXConstraint = centerXConstraint
    }

    func showScrubPreview(at time: Float64, sliderValue: Float) {
        guard let scrubPreviewView = self.scrubPreviewView else { return }

        self.scrubPreviewHideTimer?.invalidate()
        self.scrubPreviewTimeLabel?.text = self.formatTime(max(0, time - self.timelineStartTime))
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
        self.scrubPreviewHideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.hideScrubPreview()
        }
    }

    func hideScrubPreview() {
        guard let scrubPreviewView = self.scrubPreviewView, !scrubPreviewView.isHidden else { return }

        self.thumbnailProvider?.cancel()
        self.previewImageRequestId = nil
        UIView.animate(withDuration: 0.16, animations: {
            scrubPreviewView.alpha = 0
        }, completion: { _ in
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
        let requestId = UUID()
        self.previewImageRequestId = requestId
        self.thumbnailProvider?.request(at: time) { [weak self] image in
            guard let self = self, self.previewImageRequestId == requestId else { return }
            self.scrubPreviewImageView?.image = image
            self.scrubPreviewImageView?.isHidden = image == nil
            self.scheduleScrubPreviewHide(after: 1.25)
        }
    }
}

// MARK: - Timeline
extension ControlStripOverlayViewController {
    func addPeriodicTimeObserver() {
        guard let player = self.playerItem?.player else { return }

        self.removeTimeObserver()

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        self.timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            self?.updateTimeline()
        }
    }

    func removeTimeObserver() {
        guard let token = self.timeObserverToken else { return }

        self.playerItem?.player?.removeTimeObserver(token)
        self.timeObserverToken = nil
    }

    func updateTimeline() {
        guard let player = self.playerItem?.player else {
            self.timelineSlider?.isEnabled = false
            return
        }

        if let range = player.currentItem?.seekableTimeRanges.last?.timeRangeValue {
            liveButton?.isEnabled = LiveTimeline.target(start: range.start.seconds, end: CMTimeRangeGetEnd(range).seconds) != nil
            liveButton?.setTitle((LiveTimeline.isAtLive(position: player.currentTime().seconds, end: CMTimeRangeGetEnd(range).seconds) ? "live_status" : "go_live").localizedString, for: .normal)
        } else { liveButton?.isEnabled = false }
        let bounds = self.timelineBounds(for: player)
        self.timelineStartTime = bounds.start
        self.timelineDuration = bounds.duration

        guard bounds.duration > 0 else {
            self.timelineSlider?.isEnabled = false
            self.elapsedTimeLabel?.text = "--:--"
            self.remainingTimeLabel?.text = "--:--"
            return
        }

        self.timelineSlider?.isEnabled = true
        self.timelineSlider?.stepValue = Float(15 / bounds.duration)

        let currentTime = CMTimeGetSeconds(player.currentTime())
        let progress = Float((currentTime - bounds.start) / bounds.duration)
        self.timelineSlider?.value = min(max(progress, 0), 1)
        self.updateTimelineLabels(currentTime: currentTime)
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

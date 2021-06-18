//
//  ControlStripOverlayViewController.swift
//  F1A-TV
//
//  Created by Noah Fetz on 07.04.21.
//

import UIKit

class ControlStripOverlayViewController: BaseViewController {
    @IBOutlet weak var contentStackView: UIStackView!
    var controlsBarView: UIStackView?
    
    var controlStripActionProtocol: ControlStripActionProtocol?
    var playerItem: PlayerItem?
    
    var removeChannelButton: UIButton?
    var muteChannelButton: UIButton?
    var volumeSlider: TvOSSlider?
    var enterFullScreenButton: UIButton?
    var rewindButton: UIButton?
    var playPauseButton: UIButton?
    var forwardButton: UIButton?
    var languageSelectorButton: UIButton?
    var captionSelectorButton: UIButton?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupViewController()
    }
    
    func initialize(playerItem: PlayerItem, controlStripActionProtocol: ControlStripActionProtocol) {
        self.controlStripActionProtocol = controlStripActionProtocol
        self.playerItem = playerItem
    }
    
    func setupViewController() {
        self.view.backgroundColor = .clear
        
        let swipeDownRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeDownRegognized))
        swipeDownRecognizer.direction = .down
        self.view.addGestureRecognizer(swipeDownRecognizer)
        
        let playPauseGesture = UITapGestureRecognizer(target: self, action: #selector(self.playPausePressed))
        playPauseGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        self.view.addGestureRecognizer(playPauseGesture)
        
        self.setupControlBar()
        self.addContentToControlsBar()
    }
    
    func setupControlBar() {
        self.contentStackView.arrangedSubviews.forEach({$0.removeFromSuperview()})
        
        let spaceTakingView = UIView()
        spaceTakingView.backgroundColor = .clear
        self.contentStackView.addArrangedSubview(spaceTakingView)
        
        let blurBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        blurBackgroundView.layer.cornerRadius = 20
        blurBackgroundView.clipsToBounds = true
        NSLayoutConstraint.activate([
            blurBackgroundView.heightAnchor.constraint(equalToConstant: 150)
        ])
        
        self.controlsBarView = UIStackView()
        self.controlsBarView?.axis = .horizontal
        self.controlsBarView?.distribution = .equalSpacing
        self.controlsBarView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.controlsBarView?.layoutMargins = UIEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)
        self.controlsBarView?.isLayoutMarginsRelativeArrangement = true
        self.controlsBarView?.backgroundShadow()
        
        blurBackgroundView.contentView.addSubview(self.controlsBarView ?? UIView())
        self.contentStackView.addArrangedSubview(blurBackgroundView)
    }
    
    func addContentToControlsBar() {
        self.controlsBarView?.arrangedSubviews.forEach({$0.removeFromSuperview()})
        
        self.setupRemoveChannelButton()
        
        self.setupSpacerView()
        
        self.setupRewindButton()
        self.setupPlayPauseButton()
        self.setupForwardButton()
        
        self.setupSpacerView()
        
        self.setupMuteButton()
        self.setupVolumeSlider()
        self.setupLanguageSelectorButton()
//        self.setupCaptionSelectorButton()
        
        self.setupSpacerView()
        
        self.setupFullScreenButton()
    }
    
    func setupSpacerView() {
        let spacerView = UIView()
        spacerView.backgroundColor = .clear
        NSLayoutConstraint.activate([
            spacerView.widthAnchor.constraint(equalToConstant: 150)
        ])
        self.controlsBarView?.addArrangedSubview(spacerView)
    }
    
    func setupRewindButton() {
        self.rewindButton = UIButton(type: .custom)
        self.rewindButton?.setBackgroundImage(UIImage(systemName: "backward.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .focused)
        self.rewindButton?.setBackgroundImage(UIImage(systemName: "backward")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        
        let iconScaleMultiplier = (self.rewindButton?.backgroundImage(for: .normal)?.size.height ?? 1)/(self.rewindButton?.backgroundImage(for: .normal)?.size.width ?? 1)
        
        NSLayoutConstraint.activate([
            NSLayoutConstraint(item: self.rewindButton ?? UIView(), attribute: .height, relatedBy: .equal, toItem: self.rewindButton ?? UIView(), attribute: .width, multiplier: iconScaleMultiplier, constant: 0)
        ])
        
        self.rewindButton?.addTarget(self, action: #selector(self.rewindPressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.rewindButton ?? UIView())
    }
    
    func setupPlayPauseButton() {
        self.playPauseButton = UIButton(type: .custom)
        self.updatePlayPauseButtonStatus(paused: self.playerItem?.player?.timeControlStatus == .paused)
        
        let iconScaleMultiplier = (self.playPauseButton?.backgroundImage(for: .normal)?.size.height ?? 1)/(self.playPauseButton?.backgroundImage(for: .normal)?.size.width ?? 1)
        
        NSLayoutConstraint.activate([
            NSLayoutConstraint(item: self.playPauseButton ?? UIView(), attribute: .height, relatedBy: .equal, toItem: self.playPauseButton ?? UIView(), attribute: .width, multiplier: iconScaleMultiplier, constant: 0)
        ])
        
        self.playPauseButton?.addTarget(self, action: #selector(self.playPausePressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.playPauseButton ?? UIView())
    }
    
    func updatePlayPauseButtonStatus(paused: Bool) {
        if(paused) {
            self.playPauseButton?.setBackgroundImage(UIImage(systemName: "play.circle.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .focused)
            self.playPauseButton?.setBackgroundImage(UIImage(systemName: "play.circle")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        }else{
            self.playPauseButton?.setBackgroundImage(UIImage(systemName: "pause.circle.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .focused)
            self.playPauseButton?.setBackgroundImage(UIImage(systemName: "pause.circle")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
            
        }
        self.playPauseButton?.layoutIfNeeded()
        self.playPauseButton?.subviews.first?.contentMode = .scaleAspectFit
    }
    
    func setupForwardButton() {
        self.forwardButton = UIButton(type: .custom)
        self.forwardButton?.setBackgroundImage(UIImage(systemName: "forward.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .focused)
        self.forwardButton?.setBackgroundImage(UIImage(systemName: "forward")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        
        let iconScaleMultiplier = (self.forwardButton?.backgroundImage(for: .normal)?.size.height ?? 1)/(self.forwardButton?.backgroundImage(for: .normal)?.size.width ?? 1)
        
        NSLayoutConstraint.activate([
            NSLayoutConstraint(item: self.forwardButton ?? UIView(), attribute: .height, relatedBy: .equal, toItem: self.forwardButton ?? UIView(), attribute: .width, multiplier: iconScaleMultiplier, constant: 0)
        ])
        
        self.forwardButton?.addTarget(self, action: #selector(self.forwardPressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.forwardButton ?? UIView())
    }
    
    func setupRemoveChannelButton() {
        self.removeChannelButton = UIButton(type: .custom)
        self.removeChannelButton?.setBackgroundImage(UIImage(systemName: "x.circle.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .focused)
        self.removeChannelButton?.setBackgroundImage(UIImage(systemName: "x.circle")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        
        let iconScaleMultiplier = (self.removeChannelButton?.backgroundImage(for: .normal)?.size.height ?? 1)/(self.removeChannelButton?.backgroundImage(for: .normal)?.size.width ?? 1)
        
        NSLayoutConstraint.activate([
            NSLayoutConstraint(item: self.removeChannelButton ?? UIView(), attribute: .height, relatedBy: .equal, toItem: self.removeChannelButton ?? UIView(), attribute: .width, multiplier: iconScaleMultiplier, constant: 0)
        ])
        
        self.removeChannelButton?.addTarget(self, action: #selector(self.removeChannelPressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.removeChannelButton ?? UIView())
    }
    
    func setupMuteButton() {
        self.muteChannelButton = UIButton(type: .custom)
        self.updateMuteButtonStatus()
        
        let iconScaleMultiplier = (self.muteChannelButton?.backgroundImage(for: .normal)?.size.height ?? 1)/(self.muteChannelButton?.backgroundImage(for: .normal)?.size.width ?? 1)
        
        NSLayoutConstraint.activate([
            NSLayoutConstraint(item: self.muteChannelButton ?? UIView(), attribute: .height, relatedBy: .equal, toItem: self.muteChannelButton ?? UIView(), attribute: .width, multiplier: iconScaleMultiplier, constant: 0)
        ])
        
        self.muteChannelButton?.addTarget(self, action: #selector(self.muteChannelPressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.muteChannelButton ?? UIView())
    }
    
    func setupVolumeSlider() {
        let sliderWidth: CGFloat = 200
        
        self.volumeSlider = TvOSSlider()
        self.volumeSlider?.stepValue = 1/16
        self.volumeSlider?.minimumTrackTintColor = ConstantsUtil.brandingRed
        self.volumeSlider?.expectedLayoutWidth = sliderWidth //We set this to 200 to calculate the the x before we actually have the frame
        self.volumeSlider?.value = self.playerItem?.player?.volume ?? 0
        NSLayoutConstraint.activate([
            (self.volumeSlider ?? UIView()).widthAnchor.constraint(equalToConstant: sliderWidth)
        ])
        self.volumeSlider?.addTarget(self, action: #selector(self.volumeSliderChanged), for: .valueChanged)
        self.controlsBarView?.addArrangedSubview(self.volumeSlider ?? UIView())
    }
    
    func updateMuteButtonStatus() {
        if(self.playerItem?.player?.isMuted ?? true) {
            self.muteChannelButton?.setBackgroundImage(UIImage(systemName: "speaker.slash.circle.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .focused)
            self.muteChannelButton?.setBackgroundImage(UIImage(systemName: "speaker.slash.circle")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        }else{
            self.muteChannelButton?.setBackgroundImage(UIImage(systemName: "speaker.wave.2.circle.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .focused)
            self.muteChannelButton?.setBackgroundImage(UIImage(systemName: "speaker.wave.2.circle")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        }
    }
    
    func setupLanguageSelectorButton() {
        self.languageSelectorButton = UIButton(type: .custom)
        self.languageSelectorButton?.setBackgroundImage(UIImage(systemName: "ear.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .focused)
        self.languageSelectorButton?.setBackgroundImage(UIImage(systemName: "ear")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        
        let iconScaleMultiplier = (self.languageSelectorButton?.backgroundImage(for: .normal)?.size.height ?? 1)/(self.languageSelectorButton?.backgroundImage(for: .normal)?.size.width ?? 1)
        
        NSLayoutConstraint.activate([
            NSLayoutConstraint(item: self.languageSelectorButton ?? UIView(), attribute: .height, relatedBy: .equal, toItem: self.languageSelectorButton ?? UIView(), attribute: .width, multiplier: iconScaleMultiplier, constant: 0)
        ])
        
        self.languageSelectorButton?.addTarget(self, action: #selector(self.languageSelectPressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.languageSelectorButton ?? UIView())
    }
    
    func setupCaptionSelectorButton() {
        self.captionSelectorButton = UIButton(type: .custom)
        self.captionSelectorButton?.setBackgroundImage(UIImage(systemName: "captions.bubble.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .focused)
        self.captionSelectorButton?.setBackgroundImage(UIImage(systemName: "captions.bubble")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        
        let iconScaleMultiplier = (self.captionSelectorButton?.backgroundImage(for: .normal)?.size.height ?? 1)/(self.captionSelectorButton?.backgroundImage(for: .normal)?.size.width ?? 1)
        
        NSLayoutConstraint.activate([
            NSLayoutConstraint(item: self.captionSelectorButton ?? UIView(), attribute: .height, relatedBy: .equal, toItem: self.captionSelectorButton ?? UIView(), attribute: .width, multiplier: iconScaleMultiplier, constant: 0)
        ])
        
        self.captionSelectorButton?.addTarget(self, action: #selector(self.captionSelectPressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.captionSelectorButton ?? UIView())
    }
    
    func setupFullScreenButton() {
        self.enterFullScreenButton = UIButton(type: .custom)
        self.enterFullScreenButton?.setBackgroundImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .focused)
        self.enterFullScreenButton?.setBackgroundImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right.circle")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        
        let iconScaleMultiplier = (self.enterFullScreenButton?.backgroundImage(for: .normal)?.size.height ?? 1)/(self.enterFullScreenButton?.backgroundImage(for: .normal)?.size.width ?? 1)
        
        NSLayoutConstraint.activate([
            NSLayoutConstraint(item: self.enterFullScreenButton ?? UIView(), attribute: .height, relatedBy: .equal, toItem: self.enterFullScreenButton ?? UIView(), attribute: .width, multiplier: iconScaleMultiplier, constant: 0)
        ])
        
        self.enterFullScreenButton?.addTarget(self, action: #selector(self.enterFullScreenPressed), for: .primaryActionTriggered)
        self.controlsBarView?.addArrangedSubview(self.enterFullScreenButton ?? UIView())
    }
    
    @objc func removeChannelPressed() {
        self.controlStripActionProtocol?.willCloseFocusedPlayer()
        self.swipeDownRegognized()
    }
    
    @objc func muteChannelPressed() {
        let muted = !(self.playerItem?.player?.isMuted ?? false)
        self.playerItem?.player?.isMuted = muted
        self.updateMuteButtonStatus()
        
        var playerSettings = CredentialHelper.getPlayerSettings()
        playerSettings.setPreferredMute(for: self.playerItem?.contentItem.container.metadata?.channelType ?? ChannelType(), mute: muted)
        CredentialHelper.setPlayerSettings(playerSettings: playerSettings)
    }
    
    @objc func volumeSliderChanged(slider: TvOSSlider) {
        let newVolume = slider.value
        self.playerItem?.player?.volume = newVolume
        
        var playerSettings = CredentialHelper.getPlayerSettings()
        playerSettings.setPreferredVolume(for: self.playerItem?.contentItem.container.metadata?.channelType ?? ChannelType(), volume: newVolume)
        CredentialHelper.setPlayerSettings(playerSettings: playerSettings)
        
        print("Setting player volume to \(newVolume)")
    }
    
    @objc func enterFullScreenPressed() {
        self.controlStripActionProtocol?.enterFullScreenPlayer()
        self.swipeDownRegognized()
    }
    
    @objc func rewindPressed() {
        self.controlStripActionProtocol?.rewindPlayer()
    }
    
    @objc func playPausePressed() {
        self.updatePlayPauseButtonStatus(paused: self.playerItem?.player?.timeControlStatus != .paused)
        self.controlStripActionProtocol?.playPausePlayer()
    }
    
    @objc func forwardPressed() {
        self.controlStripActionProtocol?.forwardPlayer()
    }
    
    @objc func languageSelectPressed() {
        print(self.playerItem?.playerItem?.tracks(type: .audio) ?? [String]())
        print(self.playerItem?.playerItem?.tracks(type: .subtitle) ?? [String]())
        
        self.showLanguageSelectMenu()
    }
    
    func showLanguageSelectMenu() {
        let alertController = UIAlertController(title: NSLocalizedString("select", comment: ""), message: nil, preferredStyle: .alert)
        
        for language in self.playerItem?.playerItem?.tracks(type: .audio) ?? [String]() {
            alertController.addAction(UIAlertAction(title: language, style: .default, handler: { (UIAlertAction) in
                let _ = self.playerItem?.playerItem?.select(type: .audio, name: language)
                var playerSettings = CredentialHelper.getPlayerSettings()
                playerSettings.setPreferredLanugage(for: self.playerItem?.contentItem.container.metadata?.channelType ?? ChannelType(), language: language)
                CredentialHelper.setPlayerSettings(playerSettings: playerSettings)
            }))
        }
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: { (UIAlertAction) in
            print("Cancelled")
        }))
        
        UserInteractionHelper.instance.getPresentingViewController().present(alertController, animated: true)
    }
    
    @objc func captionSelectPressed() {
        print(self.playerItem?.playerItem?.tracks(type: .audio) ?? [String]())
        print(self.playerItem?.playerItem?.tracks(type: .subtitle) ?? [String]())
        
        self.showCaptionSelectMenu()
    }
    
    func showCaptionSelectMenu() {
        let alertController = UIAlertController(title: NSLocalizedString("select", comment: ""), message: nil, preferredStyle: .alert)
        
        for captions in self.playerItem?.playerItem?.tracks(type: .subtitle) ?? [String]() {
            alertController.addAction(UIAlertAction(title: captions, style: .default, handler: { (UIAlertAction) in
                let _ = self.playerItem?.playerItem?.select(type: .subtitle, name: captions)
                var playerSettings = CredentialHelper.getPlayerSettings()
                playerSettings.setPreferredCaptions(for: self.playerItem?.contentItem.container.metadata?.channelType ?? ChannelType(), captions: captions)
                CredentialHelper.setPlayerSettings(playerSettings: playerSettings)
            }))
        }
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: { (UIAlertAction) in
            print("Cancelled")
        }))
        
        UserInteractionHelper.instance.getPresentingViewController().present(alertController, animated: true)
    }
    
    @objc func swipeDownRegognized() {
        self.dismiss(animated: true)
    }
}

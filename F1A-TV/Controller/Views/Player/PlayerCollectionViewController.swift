#if canImport(F1Core)
import F1Core
#endif
//
//  PlayerCollectionViewController.swift
//  F1A-TV
//
//  Created by Noah Fetz on 29.03.21.
//

import UIKit
import AVKit

class PlayerCollectionViewController: BaseCollectionViewController, ChannelSelectionProtocol, ControlStripActionProtocol, FullscreenPlayerDismissedProtocol {
    var services: AppServices!
    var entitlementGenerations = [String: UUID]()
    var entitlementTasks = [String: Task<Void, Never>]()
    lazy var progressReporter = PlaybackProgressReporter(deliver: { [playback = services.playback] progress in
        try await playback.report(contentID: progress.contentID, subtype: progress.subtype, position: progress.position, timestamp: progress.timestamp)
    }, onError: { recordServiceFailure($0, operation: .action) })
    var startupTimeouts = [String: DispatchWorkItem]()
    var pendingSeekTime: Double?
    var pendingSeekReferenceID: String?
    var restoringPlayerIDs = Set<String>()
    var playerSeekGenerations = [String: UUID]()
    var lastPlaybackPosition: PlaybackPositionSnapshot?
    var isExitingPlayback = false
    var positionTimer: Timer?
    var startedFromBeginning = false
    var displayCriteriaTask: Task<Void, Never>?
    var defaultsTasks = [String: Task<Void, Never>]()
    var defaultsAppliedPlayerIDs = Set<String>()
    
    // MARK: - Properties
    var channelItems = [ContentItem]()
    var playerItems = [PlayerItem]()
    var lastFocusedPlayer: IndexPath?
    var controlTargetPlayerId: String?
    
    var fullscreenPlayerId: String?
    
    var playerInfoViewController: PlayerInfoOverlayViewController?
    var channelSelectorViewController: ChannelSelectorOverlayViewController?
    var controlStripViewController: ControlStripOverlayViewController?
    
    var layoutChoice = MultiviewLayout.auto
    var readyObservations = [String: NSKeyValueObservation]()
    var initializedPlayerIDs = Set<String>()
    var setupAudio = [String: SavedStream]()
    var liveCoordinator = LivePlaybackCoordinator()
    var synchronizationGeneration = UUID()
    var wantsPlayback = true
    var startupAnchors = [String: (PlaybackPositionSnapshot, UUID)]()
    var isLiveSession: Bool { channelItems.contains { $0.contentSubtype == "LIVE" } }
    var slotCount: Int { layoutChoice.slotCount(players: playerItems.count) }

    var isFirstPlayer = true
    var playFromStart = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupCollectionView()
        liveCoordinator.onFailure = { [weak self] in
            guard let self, self.viewIfLoaded?.window != nil else { return }
            UserInteractionHelper.instance.showError(title: "error".localizedString, message: "go_live_failed".localizedString)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(playerResolutionChanged), name: FairPlayer.resolutionDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playbackWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.rememberPlaybackPosition() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed { stopPlayback() }
    }
    @objc private func playbackWillResignActive() { reportCurrentPlayTime() }

    deinit {
        displayCriteriaTask?.cancel(); defaultsTasks.values.forEach { $0.cancel() }; entitlementTasks.values.forEach { $0.cancel() }
        startupTimeouts.values.forEach { $0.cancel() }
        positionTimer?.invalidate()
        let identity = ObjectIdentifier(self)
        Task { @MainActor in PlaybackIdleTimer.shared.remove(identity) }
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func playerResolutionChanged(_ notification: Notification) {
        guard let player = notification.object as? FairPlayer, player === playerItems.first?.player,
              player.resolutionStatus == .available else { return }
        updatePreferredDisplayCriteria(for: player)
    }
    
    func initialize(channelItems: [ContentItem], playFromStart: Bool? = false) {
        self.channelItems = channelItems
        self.playFromStart = playFromStart ?? false
        self.startedFromBeginning = self.playFromStart
        
        if let channel = PlaybackSelection.initialChannel(in: channelItems.compactMap(\.channel), preference: CredentialHelper.getPlayerSettings().defaultFeed),
           let item = channelItems.first(where: { $0.channel?.id == channel.id }) {
            loadStreamEntitlement(channelItem: item)
        }
    }
    
    // MARK: - Setup
    func setupCollectionView() {
        self.collectionView.backgroundColor = .black
        self.collectionView.register(AddStreamCollectionViewCell.self, forCellWithReuseIdentifier: AddStreamCollectionViewCell.reuseIdentifier)
        
        // Use custom layout for main + small players arrangement
        let customLayout = PlayerGridLayout()
        customLayout.choice = layoutChoice
        customLayout.playerCount = playerItems.count
        self.collectionView.collectionViewLayout = customLayout
        self.collectionView.remembersLastFocusedIndexPath = true
        
        let playPauseGesture = UITapGestureRecognizer(target: self, action: #selector(self.playPausePressed))
        playPauseGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        self.collectionView.addGestureRecognizer(playPauseGesture)
        
        //Override the default menu back because we need to stop all players before we dismiss the view controller
        let menuGesture = UITapGestureRecognizer(target: self, action: #selector(self.menuPressed))
        menuGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        self.collectionView.addGestureRecognizer(menuGesture)

        let swipeUpRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeUpRegognized))
        swipeUpRecognizer.direction = .up
        self.collectionView.addGestureRecognizer(swipeUpRecognizer)

        let swipeLeftRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeLeftRegognized))
        swipeLeftRecognizer.direction = .left
        self.collectionView.addGestureRecognizer(swipeLeftRecognizer)
        
        // Add select button (long press) gesture to show channel selector (useful in simulator)
        let selectLongPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.selectLongPressed))
        selectLongPressGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        self.collectionView.addGestureRecognizer(selectLongPressGesture)
    }
    
    // MARK: - Layout Update Helper
    func refreshPlayerLayout(focusedID: String? = nil) {
        if let layout = collectionView.collectionViewLayout as? PlayerGridLayout {
            layout.choice = layoutChoice
            layout.playerCount = playerItems.count
        }
        if let focusedID, let index = playerItems.firstIndex(where: { $0.id == focusedID }) {
            lastFocusedPlayer = IndexPath(item: index, section: 0)
        } else if let last = lastFocusedPlayer, last.item >= slotCount {
            lastFocusedPlayer = IndexPath(item: max(0, playerItems.count - 1), section: 0)
        }
        collectionView.reloadData()
        collectionView.collectionViewLayout.invalidateLayout()
    }
    override func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? {
        lastFocusedPlayer ?? IndexPath(item: 0, section: 0)
    }

    // MARK: - UICollectionView DataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return slotCount
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if !playerItems.indices.contains(indexPath.item) {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AddStreamCollectionViewCell.reuseIdentifier, for: indexPath) as! AddStreamCollectionViewCell
            cell.onSelect = { [weak self, weak cell] in
                guard let self, let cell, let slot = self.collectionView.indexPath(for: cell) else { return }
                self.lastFocusedPlayer = slot
                self.showChannelSelectorOverlay()
            }
            return cell
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ConstantsUtil.channelPlayerCollectionViewCell, for: indexPath) as! ChannelPlayerCollectionViewCell
        
        cell.loadingSpinner?.startAnimating()
        
        let currentItem = self.playerItems[indexPath.item]
        cell.isControlTarget = currentItem.id == self.controlTargetPlayerId
        
        cell.titleLabel.text = ""
        cell.subtitleLabel.text = ""
        cell.subtitleLabel.textColor = .white
        
        switch currentItem.contentItem.channelType {
        case .MainFeed, .AdditionalFeed:
            cell.titleLabel.text = currentItem.contentItem.title
            
        case .OnBoardCamera:
            cell.titleLabel.text = currentItem.contentItem.title
            
            if let additionalStream = currentItem.contentItem.channel {
                cell.subtitleLabel.text = additionalStream.teamName
                cell.subtitleLabel.textColor = UIColor(rgb: additionalStream.hex ?? "#00000000")
            }
            
        default:
            print("Shouldn't happen (Hopefully ^^)")
        }

        if currentItem.hasFailed {
            cell.subtitleLabel.text = "stream_failed_retry".localizedString
            cell.loadingSpinner?.stopAnimating()
        }
        
        if let player = currentItem.player, player.currentItem != nil {
            cell.startPlayer(player: player)
            cell.loadingSpinner?.stopAnimating()
        }
        
        return cell
    }
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        collectionView.visibleCells.compactMap { $0 as? ChannelPlayerCollectionViewCell }.filter { $0.isFocused || $0.isControlTarget }.forEach { $0.showOptionsMenu() }
        super.pressesBegan(presses, with: event)
    }

    // MARK: - UICollectionView Delegate
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if !playerItems.indices.contains(indexPath.item) {
            self.lastFocusedPlayer = indexPath
            self.showChannelSelectorOverlay()
            return
        }
        
        // Capture the selected tile before the overlay takes focus.
        self.lastFocusedPlayer = indexPath
        if playerItems[indexPath.item].hasFailed {
            restartPlayer(id: playerItems[indexPath.item].id)
            return
        }
        self.showControlStripOverlay(for: indexPath)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if collectionView == self.collectionView {
            if(self.playerItems.isEmpty){
                self.lastFocusedPlayer = nil
                return
            }
            
            if let nextFocusedIndexPath = context.nextFocusedIndexPath {
                self.lastFocusedPlayer = nextFocusedIndexPath
            }
        }
    }
}

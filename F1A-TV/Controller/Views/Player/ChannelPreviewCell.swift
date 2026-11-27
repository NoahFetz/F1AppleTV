#if canImport(F1Core)
import F1Core
#endif
import UIKit
import AVKit
import Kingfisher

final class ChannelPreviewCell: UITableViewCell {
    static let reuseIdentifier = "ChannelPreviewCell"
    private let previewView = UIView()
    private let artworkView = UIImageView()
    private let fallbackIcon = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let addedIcon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    private let actionLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var playerLayer: AVPlayerLayer?
    private var compositeView: TVCompositeTileView?
    private var displayObservation: NSKeyValueObservation?
    private var displayTimeout: DispatchWorkItem?
    private var subtitleHeightConstraint: NSLayoutConstraint?
    private var subtitleTopConstraint: NSLayoutConstraint?

    private let teamLogo = UIImageView()
    private let teamStripe = UIView()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        teamLogo.contentMode = .scaleAspectFit
        teamLogo.translatesAutoresizingMaskIntoConstraints = false
        teamStripe.translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        focusStyle = .custom
        previewView.backgroundColor = UIColor(white: 0.12, alpha: 1)
        previewView.layer.cornerRadius = 8
        previewView.clipsToBounds = true
        artworkView.contentMode = .scaleAspectFill
        artworkView.clipsToBounds = true
        fallbackIcon.contentMode = .scaleAspectFit
        fallbackIcon.tintColor = .white
        spinner.hidesWhenStopped = true
        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        subtitleLabel.font = .systemFont(ofSize: 22, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        subtitleLabel.lineBreakMode = .byTruncatingTail
        addedIcon.tintColor = .white
        actionLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        actionLabel.textColor = .white
        actionLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let nameMaterial = PlayerMaterial.makeView(cornerRadius: 18)
        [previewView, subtitleLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview($0) }
        [artworkView, fallbackIcon, spinner, nameMaterial].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; previewView.addSubview($0) }
        [titleLabel, actionLabel, addedIcon].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; nameMaterial.contentView.addSubview($0) }
        let subtitleHeight = subtitleLabel.heightAnchor.constraint(equalToConstant: 30)
        let subtitleTop = subtitleLabel.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 10)
        subtitleHeightConstraint = subtitleHeight
        subtitleTopConstraint = subtitleTop
        previewView.addSubview(teamStripe); previewView.addSubview(teamLogo)
        NSLayoutConstraint.activate([
            teamStripe.leadingAnchor.constraint(equalTo: previewView.leadingAnchor), teamStripe.topAnchor.constraint(equalTo: previewView.topAnchor), teamStripe.bottomAnchor.constraint(equalTo: previewView.bottomAnchor), teamStripe.widthAnchor.constraint(equalToConstant: 5),
            teamLogo.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -16), teamLogo.bottomAnchor.constraint(equalTo: previewView.bottomAnchor, constant: -16), teamLogo.widthAnchor.constraint(equalToConstant: 60), teamLogo.heightAnchor.constraint(equalToConstant: 40)
        ])
        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            previewView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            previewView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            previewView.heightAnchor.constraint(equalTo: previewView.widthAnchor, multiplier: 9.0 / 16),
            artworkView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            artworkView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),
            artworkView.topAnchor.constraint(equalTo: previewView.topAnchor),
            artworkView.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
            fallbackIcon.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            fallbackIcon.centerYAnchor.constraint(equalTo: previewView.centerYAnchor),
            fallbackIcon.widthAnchor.constraint(equalToConstant: 64),
            fallbackIcon.heightAnchor.constraint(equalToConstant: 64),
            spinner.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: previewView.centerYAnchor),
            nameMaterial.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 14),
            nameMaterial.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -14),
            nameMaterial.topAnchor.constraint(equalTo: previewView.topAnchor, constant: 14),
            nameMaterial.heightAnchor.constraint(equalToConstant: 48),
            titleLabel.leadingAnchor.constraint(equalTo: nameMaterial.contentView.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: actionLabel.leadingAnchor, constant: -10),
            actionLabel.trailingAnchor.constraint(equalTo: addedIcon.leadingAnchor, constant: -6),
            actionLabel.centerYAnchor.constraint(equalTo: nameMaterial.contentView.centerYAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: nameMaterial.contentView.centerYAnchor),
            addedIcon.trailingAnchor.constraint(equalTo: nameMaterial.contentView.trailingAnchor, constant: -14),
            addedIcon.centerYAnchor.constraint(equalTo: nameMaterial.contentView.centerYAnchor),
            addedIcon.widthAnchor.constraint(equalToConstant: 28),
            addedIcon.heightAnchor.constraint(equalToConstant: 28),
            subtitleLabel.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -2),
            subtitleTop,
            subtitleHeight,
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func channelKey(_ item: ContentItem) -> String {
        item.previewIdentity
    }

    func configure(item: ContentItem, added: Bool) {
        clearPreview()
        artworkView.kf.cancelDownloadTask()
        artworkView.image = nil
        let metadata: ContentItem? = item
        let stream = metadata?.channel
        let onboard = metadata?.channelType == .OnBoardCamera
        teamStripe.backgroundColor = stream?.hex.map { UIColor(rgb: $0) } ?? .clear
        teamStripe.isHidden = !onboard
        teamLogo.kf.cancelDownloadTask(); teamLogo.image = nil
        teamLogo.isHidden = !onboard
        if let logo = stream?.teamImg, !logo.isEmpty {
            let url = URL(string: logo.hasPrefix("http") ? logo : "\(ConstantsUtil.imageResizerUrl)/\(logo)?w=120&h=80&q=HI")
            teamLogo.kf.setImage(with: url)
        }
        titleLabel.text = onboard ? "\(stream?.racingNumber ?? 0)  \(metadata?.title ?? stream?.title ?? "")" : metadata?.title
        subtitleLabel.text = onboard ? stream?.teamName : nil
        let hasSubtitle = !(subtitleLabel.text ?? "").isEmpty
        subtitleHeightConstraint?.constant = hasSubtitle ? 30 : 0
        subtitleTopConstraint?.constant = hasSubtitle ? 10 : 0
        fallbackIcon.image = UIImage(systemName: onboard ? "steeringwheel" : "tv")
        let reference = onboard ? stream?.driverImg : metadata?.pictureUrl
        artworkView.contentMode = onboard ? .scaleAspectFit : .scaleAspectFill
        fallbackIcon.isHidden = false
        if let reference = reference, !reference.isEmpty {
            let directURL = URL(string: reference)
            let url: URL?
            if let directURL = directURL, ["http", "https"].contains(directURL.scheme ?? "") {
                url = directURL
            } else {
                var components = URLComponents(string: ConstantsUtil.imageResizerUrl)
                if var value = components {
                    value.path += "/" + reference
                    value.queryItems = [URLQueryItem(name: "w", value: "864"), URLQueryItem(name: "h", value: "486"), URLQueryItem(name: "q", value: "HI"), URLQueryItem(name: "o", value: "L")]
                    components = value
                }
                url = components?.url
            }
            artworkView.kf.setImage(with: url) { [weak self] result in
                if case .success = result { self?.fallbackIcon.isHidden = true }
            }
        }
        setAdded(added)
        accessibilityLabel = [titleLabel.text, subtitleLabel.text].compactMap { $0 }.joined(separator: ", ")
    }

    func setAdded(_ added: Bool) {
        addedIcon.isHidden = false
        addedIcon.image = UIImage(systemName: added ? "minus.circle.fill" : "plus.circle.fill")
        actionLabel.text = (added ? "stream_remove" : "stream_add").localizedString
        accessibilityValue = actionLabel.text
    }

    func setPreviewPlayer(_ player: AVPlayer?) {
        if let player, playerLayer?.player === player { return }
        displayTimeout?.cancel()
        displayTimeout = nil
        displayObservation = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        spinner.stopAnimating()
        guard let player = player else {
            fallbackIcon.isHidden = artworkView.image != nil
            return
        }
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.frame = previewView.bounds
        layer.opacity = 0
        previewView.layer.insertSublayer(layer, above: artworkView.layer)
        playerLayer = layer
        let timeout = DispatchWorkItem { [weak self, weak layer] in
            guard let self = self, self.playerLayer === layer else { return }
            self.spinner.stopAnimating()
        }
        displayTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: timeout)
        displayObservation = layer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self, weak layer] _, _ in
            DispatchQueue.main.async {
                guard let self = self, let layer = layer, self.playerLayer === layer, layer.isReadyForDisplay else { return }
                layer.opacity = 1
                self.displayTimeout?.cancel()
                self.fallbackIcon.isHidden = true
                self.spinner.stopAnimating()
            }
        }
    }

    func setCompositePreview(_ tile: TVCompositeTile?) {
        if let tile, compositeView?.renderer === tile.renderer, compositeView?.rect == tile.rect { return }
        guard tile != nil || compositeView != nil else { return }
        compositeView?.removeFromSuperview()
        compositeView = nil
        setPreviewPlayer(nil)
        guard let tile else { return }
        let view = TVCompositeTileView(tile: tile)
        view.frame = previewView.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        previewView.insertSubview(view, aboveSubview: artworkView)
        compositeView = view
        fallbackIcon.isHidden = true
    }

    func drawCompositePreview() { compositeView?.setNeedsDisplay() }

    func clearPreview() {
        setCompositePreview(nil)
        setPreviewPlayer(nil)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer?.frame = previewView.bounds
        CATransaction.commit()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        clearPreview()
        teamLogo.kf.cancelDownloadTask(); teamLogo.image = nil
        artworkView.kf.cancelDownloadTask()
        artworkView.image = nil
        fallbackIcon.isHidden = false
        transform = .identity
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations {
            self.transform = self.isFocused ? CGAffineTransform(scaleX: 1.025, y: 1.025) : .identity
            self.previewView.layer.borderWidth = self.isFocused ? 3 : 0
            self.previewView.layer.borderColor = UIColor.white.cgColor
        }
    }
}

@MainActor
final class StreamPreviewSession: PreviewPlaybackSession {
    private let services: AppServices
    private let previewFeeds: PreviewFeedLoader
    private var entitlementRequest: Task<Void, Never>?
    private var requestID = UUID()
    private(set) var player: FairPlayer?
    private var completion: ((FairPlayer?) -> Void)?
    private var synchronizing = false
    private var preparationError: Error?
    private var retryIndividual: (() -> Void)?

    init(services: AppServices, previewFeeds: PreviewFeedLoader) {
        self.services = services
        self.previewFeeds = previewFeeds
    }

    func start(item: ContentItem, referencePlayer: AVPlayer?, maximumHeight: Int = 360, completion: @escaping (FairPlayer?) -> Void) {
        stop()
        self.completion = completion
        guard case .playback(let target) = item.action else { fail(error: APIError.invalidPlayback); return }
        let player = FairPlayer()
        player.fairPlayService = services.fairPlay
        player.reportsPlaybackErrors = false
        player.isMuted = true
        player.volume = 0
        self.player = player
        player.onPlaybackError = { [weak self, weak player] error in
            guard let self, let player, self.player === player else { return }
            self.preparationError = error
        }
        loadPreview(channel: item.channel, target: target, maximumHeight: maximumHeight, allowBundle: true)
    }

    private func loadPreview(channel: PlaybackChannel?, target: PlaybackTarget, maximumHeight: Int, allowBundle: Bool) {
        guard let player else { return }
        let identity = UUID()
        requestID = identity
        entitlementRequest = Task { [weak self] in
            guard let self else { return }
            do {
                let usesBundle = try await self.previewFeeds.prepare(
                    channel: channel, allowBundle: allowBundle,
                    individual: { try await self.services.playback.entitlement(target) }
                ) { entitlement, timeout in
                    self.preparationError = nil
                    try await player.prepareFeedPreview(entitlement, maximumHeight: maximumHeight,
                                                        timeout: timeout, failure: { self.preparationError })
                }
                try Task.checkCancellation()
                guard self.requestID == identity else { return }
                self.entitlementRequest = nil
                if usesBundle {
                    self.retryIndividual = { [weak self] in
                        self?.loadPreview(channel: channel, target: target, maximumHeight: maximumHeight, allowBundle: false)
                    }
                }
                self.completion?(player)
            } catch {
                guard self.requestID == identity, !Task.isCancelled else { return }
                self.fail(error: error)
            }
        }
    }

    func synchronize(reference: AVPlayer?, visible: Bool) {
        guard let player, let item = player.currentItem else { return }
        if let error = preparationError ?? (item.status == .failed ? (item.error ?? APIError.invalidPlayback) : nil) {
            if let retryIndividual {
                self.retryIndividual = nil
                synchronizing = false
                player.stopStream()
                completion?(nil)
                retryIndividual()
            } else {
                fail(error: error)
            }
            return
        }
        guard item.status == .readyToPlay else { return }
        guard visible else { player.pause(); return }
        let rate = reference?.rate ?? 1
        if rate == 0 { player.pause() } else if player.rate != rate { player.rate = rate }
        guard let reference, !synchronizing else { return }
        let target: Double
        if let date = reference.currentItem?.currentDate(), let ownDate = item.currentDate() {
            let drift = date.timeIntervalSince(ownDate)
            guard abs(drift) > 0.8 else { return }
            synchronizing = true
            let identity = requestID
            player.seek(to: date) { [weak self] _ in
                DispatchQueue.main.async { guard self?.requestID == identity else { return }; self?.synchronizing = false }
            }
            return
        } else if !item.duration.seconds.isFinite,
                  let ownRange = item.seekableTimeRanges.last?.timeRangeValue,
                  let referenceRange = reference.currentItem?.seekableTimeRanges.last?.timeRangeValue {
            let lag = CMTimeGetSeconds(CMTimeRangeGetEnd(referenceRange)) - reference.currentTime().seconds
            target = CMTimeGetSeconds(CMTimeRangeGetEnd(ownRange)) - max(0, lag)
        } else { target = reference.currentTime().seconds }
        guard target.isFinite, player.currentTime().seconds.isFinite,
              abs(target - player.currentTime().seconds) > 0.8 else { return }
        let duration = item.duration.seconds
        let range = item.seekableTimeRanges.last?.timeRangeValue
        let lower = range.map { max(0, $0.start.seconds) } ?? 0
        let upper = range.map { CMTimeRangeGetEnd($0).seconds - 0.1 } ?? (duration.isFinite ? max(0, duration - 0.1) : target)
        let clamped = max(lower, min(target, max(lower, upper)))
        synchronizing = true
        let identity = requestID
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async { guard self?.requestID == identity else { return }; self?.synchronizing = false }
        }
    }

    func stop() {
        requestID = UUID()
        entitlementRequest?.cancel()
        entitlementRequest = nil
        player?.stopStream()
        player = nil
        completion = nil
        preparationError = nil
        retryIndividual = nil
        synchronizing = false
    }

    private func fail(error: Error) {
        recordServiceFailure(error, operation: .preview)
        let callback = completion
        stop()
        callback?(nil)
    }

    deinit {
        entitlementRequest?.cancel()
        let closingPlayer = player
        Task { @MainActor in closingPlayer?.stopStream() }
    }
}

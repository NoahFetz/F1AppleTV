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
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var playerLayer: AVPlayerLayer?
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
        let nameMaterial = PlayerMaterial.makeView(cornerRadius: 18)
        [previewView, subtitleLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview($0) }
        [artworkView, fallbackIcon, spinner, nameMaterial].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; previewView.addSubview($0) }
        [titleLabel, addedIcon].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; nameMaterial.contentView.addSubview($0) }
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
            titleLabel.trailingAnchor.constraint(equalTo: addedIcon.leadingAnchor, constant: -10),
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
        setPreviewPlayer(nil)
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
        addedIcon.isHidden = !added
        accessibilityValue = added ? "Added" : nil
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

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer?.frame = previewView.bounds
        CATransaction.commit()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setPreviewPlayer(nil)
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
    private var entitlementRequest: Task<Void, Never>?
    private let services: AppServices
    init(services: AppServices) { self.services = services }
    private var observation: NSKeyValueObservation?
    private var timeout: DispatchWorkItem?
    private var requestID = UUID().uuidString
    private(set) var player: FairPlayer?
    private var completion: ((FairPlayer?) -> Void)?
    private var synchronizing = false
    private var hasStarted = false
    private var maximumHeight = 360

    func start(item: ContentItem, referencePlayer: AVPlayer?, maximumHeight: Int = 360, completion: @escaping (FairPlayer?) -> Void) {
        stop()
        self.completion = completion
        self.maximumHeight = maximumHeight
        let target: PlaybackTarget
        if case .playback(let action) = item.action { target = action }
        else { fail(error: APIError.invalidPlayback); return }
        let identity = requestID, playback = services.playback
        entitlementRequest = Task { [weak self] in
            do {
                let entitlement = try await playback.entitlement(target)
                try Task.checkCancellation()
                guard let self, self.requestID == identity else { return }
                self.didLoadStreamEntitlement(playerId: identity, streamEntitlement: entitlement)
            } catch {
                guard let self, self.requestID == identity, !(error is CancellationError) else { return }
                recordServiceFailure(error, operation: .preview)
                self.fail(error: error, recordsError: false)
            }
        }
        let timeout = DispatchWorkItem { [weak self] in
            guard self?.requestID == identity else { return }
            self?.fail(error: URLError(.timedOut))
        }
        self.timeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
    }

    func didLoadStreamEntitlement(playerId: String, streamEntitlement: PlaybackEntitlement) {
        guard playerId == requestID else { return }
        let player = FairPlayer()
        player.fairPlayService = services.fairPlay
        player.reportsPlaybackErrors = false
        self.player = player
        player.playStream(streamEntitlement: streamEntitlement)
        player.isMuted = true
        player.volume = 0
        player.prepareStream(previewMaximumHeight: maximumHeight) { [weak self, weak player] item in
            guard let self = self, let player = player, self.player === player else { return }
            self.observation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak player] item, _ in
                DispatchQueue.main.async {
                    guard let self = self, let player = player, self.player === player else { return }
                    if item.status == .failed { self.fail(error: item.error ?? URLError(.cannotDecodeContentData), recordsError: false) }
                    else if item.status == .readyToPlay && !self.hasStarted {
                        self.hasStarted = true
                        self.timeout?.cancel()
                        player.pause()
                        self.completion?(player)

                    }
                }
            }
        }
    }

    func synchronize(reference: AVPlayer?, visible: Bool) {
        guard let player, let item = player.currentItem, item.status == .readyToPlay else { return }
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
        requestID = UUID().uuidString
        entitlementRequest?.cancel()
        entitlementRequest = nil
        observation = nil
        timeout?.cancel()
        timeout = nil
        player?.stopStream()
        player = nil
        completion = nil
        hasStarted = false
        synchronizing = false
    }

    private func fail(error: Error, recordsError: Bool = true) {
        if recordsError { recordServiceFailure(error, operation: .preview) }
        let callback = completion
        stop()
        callback?(nil)
    }

    deinit {
        entitlementRequest?.cancel(); timeout?.cancel()
        let closingPlayer = player
        Task { @MainActor in closingPlayer?.stopStream() }
    }
}

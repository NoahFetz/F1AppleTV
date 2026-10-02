import UIKit
import Kingfisher

/// Allow controls in supplementary content to receive focus instead of the scroll view itself.
final class CatalogCollectionView: UICollectionView {
    override var canBecomeFocused: Bool { false }
}

final class CatalogGradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    override init(frame: CGRect) {
        super.init(frame: frame)
        let gradient = layer as! CAGradientLayer
        gradient.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.96).cgColor]
        gradient.locations = [0.25, 1]
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class CatalogSeriesBadge: UIStackView {
    private let label = UILabel()
    private let bar = UIView()
    private let gradient = CAGradientLayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        axis = .horizontal; spacing = 10
        bar.widthAnchor.constraint(equalToConstant: 4).isActive = true
        bar.heightAnchor.constraint(equalToConstant: 24).isActive = true
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.textColor = .white
        addArrangedSubview(bar); addArrangedSubview(label)
        gradient.colors = [UIColor.cyan.cgColor, UIColor(rgb: 0xbc0f80).cgColor]
        bar.layer.addSublayer(gradient)
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() { super.layoutSubviews(); gradient.frame = bar.bounds }
    func configure(_ name: String?, foreground: UIColor = .white) {
        let name = name ?? ""
        let series = SeriesType.fromCapitalDisplayName(capitalDisplayName: name)
        label.text = series == .None ? name : series.getShortDisplayName()
        label.textColor = foreground
        bar.backgroundColor = series.getColor()
        gradient.isHidden = series != .F1Academy
        isHidden = name.isEmpty
        accessibilityLabel = label.text
    }
}

final class CatalogHeroDots: UICollectionReusableView {
    static let kind = "CatalogHeroDots"
    static let reuseID = "CatalogHeroDots"
    let dots = UIPageControl()
    override init(frame: CGRect) {
        super.init(frame: frame)
        dots.isUserInteractionEnabled = false
        dots.currentPageIndicatorTintColor = ConstantsUtil.brandingRed
        dots.pageIndicatorTintColor = .white.withAlphaComponent(0.4)
        dots.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dots)
        NSLayoutConstraint.activate([dots.centerXAnchor.constraint(equalTo: centerXAnchor), dots.centerYAnchor.constraint(equalTo: centerYAnchor)])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(count: Int, index: Int) { dots.numberOfPages = count; dots.currentPage = index; dots.isHidden = count < 2 }
}

/// Browsing cells are independent of the thumbnail cells used by the player.
private final class CatalogCardFocusButton: UIButton {
    var onFocus: (() -> Void)?
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations { self.onFocus?() }
    }
}

final class CatalogCardCell: UICollectionViewCell {
    static let reuseID = "CatalogCardCell"
    enum Style { case thumbnail, poster, hero }
    private let artwork = CatalogArtworkImageView()
    private let cardButton = CatalogCardFocusButton(type: .custom)
    private let titleLabel = FontAdjustedUILabel()
    private let detailLabel = FontAdjustedUILabel()
    private let actionButton = TVActionButton(type: .custom)
    private let flag = UIImageView()
    private let badge = CatalogSeriesBadge()
    private let accentLine = UIView()
    private var seriesName: String?
    var onAction: (() -> Void)?
    var onMore: (() -> Void)?
    private let moreButton = TVActionButton(type: .custom)
    private let textStack = UIStackView()
    private let gradient = CatalogGradientView()
    private var style: Style = .thumbnail
    private var styleConstraints = [NSLayoutConstraint]()
    override var canBecomeFocused: Bool { false }
    override var preferredFocusEnvironments: [UIFocusEnvironment] { style == .hero ? [actionButton] : [cardButton] }

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = ConstantsUtil.brandingItemColor
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        artwork.contentMode = .scaleAspectFill
        artwork.clipsToBounds = true
        artwork.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(artwork)
        gradient.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(gradient)
        NSLayoutConstraint.activate([
            gradient.leadingAnchor.constraint(equalTo: artwork.leadingAnchor), gradient.trailingAnchor.constraint(equalTo: artwork.trailingAnchor),
            gradient.topAnchor.constraint(equalTo: artwork.topAnchor), gradient.bottomAnchor.constraint(equalTo: artwork.bottomAnchor)
        ])
        textStack.axis = .vertical
        textStack.spacing = 8
        textStack.translatesAutoresizingMaskIntoConstraints = false
        let details = UIStackView(arrangedSubviews: [flag, detailLabel]); details.spacing = 12; details.alignment = .center
        flag.contentMode = .scaleAspectFit
        flag.widthAnchor.constraint(equalToConstant: 36).isActive = true
        flag.heightAnchor.constraint(equalToConstant: 26).isActive = true
        accentLine.backgroundColor = ConstantsUtil.brandingRed
        accentLine.heightAnchor.constraint(equalToConstant: 3).isActive = true
        let accentContainer = UIView(); accentContainer.tag = 925
        accentLine.translatesAutoresizingMaskIntoConstraints = false; accentContainer.addSubview(accentLine)
        NSLayoutConstraint.activate([accentContainer.heightAnchor.constraint(equalToConstant: 3), accentLine.leadingAnchor.constraint(equalTo: accentContainer.leadingAnchor), accentLine.widthAnchor.constraint(equalToConstant: 56), accentLine.topAnchor.constraint(equalTo: accentContainer.topAnchor)])
        let actions = UIStackView(arrangedSubviews: [actionButton, moreButton, UIView()]); actions.spacing = 16; actions.alignment = .center
        actionButton.widthAnchor.constraint(equalToConstant: 300).isActive = true
        moreButton.widthAnchor.constraint(equalToConstant: 180).isActive = true
        [accentContainer, titleLabel, details, badge, actions].forEach { textStack.addArrangedSubview($0) }
        moreButton.setTitle("catalog_more".localizedString, for: .normal)
        moreButton.addAction(UIAction { [weak self] _ in self?.onMore?() }, for: .primaryActionTriggered)
        actionButton.contentHorizontalAlignment = .center
        actionButton.addAction(UIAction { [weak self] _ in self?.onAction?() }, for: .primaryActionTriggered)
        contentView.addSubview(textStack)
        titleLabel.numberOfLines = 2
        detailLabel.numberOfLines = 2
        actionButton.titleLabel?.font = .systemFont(ofSize: 24, weight: .medium)
        cardButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardButton)
        NSLayoutConstraint.activate([cardButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor), cardButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor), cardButton.topAnchor.constraint(equalTo: contentView.topAnchor), cardButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)])
        cardButton.addAction(UIAction { [weak self] _ in self?.onAction?() }, for: .primaryActionTriggered)
        cardButton.onFocus = { [weak self] in self?.updateAppearance() }
        isAccessibilityElement = false
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(item: ContentItem?, style: Style, viewAllTitle: String? = nil, loadingTitle: String? = nil, artworkOnly: Bool = false) {
        self.style = style
        NSLayoutConstraint.deactivate(styleConstraints)
        let metadata = item
        let title = style == .hero ? metadata?.titleBrief.flatMap { $0.isEmpty ? nil : $0 } ?? metadata?.title : metadata?.title
        titleLabel.text = viewAllTitle ?? loadingTitle ?? title ?? metadata?.longDescription ?? ""
        titleLabel.font = UIFont(name: "Formula1-Display-Bold", size: style == .hero ? 36 : 24)
        detailLabel.font = .systemFont(ofSize: style == .hero ? 24 : 21)
        detailLabel.numberOfLines = style == .hero ? 3 : 2
        if style == .hero {
            detailLabel.text = metadata?.longDescription
        } else if item?.objectType == .Video {
            detailLabel.text = [metadata?.uiDuration, metadata?.contentSubtype]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        } else {
            detailLabel.text = [metadata?.race?.meetingCountryName, metadata?.race?.meetingDisplayDate]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        }
        detailLabel.isHidden = detailLabel.text?.isEmpty ?? true
        seriesName = metadata?.race?.series ?? item?.series
        badge.configure(seriesName)
        badge.isHidden = artworkOnly || item?.objectType != .Video
        flag.kf.cancelDownloadTask(); flag.image = nil; flag.isHidden = true
        if let country = metadata?.race?.meetingCountryKey, !country.isEmpty, !artworkOnly {
            flag.isHidden = false
            flag.kf.setImage(with: URL(string: "https://ott-img.formula1.com/countries/\(country).png"))
        }
        titleLabel.isHidden = artworkOnly
        detailLabel.superview?.isHidden = artworkOnly || detailLabel.isHidden
        textStack.viewWithTag(925)?.isHidden = style != .hero
        actionButton.setTitle(item?.objectType == .Video ? "catalog_watch_now".localizedString : "catalog_explore".localizedString, for: .normal)
        actionButton.restingColor = ConstantsUtil.brandingItemColor
        actionButton.updateStyle()
        actionButton.isHidden = style != .hero
        moreButton.isHidden = style != .hero || (metadata?.longDescription?.count ?? 0) <= 220
        cardButton.isHidden = style == .hero
        isAccessibilityElement = false
        artwork.isHidden = viewAllTitle != nil || loadingTitle != nil
        gradient.isHidden = style != .hero
        let inset: CGFloat = style == .hero ? 32 : 18
        styleConstraints = [
            artwork.topAnchor.constraint(equalTo: contentView.topAnchor),
            artwork.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            artwork.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: inset),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -inset)
        ]
        if artworkOnly {
            styleConstraints += [artwork.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)]
            textStack.isHidden = true
        } else if style == .hero {
            textStack.isHidden = false
            styleConstraints += [artwork.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                                 textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)]
        } else if viewAllTitle != nil || loadingTitle != nil {
            textStack.isHidden = false
            styleConstraints += [textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)]
        } else {
            textStack.isHidden = false
            styleConstraints += [artwork.heightAnchor.constraint(equalTo: artwork.widthAnchor, multiplier: style == .poster ? 1.5 : 9.0 / 16.0),
                                 textStack.topAnchor.constraint(equalTo: artwork.bottomAnchor, constant: 16),
                                 textStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12)]
        }
        NSLayoutConstraint.activate(styleConstraints)
        artwork.configure(metadata?.pictureUrl, focusScale: style == .hero ? 1 : 1.025)
        accessibilityLabel = [titleLabel.text, detailLabel.text, style == .hero ? actionButton.title(for: .normal) : nil].compactMap { $0 }.joined(separator: ", ")
        actionButton.accessibilityLabel = accessibilityLabel
        cardButton.accessibilityLabel = accessibilityLabel
        updateAppearance()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        artwork.reset()
        flag.kf.cancelDownloadTask(); flag.kf.setImage(with: Optional<URL>.none)
        titleLabel.text = nil; detailLabel.text = nil; seriesName = nil; badge.configure(nil)
        accessibilityLabel = nil; cardButton.accessibilityLabel = nil; actionButton.accessibilityLabel = nil
        onAction = nil; onMore = nil
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations({ self.updateAppearance() }, completion: nil)
    }

    private func updateAppearance() {
        let focused = cardButton.isFocused
        contentView.backgroundColor = focused && style != .hero ? .white : ConstantsUtil.brandingItemColor
        let foreground: UIColor = focused && style != .hero ? .black : .white
        titleLabel.textColor = foreground
        detailLabel.textColor = foreground.withAlphaComponent(0.85)
        if !badge.isHidden { badge.configure(seriesName, foreground: foreground) }
        transform = focused ? CGAffineTransform(scaleX: 1.025, y: 1.025) : .identity
        layer.borderWidth = focused ? 3 : 0
        layer.borderColor = UIColor.white.cgColor
        layer.cornerRadius = 12
    }
}

final class CatalogHeaderView: UICollectionReusableView {
    static let reuseID = "CatalogHeaderView"
    private let titleLabel = UILabel()
    let actionButton = TVActionButton(type: .custom)
    var onAction: (() -> Void)?
    private let subtitleLabel = UILabel()
    weak var returnTarget: UIView?
    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 2; titleLabel.textColor = .white
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.setTitle("view_all".localizedString, for: .normal)
        actionButton.addAction(UIAction { [weak self] _ in self?.onAction?() }, for: .primaryActionTriggered)
        addSubview(titleLabel); addSubview(actionButton)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false; subtitleLabel.font = .systemFont(ofSize: 24); subtitleLabel.textColor = .secondaryLabel; subtitleLabel.numberOfLines = 2; addSubview(subtitleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor), titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8), titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 34),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor), subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor), subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8), subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -24),
            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor), actionButton.centerYAnchor.constraint(equalTo: centerYAnchor), actionButton.widthAnchor.constraint(equalToConstant: 190)

        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(title: String, layout: ContainerLayoutType, hasAction: Bool = false, subtitle: String? = nil) {
        titleLabel.text = title
        titleLabel.font = layout == .Subtitle ? .systemFont(ofSize: 24) : TVTypography.heading(layout == .Title ? 44 : 28)
        titleLabel.accessibilityTraits = .header
        actionButton.isHidden = !hasAction
        subtitleLabel.text = subtitle; subtitleLabel.isHidden = subtitle?.isEmpty != false
    }
    static func height(for section: ContentSection, width: CGFloat) -> CGFloat {
        let font = section.layoutType == .Subtitle ? UIFont.systemFont(ofSize: 24) : TVTypography.heading(section.layoutType == .Title ? 44 : 28)
        func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
            let bounds = (text as NSString).boundingRect(with: CGSize(width: max(100, width), height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil)
            return min(ceil(bounds.height), ceil(font.lineHeight * 2))
        }
        let titleHeight = max(34, textHeight(section.title, font: font, width: width - 214))
        let subtitle = section.subtitle
        return max(section.layoutType == .Title ? 76 : 52, titleHeight + 16 + (subtitle.isEmpty ? 0 : 8 + textHeight(subtitle, font: .systemFont(ofSize: 24), width: width)))
    }
    override func prepareForReuse() { super.prepareForReuse(); onAction = nil; returnTarget = nil }
}

final class CatalogBannerCell: UICollectionViewCell {
    static let reuseID = "CatalogBannerCell"
    private let artwork = CatalogArtworkImageView()
    private let shade = CatalogGradientView()
    private let countryLabel = UILabel()
    private let titleLabel = UILabel()
    private let detailsLabel = UILabel()
    private let flag = UIImageView()
    private let badge = CatalogSeriesBadge()
    private let descriptionLabel = TVDesign.label("", size: 24)
    private let more = TVActionButton(type: .custom)
    var onMore: (() -> Void)?
    private var floating = false
    override var preferredFocusEnvironments: [UIFocusEnvironment] { floating || more.isHidden ? [] : [more] }
    override var canBecomeFocused: Bool { floating }

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = 12
        artwork.contentMode = .scaleAspectFill
        artwork.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(artwork)
        shade.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        shade.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(shade)
        flag.contentMode = .scaleAspectFit
        flag.translatesAutoresizingMaskIntoConstraints = false
        countryLabel.font = .systemFont(ofSize: 24)
        let countryStack = UIStackView(arrangedSubviews: [flag, countryLabel])
        countryStack.spacing = 16
        titleLabel.font = TVTypography.heading(44)
        titleLabel.numberOfLines = 2
        detailsLabel.font = .systemFont(ofSize: 24)
        descriptionLabel.numberOfLines = 2
        more.setTitle("catalog_more".localizedString, for: .normal)
        more.addAction(UIAction { [weak self] _ in self?.onMore?() }, for: .primaryActionTriggered)
        let stack = UIStackView(arrangedSubviews: [countryStack, titleLabel, detailsLabel, badge, descriptionLabel, more])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        [countryLabel, titleLabel, detailsLabel].forEach { $0.textColor = .white }
        NSLayoutConstraint.activate([
            artwork.topAnchor.constraint(equalTo: contentView.topAnchor), artwork.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            artwork.leadingAnchor.constraint(equalTo: contentView.leadingAnchor), artwork.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            shade.topAnchor.constraint(equalTo: contentView.topAnchor), shade.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            shade.leadingAnchor.constraint(equalTo: contentView.leadingAnchor), shade.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32), stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            flag.widthAnchor.constraint(equalToConstant: 42), flag.heightAnchor.constraint(equalToConstant: 30)
        ])
        isAccessibilityElement = false
        accessibilityTraits = .header
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ item: ContentItem, floating: Bool = false) {
        self.floating = floating
        let metadata: ContentItem? = item
        let meeting = metadata?.race
        badge.configure(meeting?.series ?? item.series)
        let description = metadata?.longDescription ?? ""
        descriptionLabel.text = description; descriptionLabel.isHidden = description.isEmpty
        more.isHidden = description.count <= 220
        isAccessibilityElement = floating && more.isHidden
        countryLabel.text = meeting?.meetingCountryName
        titleLabel.text = meeting?.meetingOfficialName.flatMap { $0.isEmpty ? nil : $0 } ?? metadata?.title
        let round = meeting?.championshipMeetingOrdinal.flatMap { $0.isEmpty ? nil : $0 }.map { "\("catalog_round".localizedString) \($0)" }
        detailsLabel.text = [round, meeting?.meetingDisplayDate].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "  |  ")
        flag.kf.cancelDownloadTask()
        flag.image = nil
        if let countryID = meeting?.meetingCountryKey, !countryID.isEmpty {
            flag.kf.setImage(with: URL(string: "https://ott-img.formula1.com/countries/\(countryID).png"))
        }
        artwork.isHidden = floating; shade.isHidden = floating
        contentView.layer.cornerRadius = floating ? 0 : 12
        artwork.configure(floating ? nil : metadata?.pictureUrl)
        accessibilityLabel = [countryLabel.text, titleLabel.text, detailsLabel.text].compactMap { $0 }.joined(separator: ", ")
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        artwork.reset()
        flag.kf.cancelDownloadTask(); flag.kf.setImage(with: Optional<URL>.none)
        titleLabel.text = nil; countryLabel.text = nil; detailsLabel.text = nil; descriptionLabel.text = nil
        accessibilityLabel = nil; onMore = nil
    }
}

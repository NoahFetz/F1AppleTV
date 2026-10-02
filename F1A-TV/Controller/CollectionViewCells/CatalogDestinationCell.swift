import UIKit
import Kingfisher

final class CatalogDestinationCell: UICollectionViewCell {
    static let reuseID = "CatalogDestinationCell"
    private let artwork = CatalogArtworkImageView()
    private let shade = CatalogGradientView()
    private let title = TVDesign.label("", size: 44, bold: true)
    private let subtitle = TVDesign.label("", size: 24)
    private let descriptionLabel = TVDesign.label("", size: 24)
    private let flag = UIImageView()
    private let information = TVDesign.label("", size: 22)
    private let badge = CatalogSeriesBadge()
    private let more = TVActionButton(type: .custom)
    var onMore: (() -> Void)?
    private var floating = false
    override var canBecomeFocused: Bool { floating }
    override var preferredFocusEnvironments: [UIFocusEnvironment] { floating || more.isHidden ? [] : [more] }
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = true; contentView.layer.cornerRadius = 16
        artwork.contentMode = .scaleAspectFill
        shade.backgroundColor = .black.withAlphaComponent(0.3)
        [artwork, shade].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview($0) }
        flag.contentMode = .scaleAspectFit
        flag.widthAnchor.constraint(equalToConstant: 36).isActive = true; flag.heightAnchor.constraint(equalToConstant: 26).isActive = true
        let facts = UIStackView(arrangedSubviews: [flag, information]); facts.spacing = 12; facts.alignment = .center
        let stack = UIStackView(arrangedSubviews: [title, subtitle, facts, badge, descriptionLabel, more])
        stack.axis = .vertical; stack.spacing = 10; stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview(stack)
        title.numberOfLines = 2; descriptionLabel.numberOfLines = 3
        subtitle.textColor = .secondaryLabel; information.textColor = .secondaryLabel
        more.setTitle("catalog_more".localizedString, for: .normal)
        more.addAction(UIAction { [weak self] _ in self?.onMore?() }, for: .primaryActionTriggered)
        NSLayoutConstraint.activate([
            artwork.leadingAnchor.constraint(equalTo: contentView.leadingAnchor), artwork.trailingAnchor.constraint(equalTo: contentView.trailingAnchor), artwork.topAnchor.constraint(equalTo: contentView.topAnchor), artwork.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            shade.leadingAnchor.constraint(equalTo: contentView.leadingAnchor), shade.trailingAnchor.constraint(equalTo: contentView.trailingAnchor), shade.topAnchor.constraint(equalTo: contentView.topAnchor), shade.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32), stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32), stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            title.widthAnchor.constraint(equalTo: stack.widthAnchor), descriptionLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    static func height(for item: ContentItem, floating: Bool = false) -> CGFloat {
        let metadata: ContentItem? = item
        if !floating && metadata?.pictureUrl?.isEmpty == false { return 420 }
        let description = metadata?.longDescription ?? ""
        return description.isEmpty ? 180 : description.count > 220 ? 350 : 280
    }
    func configure(_ item: ContentItem, floating: Bool = false) {
        self.floating = floating
        accessibilityTraits = .header
        let m: ContentItem? = item
        title.text = m?.title; subtitle.text = m?.label; subtitle.isHidden = m?.label?.isEmpty != false
        accessibilityLabel = [m?.title, m?.label, m?.longDescription].compactMap { $0 }.joined(separator: ", ")
        let text = m?.longDescription ?? ""
        descriptionLabel.text = text; descriptionLabel.isHidden = text.isEmpty; more.isHidden = text.count <= 220
        isAccessibilityElement = floating && more.isHidden
        information.text = [m?.race?.meetingCountryName, m?.race?.meetingDisplayDate].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        information.superview?.isHidden = information.text?.isEmpty != false
        badge.configure(m?.race?.series ?? item.series)
        flag.kf.cancelDownloadTask(); flag.image = nil; flag.isHidden = true
        if let key = m?.race?.meetingCountryKey, !key.isEmpty {
            flag.isHidden = false; flag.kf.setImage(with: URL(string: "https://ott-img.formula1.com/countries/\(key).png"))
        }
        let hasArtwork = !floating && m?.pictureUrl?.isEmpty == false
        artwork.isHidden = !hasArtwork
        contentView.layer.cornerRadius = floating ? 0 : 16
        shade.isHidden = !hasArtwork
        artwork.configure(hasArtwork ? m?.pictureUrl : nil)
    }
    override func prepareForReuse() {
        super.prepareForReuse(); artwork.reset()
        flag.kf.cancelDownloadTask(); flag.kf.setImage(with: Optional<URL>.none)
        title.text = nil; subtitle.text = nil; descriptionLabel.text = nil; information.text = nil
        accessibilityLabel = nil; onMore = nil
    }
}

/// Native focusable paragraphs make long descriptions readable with the remote.
final class CatalogTextViewController: UITableViewController {
    private let paragraphs: [String]
    init(title: String, text: String) {
        var parts = [String](); var remaining = text[...]
        while !remaining.isEmpty {
            let end = remaining.index(remaining.startIndex, offsetBy: min(400, remaining.count))
            let split = end == remaining.endIndex ? end : remaining[..<end].lastIndex(where: \.isWhitespace) ?? end
            parts.append(String(remaining[..<split])); remaining = remaining[split...].drop(while: \.isWhitespace)
        }
        paragraphs = parts; super.init(style: .plain); self.title = title
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() { super.viewDidLoad(); tableView.overrideUserInterfaceStyle = .dark; let heading = TVDesign.label(title ?? "", size: 44, bold: true); heading.frame = CGRect(x: 64, y: 24, width: 1600, height: 72); let header = UIView(frame: CGRect(x: 0, y: 0, width: 1920, height: 120)); header.addSubview(heading); tableView.tableHeaderView = header; tableView.backgroundColor = ConstantsUtil.brandingBackgroundColor; tableView.register(UITableViewCell.self, forCellReuseIdentifier: "text"); tableView.rowHeight = UITableView.automaticDimension }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { paragraphs.count }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let bounds = (paragraphs[indexPath.row] as NSString).boundingRect(with: CGSize(width: max(300, tableView.bounds.width - 320), height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: UIFont.systemFont(ofSize: 26)], context: nil)
        return max(100, ceil(bounds.height) + 48)
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "text", for: indexPath)
        cell.contentConfiguration = nil
        let label = cell.contentView.viewWithTag(923) as? UILabel ?? UILabel()
        if label.superview == nil {
            label.tag = 923; label.translatesAutoresizingMaskIntoConstraints = false
            label.numberOfLines = 0; label.lineBreakMode = .byWordWrapping; label.font = .systemFont(ofSize: 26)
            cell.contentView.addSubview(label)
            NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 24), label.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -24), label.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 24), label.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -24)])
        }
        label.text = paragraphs[indexPath.row]; label.textColor = cell.isFocused ? .black : .white
        cell.accessibilityLabel = label.text
        cell.configurationUpdateHandler = { [weak label] _, state in label?.textColor = state.isFocused ? .black : .white }
        cell.backgroundColor = .clear; return cell
    }
}

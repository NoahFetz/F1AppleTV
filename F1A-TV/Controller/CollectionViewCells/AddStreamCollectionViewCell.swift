import UIKit

/// An empty layout slot remains quiet; focus belongs to its compact native action.
final class AddStreamCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "AddStreamCollectionViewCell"
    private let addButton: UIButton
    var onSelect: (() -> Void)?

    override var canBecomeFocused: Bool { false }
    override var preferredFocusEnvironments: [UIFocusEnvironment] { [addButton] }

    override init(frame: CGRect) {
        var configuration = UIButton.Configuration.glass()
        configuration.title = "add_stream".localizedString
        configuration.image = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .medium))
        configuration.imagePadding = 12
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .systemFont(ofSize: 24, weight: .medium)
            return attributes
        }
        addButton = UIButton(configuration: configuration)
        super.init(frame: frame)

        let slot = UIView()
        slot.isUserInteractionEnabled = false
        slot.backgroundColor = UIColor.white.withAlphaComponent(0.025)
        slot.layer.cornerRadius = 20
        slot.layer.borderWidth = 1
        slot.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        slot.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(slot)

        addButton.overrideUserInterfaceStyle = .dark
        addButton.tintColor = .white
        addButton.titleLabel?.adjustsFontSizeToFitWidth = true
        addButton.titleLabel?.minimumScaleFactor = 0.75
        addButton.accessibilityLabel = "add_stream".localizedString
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.addAction(UIAction { [weak self] _ in self?.onSelect?() }, for: .primaryActionTriggered)
        contentView.addSubview(addButton)
        NSLayoutConstraint.activate([
            slot.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            slot.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            slot.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            slot.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            addButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            addButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            addButton.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 28),
            addButton.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -28)
        ])
    }

    required init?(coder: NSCoder) { fatalError("Use programmatic registration") }

    override func prepareForReuse() {
        super.prepareForReuse()
        onSelect = nil
    }
}

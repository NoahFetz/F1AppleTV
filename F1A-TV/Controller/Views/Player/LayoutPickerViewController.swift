import UIKit

final class LayoutPickerViewController: UIViewController {
    let selected: MultiviewLayout
    let streamCount: Int
    let onSelect: (MultiviewLayout) -> Void
    private var selectedButton: UIButton?
    init(selected: MultiviewLayout, streamCount: Int, onSelect: @escaping (MultiviewLayout) -> Void) {
        self.selected = selected; self.streamCount = streamCount; self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var preferredFocusEnvironments: [UIFocusEnvironment] { selectedButton.map { [$0] } ?? super.preferredFocusEnvironments }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black.withAlphaComponent(0.65)
        let material = PlayerMaterial.makeView(cornerRadius: 28)
        material.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(material)
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 30; stack.translatesAutoresizingMaskIntoConstraints = false
        material.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            material.centerXAnchor.constraint(equalTo: view.centerXAnchor), material.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            material.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 100), material.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -100),
            stack.topAnchor.constraint(equalTo: material.contentView.topAnchor, constant: 40), stack.bottomAnchor.constraint(equalTo: material.contentView.bottomAnchor, constant: -40),
            stack.leadingAnchor.constraint(equalTo: material.contentView.leadingAnchor, constant: 36), stack.trailingAnchor.constraint(equalTo: material.contentView.trailingAnchor, constant: -36)
        ])
        stack.addArrangedSubview(TVDesign.label("layouts".localizedString, size: 36, bold: true))
        let row = UIStackView(); row.axis = .horizontal; row.spacing = 14; row.distribution = .fillEqually
        stack.addArrangedSubview(row)
        for choice in MultiviewLayout.allCases {
            let button = TVDesign.button(choice.titleKey.localizedString + (choice == selected ? " ✓" : "")) { [weak self] in
                guard let self else { return }
                self.onSelect(choice)
                self.dismiss(animated: true)
            }
            button.setImage(Self.illustration(choice), for: .normal)
            button.updateStyle()
            button.configuration?.imagePlacement = .top
            button.configuration?.imagePadding = 20
            button.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes; attributes.font = UIFont.systemFont(ofSize: 22, weight: .medium); return attributes
            }
            button.isEnabled = choice.supports(count: streamCount)
            button.alpha = button.isEnabled ? 1 : 0.35
            button.accessibilityLabel = choice.titleKey.localizedString
            button.accessibilityValue = choice == selected ? "selected".localizedString : nil
            if choice == selected { selectedButton = button }
            row.addArrangedSubview(button)
        }
        stack.addArrangedSubview(TVDesign.label("layout_capacity_help".localizedString, size: 23))
    }
    private static func illustration(_ choice: MultiviewLayout) -> UIImage {
        let count = choice.capacity ?? (choice == .grid ? 4 : 3)
        let canvas = CGRect(x: 4, y: 4, width: 124, height: 70)
        let frames = PlayerLayoutGeometry(layout: choice, count: count, bounds: canvas).frames
        return UIGraphicsImageRenderer(size: CGSize(width: 132, height: 78)).image { context in
            UIColor.white.setFill()
            for frame in frames {
                if choice == .inset, frame != frames.first {
                    context.cgContext.setBlendMode(.clear); context.cgContext.setLineWidth(4); context.cgContext.stroke(frame)
                    context.cgContext.setBlendMode(.normal)
                }
                context.cgContext.fill(frame.insetBy(dx: 2, dy: 2))
            }
        }.withRenderingMode(.alwaysTemplate)
    }
}

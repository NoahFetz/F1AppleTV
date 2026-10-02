import UIKit

struct CatalogScheduleState {
    var groupName = "ALL"
    var expanded = true
}

private final class CatalogScheduleButton: UIButton {
    override var canBecomeFocused: Bool { isEnabled }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations({
            self.backgroundColor = self.isFocused ? .white : ConstantsUtil.brandingItemColor
            self.setTitleColor(self.isFocused ? .black : .white, for: .normal)
            self.transform = self.isFocused ? CGAffineTransform(scaleX: 1.025, y: 1.025) : .identity
        }, completion: nil)
    }
}

final class CatalogScheduleView: UICollectionReusableView {
    static let reuseID = "CatalogScheduleView"
    static let elementKind = "CatalogSchedule"
    private var contentView: UIView { self }
    private let controlsScroll = UIScrollView()
    private let controls = UIStackView()
    private let daysScroll = UIScrollView()
    private let dayColumns = UIStackView()
    private var schedule: CatalogSchedule?
    private var state = CatalogScheduleState()
    private var filterButtons = [UIButton]()
    private var toggleButton: UIButton?
    var onStateChange: ((CatalogScheduleState) -> Void)?
    var onSelect: ((ContentItem) -> Void)?
    override var canBecomeFocused: Bool { false }
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        toggleButton.map { [$0] } ?? super.preferredFocusEnvironments
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        controls.axis = .horizontal
        controls.spacing = 16
        dayColumns.axis = .horizontal
        dayColumns.alignment = .top
        dayColumns.spacing = 24
        for (scroll, stack) in [(controlsScroll, controls), (daysScroll, dayColumns)] {
            scroll.translatesAutoresizingMaskIntoConstraints = false
            scroll.showsHorizontalScrollIndicator = false
            stack.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(scroll)
            scroll.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
                stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -8),
                stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 8),
                stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -8)
            ])
        }
        NSLayoutConstraint.activate([
            controlsScroll.topAnchor.constraint(equalTo: contentView.topAnchor),
            controlsScroll.leadingAnchor.constraint(equalTo: contentView.leadingAnchor), controlsScroll.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            controlsScroll.heightAnchor.constraint(equalToConstant: 82),
            controls.heightAnchor.constraint(equalTo: controlsScroll.frameLayoutGuide.heightAnchor, constant: -16),
            daysScroll.topAnchor.constraint(equalTo: controlsScroll.bottomAnchor, constant: 12),
            daysScroll.leadingAnchor.constraint(equalTo: contentView.leadingAnchor), daysScroll.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            daysScroll.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func height(schedule: CatalogSchedule, state: CatalogScheduleState) -> CGFloat {
        guard state.expanded else { return 100 }
        let count = schedule.days(groupName: state.groupName).map { $0.events.count }.max() ?? 0
        return 160 + CGFloat(count) * 108
    }

    func configure(schedule: CatalogSchedule, state: CatalogScheduleState) {
        self.schedule = schedule
        self.state = state
        controls.arrangedSubviews.forEach { $0.removeFromSuperview() }
        filterButtons.removeAll()
        let toggle = makeButton(title: "", width: 240)
        toggle.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.state.expanded.toggle()
            self.renderDays()
            self.updateControls()
            self.onStateChange?(self.state)
        }, for: .primaryActionTriggered)
        controls.addArrangedSubview(toggle)
        toggleButton = toggle
        for group in schedule.groups {
            let button = makeButton(title: group.label, width: max(100, CGFloat(group.label.count) * 18 + 32))
            button.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.state.groupName = group.name
                self.renderDays()
                self.updateControls()
                self.daysScroll.setContentOffset(.zero, animated: false)
                self.onStateChange?(self.state)
            }, for: .primaryActionTriggered)
            controls.addArrangedSubview(button)
            filterButtons.append(button)
        }
        updateControls()
        renderDays()
    }

    private func updateControls() {
        toggleButton?.setTitle((state.expanded ? "catalog_collapse_schedule" : "catalog_expand_schedule").localizedString, for: .normal)
        for (index, group) in (schedule?.groups ?? []).enumerated() {
            let button = filterButtons[index]
            button.layer.borderWidth = group.name == state.groupName ? 2 : 0
            button.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
            button.accessibilityTraits = group.name == state.groupName ? [.button, .selected] : .button
        }
    }

    private func renderDays() {
        dayColumns.arrangedSubviews.forEach { $0.removeFromSuperview() }
        daysScroll.isHidden = !state.expanded
        guard state.expanded, let schedule else { return }
        let dayFormatter = DateFormatter()
        dayFormatter.setLocalizedDateFormatFromTemplate("EEEE d MMM")
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        for day in schedule.days(groupName: state.groupName) {
            let column = UIStackView()
            column.axis = .vertical
            column.spacing = 12
            column.translatesAutoresizingMaskIntoConstraints = false
            column.widthAnchor.constraint(equalToConstant: 350).isActive = true
            let heading = UILabel()
            heading.font = .systemFont(ofSize: 23, weight: .semibold)
            heading.textColor = .white
            heading.text = day.date.map { dayFormatter.string(from: $0) } ?? "catalog_schedule_tba".localizedString
            heading.heightAnchor.constraint(equalToConstant: 36).isActive = true
            column.addArrangedSubview(heading)
            for event in day.events {
                let metadata: ContentItem? = event
                let time = CatalogSchedule.startDate(event).map { timeFormatter.string(from: $0) } ?? "catalog_schedule_tba".localizedString
                let series = metadata?.race?.series ?? event.series ?? ""
                let title = metadata?.titleBrief.flatMap { $0.isEmpty ? nil : $0 } ?? metadata?.longDescription ?? metadata?.title ?? ""
                let button = makeButton(title: "\(time)  \(series)\n\(title)", width: 350)
                let color = SeriesType.fromCapitalDisplayName(capitalDisplayName: series).getColor()
                let stripe = UIView(); stripe.backgroundColor = color
                stripe.translatesAutoresizingMaskIntoConstraints = false; stripe.isUserInteractionEnabled = false
                button.addSubview(stripe)
                NSLayoutConstraint.activate([stripe.leadingAnchor.constraint(equalTo: button.leadingAnchor), stripe.topAnchor.constraint(equalTo: button.topAnchor, constant: 8), stripe.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -8), stripe.widthAnchor.constraint(equalToConstant: 4)])
                if series.uppercased() == "F1 ACADEMY" {
                    let gradient = CAGradientLayer()
                    gradient.colors = [UIColor.cyan.cgColor, UIColor(rgb: 0xbc0f80).cgColor]
                    gradient.frame = CGRect(x: 0, y: 0, width: 4, height: 80)
                    stripe.layer.addSublayer(gradient)
                }
                button.isEnabled = CatalogSchedule.canPlay(event)
                button.alpha = button.isEnabled ? 1 : 0.55
                button.heightAnchor.constraint(equalToConstant: 96).isActive = true
                button.addAction(UIAction { [weak self] _ in
                    guard CatalogSchedule.canPlay(event) else { return }
                    self?.onSelect?(event)
                }, for: .primaryActionTriggered)
                column.addArrangedSubview(button)
            }
            dayColumns.addArrangedSubview(column)
        }
    }

    private func makeButton(title: String, width: CGFloat) -> UIButton {
        let button = CatalogScheduleButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 23, weight: .medium)
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = ConstantsUtil.brandingItemColor
        button.layer.cornerRadius = 10
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        return button
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onStateChange = nil
        onSelect = nil
        daysScroll.contentOffset = .zero
        controlsScroll.contentOffset = .zero
    }
}

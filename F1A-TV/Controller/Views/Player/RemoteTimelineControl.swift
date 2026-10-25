import UIKit
import F1Core

// Both controls consume horizontal input only; UIKit retains vertical navigation.
final class HorizontalRemoteInput: NSObject, UIGestureRecognizerDelegate {
    private weak var view: UIView?
    var onStep: ((TransportDirection) -> Void)?
    var onHold: ((TransportDirection, Bool) -> Void)?
    var onPan: ((Double) -> Void)?
    var onPanEnd: (() -> Void)?
    private var previousTranslation: CGFloat = 0

    init(view: UIView) {
        self.view = view
        super.init()
        for direction in [TransportDirection.backward, .forward] {
            let press = direction == .backward ? UIPress.PressType.leftArrow : .rightArrow
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
            tap.allowedPressTypes = [NSNumber(value: press.rawValue)]
            tap.name = String(direction.rawValue)
            tap.delegate = self
            let hold = UILongPressGestureRecognizer(target: self, action: #selector(held))
            hold.allowedPressTypes = tap.allowedPressTypes
            hold.minimumPressDuration = 0.45
            hold.name = tap.name
            hold.delegate = self
            tap.require(toFail: hold)
            view.addGestureRecognizer(tap)
            view.addGestureRecognizer(hold)
        }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned))
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard view?.isFocused == true else { return false }
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = pan.velocity(in: view)
            return abs(velocity.x) > abs(velocity.y)
        }
        return true
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, let direction = direction(recognizer) else { return }
        onStep?(direction)
    }

    @objc private func held(_ recognizer: UILongPressGestureRecognizer) {
        guard let direction = direction(recognizer) else { return }
        if recognizer.state == .began { onHold?(direction, true) }
        else if recognizer.state == .ended || recognizer.state == .cancelled { onHold?(direction, false) }
    }

    @objc private func panned(_ recognizer: UIPanGestureRecognizer) {
        guard let view, view.bounds.width > 0 else { return }
        if recognizer.state == .began { previousTranslation = 0 }
        if recognizer.state == .began || recognizer.state == .changed || recognizer.state == .ended {
            let translation = recognizer.translation(in: view).x
            onPan?(Double((translation - previousTranslation) / view.bounds.width))
            previousTranslation = translation
        }
        if recognizer.state == .ended || recognizer.state == .cancelled { onPanEnd?() }
    }

    private func direction(_ recognizer: UIGestureRecognizer) -> TransportDirection? {
        recognizer.name.flatMap(Int.init).flatMap(TransportDirection.init(rawValue:))
    }
}

final class RemoteTimelineControl: UIControl {
    var value: Float = 0 { didSet { setNeedsLayout() } }
    var onStep: ((TransportDirection) -> Void)?
    var onHold: ((TransportDirection) -> Void)?
    var onPanSeconds: ((Double) -> Void)?
    var onConfirm: (() -> Void)?
    private let track = UIView()
    private let played = UIView()
    private let thumb = UIView()
    private var input: HorizontalRemoteInput!

    override var canBecomeFocused: Bool { isEnabled }

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityIdentifier = "multiview.timeline"
        accessibilityLabel = "multiview_playback_position".localizedString
        accessibilityTraits = [.adjustable]
        track.backgroundColor = UIColor.white.withAlphaComponent(0.28)
        played.backgroundColor = .white
        thumb.backgroundColor = .white
        [track, played, thumb].forEach { addSubview($0) }
        input = HorizontalRemoteInput(view: self)
        input.onStep = { [weak self] in self?.onStep?($0) }
        input.onHold = { [weak self] direction, began in if began { self?.onHold?(direction) } }
        input.onPan = { [weak self] fraction in self?.onPanSeconds?(fraction * 120) }
        let select = UITapGestureRecognizer(target: self, action: #selector(confirm))
        select.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        select.delegate = input
        addGestureRecognizer(select)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset: CGFloat = 18
        let width = max(0, bounds.width - inset * 2)
        let x = inset + width * CGFloat(min(max(value, 0), 1))
        let height: CGFloat = isFocused ? 9 : 5
        track.frame = CGRect(x: inset, y: bounds.midY - height / 2, width: width, height: height)
        played.frame = CGRect(x: inset, y: track.frame.minY, width: x - inset, height: height)
        let size: CGFloat = isFocused ? 32 : 20
        thumb.frame = CGRect(x: x - size / 2, y: bounds.midY - size / 2, width: size, height: size)
        [track, played].forEach { $0.layer.cornerRadius = height / 2 }
        thumb.layer.cornerRadius = size / 2
        thumb.layer.shadowColor = UIColor.white.cgColor
        thumb.layer.shadowRadius = 12
        thumb.layer.shadowOpacity = isFocused ? 0.7 : 0
        alpha = isEnabled ? 1 : 0.4
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations { self.setNeedsLayout(); self.layoutIfNeeded() }
    }

    override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
        let vertical = context.focusHeading.contains(.up) || context.focusHeading.contains(.down)
        if context.previouslyFocusedView === self && !vertical && (context.focusHeading.contains(.left) || context.focusHeading.contains(.right)) { return false }
        return super.shouldUpdateFocus(in: context)
    }

    override func accessibilityIncrement() { onStep?(.forward) }
    override func accessibilityDecrement() { onStep?(.backward) }
    @objc private func confirm() { if isEnabled { onConfirm?() } }
}

import UIKit

enum PlayerMaterial {
    static func makeView(cornerRadius: CGFloat) -> UIVisualEffectView {
        let effect = UIGlassEffect(style: .regular)
        let view = UIVisualEffectView(effect: effect)
        view.overrideUserInterfaceStyle = .dark
        view.layer.cornerRadius = cornerRadius
        view.clipsToBounds = true
        return view
    }
}

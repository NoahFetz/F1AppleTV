import UIKit

/// Shared management screen; player callers additionally provide save/load actions.
final class SetupPickerViewController: UIViewController {
    var snapshot: (() -> MultiviewSetup?)?
    var onLoad: ((MultiviewSetup) -> Void)?
    private let store: MultiviewSetupStore
    private var stack: UIStackView!
    private var observation: NSObjectProtocol?
    private weak var lastFocusedControl: UIView?
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if let lastFocusedControl, lastFocusedControl.window != nil { return [lastFocusedControl] }
        return stack?.arrangedSubviews.compactMap { $0 as? UIButton }.first.map { [$0] } ?? super.preferredFocusEnvironments
    }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if let next = context.nextFocusedView, next.isDescendant(of: view) { lastFocusedControl = next }
    }
    init(store: MultiviewSetupStore? = nil) { self.store = store ?? .shared; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        stack = TVDesign.stack(in: view, title: "saved_setups".localizedString)
        render()
        observation = NotificationCenter.default.addObserver(forName: MultiviewSetupStore.didChange, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.render() }
        }
    }
    deinit { if let observation { NotificationCenter.default.removeObserver(observation) } }
    private func render() {
        stack.arrangedSubviews.dropFirst().forEach { $0.removeFromSuperview() }
        if snapshot != nil {
            stack.addArrangedSubview(TVDesign.button("save_current_setup".localizedString) { [weak self] in
                guard let self, let setup = self.snapshot?() else { return }
                self.editName(setup, isNew: true)
            })
        }
        let setups = store.load()
        if setups.isEmpty { stack.addArrangedSubview(TVDesign.label("setups_empty".localizedString)) }
        if onLoad != nil { stack.addArrangedSubview(TVDesign.label("setup_load_help".localizedString, size: 23)) }
        for setup in setups {
            let summary = setup.name + " · " + setup.layout.titleKey.localizedString + " · " + String(setup.streams.count)
            stack.addArrangedSubview(TVDesign.button(summary) { [weak self] in self?.showActions(setup) })
        }
        stack.addArrangedSubview(TVDesign.button("close".localizedString) { [weak self] in self?.dismiss(animated: true) })
    }
    private func showActions(_ setup: MultiviewSetup) {
        let alert = UIAlertController(title: setup.name, message: nil, preferredStyle: .actionSheet)
        if let onLoad {
            alert.addAction(UIAlertAction(title: "load_setup".localizedString, style: .default) { [weak self] _ in
                self?.dismiss(animated: true) { onLoad(setup) }
            })
        }
        alert.addAction(UIAlertAction(title: "rename_setup".localizedString, style: .default) { [weak self] _ in self?.editName(setup, isNew: false) })
        alert.addAction(UIAlertAction(title: "delete_setup".localizedString, style: .destructive) { [weak self] _ in
            guard let self else { return }
            let confirmation = UIAlertController(title: "delete_setup".localizedString, message: setup.name, preferredStyle: .alert)
            confirmation.addAction(UIAlertAction(title: "delete_setup".localizedString, style: .destructive) { [weak self] _ in
                self?.perform { try self?.store.delete(id: setup.id) }
            })
            confirmation.addAction(UIAlertAction(title: "cancel".localizedString, style: .cancel))
            self.present(confirmation, animated: true)
        })
        alert.addAction(UIAlertAction(title: "cancel".localizedString, style: .cancel))
        present(alert, animated: true)
    }
    private func editName(_ setup: MultiviewSetup, isNew: Bool) {
        let alert = UIAlertController(title: (isNew ? "save_current_setup" : "rename_setup").localizedString, message: nil, preferredStyle: .alert)
        alert.addTextField { field in field.text = setup.name; field.placeholder = "setup_name".localizedString }
        alert.addAction(UIAlertAction(title: "save_setup".localizedString, style: .default) { [weak self, weak alert] _ in
            guard let self, let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return }
            var edited = setup; edited.name = name
            self.perform { try self.store.save(edited) }
        })
        alert.addAction(UIAlertAction(title: "cancel".localizedString, style: .cancel))
        present(alert, animated: true)
    }
    private func perform(_ action: () throws -> Void) {
        do { try action() } catch {
            UserInteractionHelper.instance.showError(title: "error".localizedString, message: "setup_save_failed".localizedString)
        }
    }
}

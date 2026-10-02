import UIKit

final class ErrorLogViewController: UITableViewController {
    private var entries = [AppErrorRecord]()
    private let store: AppErrorStoring
    init(store: AppErrorStoring = AppErrorStore.shared) { self.store = store; super.init(style: .plain) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "diagnostics_error_log".localizedString
        tableView.overrideUserInterfaceStyle = .dark; tableView.tintColor = .white
        let heading = TVDesign.label(title ?? "", size: 44, bold: true)
        heading.frame = CGRect(x: 64, y: 24, width: 1600, height: 72)
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 1920, height: 120)); header.addSubview(heading); tableView.tableHeaderView = header
        tableView.backgroundColor = ConstantsUtil.brandingBackgroundColor
        tableView.rowHeight = 112
        tableView.remembersLastFocusedIndexPath = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "error")
        NotificationCenter.default.addObserver(self, selector: #selector(reloadHistory), name: AppErrorStore.changed, object: nil)
        reloadHistory()
    }
    @objc private func reloadHistory() {
        entries = store.records(); tableView.reloadData()
        let empty = TVDesign.label("diagnostics_empty".localizedString, size: 26)
        empty.textAlignment = .center
        tableView.backgroundView = entries.isEmpty ? empty : nil
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { entries.count + 1 }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "error", for: indexPath)
        var config = cell.defaultContentConfiguration()
        if indexPath.row == entries.count {
            config.text = (entries.isEmpty ? "close" : "diagnostics_clear").localizedString; config.image = UIImage(systemName: entries.isEmpty ? "xmark" : "trash")
        } else {
            let entry = entries[indexPath.row]
            config.text = ("diagnostics_operation_" + entry.operation.rawValue).localizedString + " · " + entry.summaryKey.localizedString
            config.secondaryText = DateFormatter.localizedString(from: entry.lastTimestamp, dateStyle: .medium, timeStyle: .medium) + (entry.repeatCount > 1 ? " · ×\(entry.repeatCount)" : "")
            config.image = UIImage(systemName: "exclamationmark.circle")
        }
        config.textProperties.font = .systemFont(ofSize: 25, weight: .medium)
        config.secondaryTextProperties.font = .systemFont(ofSize: 21)
        cell.contentConfiguration = config; cell.backgroundColor = .clear
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == entries.count {
            guard !entries.isEmpty else { dismiss(animated: true); return }
            let alert = UIAlertController(title: "diagnostics_clear".localizedString, message: "diagnostics_clear_confirm".localizedString, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "close".localizedString, style: .cancel))
            alert.addAction(UIAlertAction(title: "diagnostics_clear".localizedString, style: .destructive) { [weak self] _ in self?.store.clear() })
            present(alert, animated: true); return
        }
        let entry = entries[indexPath.row]
        let panel = UIViewController(); panel.view.backgroundColor = ConstantsUtil.brandingBackgroundColor
        let stack = TVDesign.stack(in: panel.view, title: ("diagnostics_operation_" + entry.operation.rawValue).localizedString)
        stack.addArrangedSubview(TVDesign.label(entry.summaryKey.localizedString))
        let first = DateFormatter.localizedString(from: entry.firstTimestamp, dateStyle: .medium, timeStyle: .medium)
        let last = DateFormatter.localizedString(from: entry.lastTimestamp, dateStyle: .medium, timeStyle: .medium)
        var details = "\("diagnostics_first".localizedString): \(first)\n\("diagnostics_last".localizedString): \(last)\n\("diagnostics_count".localizedString): \(entry.repeatCount)\n\(entry.domain): \(entry.code)"
        if let context = entry.catalogContext {
            details += "\n" + ("diagnostics_catalog_" + context.reason.rawValue).localizedString
            if let index = context.sectionIndex { details += " · " + String(format: "diagnostics_catalog_section".localizedString, index + 1) }
            if let index = context.itemIndex { details += " · " + String(format: "diagnostics_catalog_item".localizedString, index + 1) }
        }
        if let status = entry.httpStatus { details += "\nHTTP: \(status)" }
        stack.addArrangedSubview(TVDesign.label(details, size: 24))
        stack.addArrangedSubview(TVDesign.button("close".localizedString) { [weak panel] in panel?.dismiss(animated: true) })
        present(panel, animated: true)
    }
    deinit { NotificationCenter.default.removeObserver(self) }
}

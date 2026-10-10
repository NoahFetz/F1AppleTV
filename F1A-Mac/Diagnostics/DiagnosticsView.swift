import SwiftUI
import F1Core

struct DiagnosticsView: View {
    @State private var records = AppErrorStore.shared.records()
    var body: some View {
        VStack(alignment: .leading) {
            HStack { Text("Error Log").font(.largeTitle.bold()); Spacer(); Button("Clear") { AppErrorStore.shared.clear(); records = [] }.disabled(records.isEmpty) }.padding(24)
            if records.isEmpty { ContentUnavailableView("No recorded errors", systemImage: "checkmark.circle") }
            else {
                List(records) { record in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack { Text(record.operation.rawValue).font(.headline); Spacer(); Text(record.lastTimestamp.formatted()).font(.caption).foregroundStyle(.secondary) }
                        Text(record.summaryKey.localizedString)
                        Text("\(record.domain) · \(record.code)" + (record.httpStatus.map { " · HTTP \($0)" } ?? "") + (record.repeatCount > 1 ? " · \(record.repeatCount) occurrences" : "")).font(.caption).foregroundStyle(.secondary)
                        if let causes = record.underlyingErrors, !causes.isEmpty {
                            Text(causes.map { "\($0.domain) · \($0.code)" }.joined(separator: " → ")).font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 6).textSelection(.enabled)
                }
            }
        }.onReceive(NotificationCenter.default.publisher(for: AppErrorStore.changed)) { _ in records = AppErrorStore.shared.records() }
    }
}

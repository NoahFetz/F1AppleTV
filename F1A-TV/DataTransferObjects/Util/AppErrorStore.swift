import Foundation

enum AppErrorCategory: String, Codable { case catalog, account, credentials, playback, drm, preview, application }
enum AppErrorOperation: String, Codable {
    case menu, page, video, login, logout, credentials, tokenRefresh, entitlement, certificate, license, preparation, playback, preview, action
    var category: AppErrorCategory {
        switch self {
        case .menu, .page, .video: return .catalog
        case .login, .logout, .tokenRefresh: return .account
        case .credentials: return .credentials
        case .certificate, .license: return .drm
        case .preparation, .playback, .entitlement: return .playback
        case .preview: return .preview
        case .action: return .application
        }
    }
}
struct CatalogDiagnostic: Codable, Equatable, Sendable {
    enum Scope: String, Codable, Sendable { case menu, page }
    enum Reason: String, Codable, Sendable { case unsupportedLayout, malformedSibling, unusableVideo, invalidAction }
    var scope: Scope = .page
    var sectionIndex: Int? = nil
    var itemIndex: Int? = nil
    let reason: Reason
    var safe: CatalogDiagnostic? {
        guard [sectionIndex, itemIndex].compactMap({ $0 }).allSatisfy({ (0...1_000_000).contains($0) }) else { return nil }; return self
    }
}
struct AppErrorRecord: Codable, Identifiable {
    let id: UUID
    let category: AppErrorCategory
    let operation: AppErrorOperation
    let firstTimestamp: Date
    var lastTimestamp: Date
    let summaryKey: String
    let domain: String
    let code: Int
    let httpStatus: Int?
    var repeatCount: Int
    var catalogContext: CatalogDiagnostic? = nil
}
protocol AppErrorStoring: AnyObject {
    func records() -> [AppErrorRecord]
    func record(_ error: Error, operation: AppErrorOperation, httpStatus: Int?)
    func clear()
}

/// Only structured, allowlisted fields are persisted; error messages and request data never enter storage.
final class AppErrorStore: AppErrorStoring {
    static let shared = AppErrorStore(defaults: .standard)
    static let changed = Notification.Name("AppErrorHistoryChanged")
    private let defaults: UserDefaults
    private let key = "AppErrorHistory.v1"
    private let clock: () -> Date
    private let lock = NSLock()
    private var entries: [AppErrorRecord]
    init(defaults: UserDefaults, clock: @escaping () -> Date = Date.init) {
        self.defaults = defaults; self.clock = clock
        entries = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([AppErrorRecord].self, from: $0) } ?? []
        entries = entries.filter { $0.repeatCount > 0 && $0.firstTimestamp <= $0.lastTimestamp }.map { entry in
            let domain = Self.safeDomain(entry.domain)
            let status = entry.httpStatus.flatMap { (100...599).contains($0) ? $0 : nil }
            return AppErrorRecord(id: entry.id, category: entry.operation.category, operation: entry.operation, firstTimestamp: entry.firstTimestamp, lastTimestamp: entry.lastTimestamp, summaryKey: Self.summary(domain: domain, status: status), domain: domain, code: entry.code, httpStatus: status, repeatCount: entry.repeatCount, catalogContext: entry.catalogContext?.safe)
        }
        prune(); persist()
    }
    func records() -> [AppErrorRecord] {
        lock.lock(); defer { lock.unlock() }
        prune(); persist(); return entries.sorted { $0.lastTimestamp > $1.lastTimestamp }
    }
    func record(_ error: Error, operation: AppErrorOperation, httpStatus: Int? = nil) {
        record(error, operation: operation, httpStatus: httpStatus, catalogContext: nil)
    }
    func record(_ error: Error, operation: AppErrorOperation, httpStatus: Int? = nil, catalogContext: CatalogDiagnostic?) {
        let catalogContext = catalogContext?.safe
        guard !Self.isCancellation(error) else { return }
        let value = error as NSError
        let domain = Self.safeDomain(value.domain)
        let status = httpStatus.flatMap { (100...599).contains($0) ? $0 : nil }
        let summary = Self.summary(domain: domain, status: status)
        lock.lock(); let now = clock(); prune()
        if let index = entries.firstIndex(where: { $0.operation == operation && $0.domain == domain && $0.code == value.code && $0.httpStatus == status && $0.catalogContext == catalogContext && now.timeIntervalSince($0.lastTimestamp) >= 0 && now.timeIntervalSince($0.lastTimestamp) <= 60 }) {
            entries[index].lastTimestamp = now; entries[index].repeatCount += 1
        } else {
            entries.append(AppErrorRecord(id: UUID(), category: operation.category, operation: operation, firstTimestamp: now, lastTimestamp: now, summaryKey: summary, domain: domain, code: value.code, httpStatus: status, repeatCount: 1, catalogContext: catalogContext))
        }
        prune(); persist(); lock.unlock(); notify()
    }
    func clear() { lock.lock(); entries.removeAll(); persist(); lock.unlock(); notify() }
    private func prune() {
        let cutoff = clock().addingTimeInterval(-7 * 24 * 3600)
        entries = Array(entries.filter { $0.lastTimestamp >= cutoff && $0.lastTimestamp <= clock().addingTimeInterval(60) }.sorted { $0.lastTimestamp > $1.lastTimestamp }.prefix(100))
    }
    private func persist() { if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: key) } }
    private func notify() { DispatchQueue.main.async { NotificationCenter.default.post(name: Self.changed, object: self) } }
    private static func summary(domain: String, status: Int?) -> String {
        status != nil ? "diagnostics_summary_http" : domain == NSURLErrorDomain ? "diagnostics_summary_network" : domain == NSCocoaErrorDomain ? "diagnostics_summary_storage" : "diagnostics_summary_operation"
    }
    private static func safeDomain(_ domain: String) -> String {
        let known = [NSURLErrorDomain, NSCocoaErrorDomain, NSOSStatusErrorDomain, "AVFoundationErrorDomain", "CoreMediaErrorDomain", "Alamofire.AFError", "Application"]
        return known.contains(domain) ? domain : "Application"
    }
    static func isCancellation(_ error: Error, depth: Int = 0) -> Bool {
        if error is CancellationError { return true }
        guard depth < 8 else { return false }
        let error = error as NSError
        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled { return true }
        return (error.userInfo[NSUnderlyingErrorKey] as? Error).map { isCancellation($0, depth: depth + 1) } ?? false
    }
}

/// Delivers an owned failure after saving diagnostics, including inline-only error handlers.
enum AppErrorReporting {
    static func deliver(_ error: Error, operation: AppErrorOperation, httpStatus: Int? = nil,
                        store: AppErrorStoring = AppErrorStore.shared, isCurrent: () -> Bool = { true },
                        failureHandler: (Error) -> Void) {
        guard isCurrent(), !AppErrorStore.isCancellation(error) else { return }
        store.record(error, operation: operation, httpStatus: httpStatus)
        failureHandler(error)
    }
}

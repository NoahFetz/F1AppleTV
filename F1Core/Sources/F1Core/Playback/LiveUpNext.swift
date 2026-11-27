import Foundation
import SwiftUI

public struct LiveUpNextNotice {
    public enum State: Equatable {
        case starting(seconds: Int)
        case waiting
        case live
    }

    public let item: ContentItem
    public let state: State

    static func next(in items: [ContentItem], excluding: Set<String>, now: Date) -> Self? {
        items.compactMap { item -> (Self, Date)? in
            guard item.contentSubtype == "LIVE", item.locked != true, let id = item.contentId,
                  !excluding.contains(id), let start = item.coverageStartsAt else { return nil }
            let interval = start.timeIntervalSince(now)
            guard abs(interval) <= 120 else { return nil }
            let state: State = interval > 0 ? .starting(seconds: Int(interval.rounded(.up))) : (item.canPlay ? .live : .waiting)
            return (Self(item: item, state: state), start)
        }.min { $0.1 < $1.1 }?.0
    }
}

@MainActor
public final class LiveUpNextMonitor: ObservableObject {
    @Published public private(set) var notice: LiveUpNextNotice?
    private var task: Task<Void, Never>?
    private var contentID: String?
    private var dismissed = Set<String>()

    public init() {}

    public func start(for id: String, catalog: F1PersonalizedCatalog) {
        guard contentID != id else { return }
        stop()
        contentID = id
        task = Task { [weak self] in
            while !Task.isCancelled {
                let items = await catalog.upcomingStreams(for: id)
                let refreshedAt = Date()
                while !Task.isCancelled, let self {
                    let now = Date()
                    self.update(with: items, excluding: id, now: now)
                    if now.timeIntervalSince(refreshedAt) >= (self.notice == nil ? 60 : 15) { break }
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                }
                guard self != nil else { return }
            }
        }
    }

    public func dismiss() {
        if let id = notice?.item.contentId { dismissed.insert(id) }
        notice = nil
    }

    public func stop() {
        task?.cancel()
        task = nil
        contentID = nil
        dismissed.removeAll()
        if notice != nil { notice = nil }
    }

    private func update(with items: [ContentItem], excluding currentID: String, now: Date) {
        let next = LiveUpNextNotice.next(in: items, excluding: dismissed.union([currentID]), now: now)
        guard next?.item.contentId != notice?.item.contentId || next?.state != notice?.state else { return }
        notice = next
    }

    deinit { task?.cancel() }
}

public struct LiveUpNextBanner: View {
    @ObservedObject private var monitor: LiveUpNextMonitor
    private let watch: ((ContentItem) -> Void)?

    public init(monitor: LiveUpNextMonitor, watch: ((ContentItem) -> Void)? = nil) {
        self.monitor = monitor
        self.watch = watch
    }

    public var body: some View {
        if let notice = monitor.notice {
            VStack(alignment: .leading, spacing: 8) {
                Text(status(notice.state)).font(.subheadline.weight(.semibold)).monospacedDigit()
                Text(notice.item.title ?? notice.item.titleBrief ?? "catalog_up_next".localizedString)
                    .font(.headline)
                    .lineLimit(2)
                if let watch {
                    HStack {
                        if notice.state == .live {
                            Button("playback_watch_live".localizedString) { watch(notice.item) }
                                .buttonStyle(.borderedProminent)
                        }
                        Button("playback_dismiss_up_next".localizedString) { monitor.dismiss() }
                    }.buttonStyle(.bordered)
                }
            }
            .padding(16)
            .background(.black.opacity(0.85), in: .rect(cornerRadius: 12))
            .foregroundStyle(.white)
        }
    }

    private func status(_ state: LiveUpNextNotice.State) -> String {
        switch state {
        case .starting(let seconds):
            let time = Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
            return String(format: "playback_coverage_starts_in".localizedString, time)
        case .waiting:
            return "playback_coverage_waiting".localizedString
        case .live:
            return "playback_coverage_live_now".localizedString
        }
    }
}

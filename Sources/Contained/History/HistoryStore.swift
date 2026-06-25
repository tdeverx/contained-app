import Foundation
import SwiftData
import ContainedCore

/// Owns the SwiftData stack for the persistent history (events + metric samples) and writes to it.
/// Retention-bounded so the database can't grow without limit. The `container` is exposed so the
/// SwiftUI views can read it via `@Query`.
@MainActor
final class HistoryStore {
    let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    /// Keep this many days of history; pruned on launch and periodically. Driven by the user
    /// setting (`SettingsStore.historyRetentionDays`), synced by `AppModel`.
    var retentionDays = 7
    private var lastMetricSample: Date?
    /// Minimum spacing between persisted metric samples, so a 2s poll doesn't flood the DB
    /// (60s → ~10k rows per container over the 7-day window).
    private let metricInterval: TimeInterval = 60

    init() {
        let schema = Schema([EventRecord.self, MetricSample.self, Template.self])
        do {
            container = try ModelContainer(for: schema)
        } catch {
            // Fall back to an in-memory store so the app still runs if the on-disk store can't open.
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: config)
        }
        pruneOld()
    }

    // MARK: Writes

    func record(_ kind: EventKind, containerID: String? = nil, message: String, at date: Date = Date()) {
        context.insert(EventRecord(timestamp: date, containerID: containerID, kind: kind, message: message))
        try? context.save()
    }

    /// Persist a metric sample for each running container, throttled to `metricInterval`.
    func recordMetrics(_ deltas: [String: StatsDelta], at date: Date = Date()) {
        if let last = lastMetricSample, date.timeIntervalSince(last) < metricInterval { return }
        lastMetricSample = date
        for (id, d) in deltas {
            context.insert(MetricSample(timestamp: date, containerID: id,
                                        cpuFraction: d.cpuCoreFraction, memoryBytes: Double(d.memoryUsageBytes),
                                        netRxBytesPerSec: d.netRxBytesPerSec, netTxBytesPerSec: d.netTxBytesPerSec,
                                        diskReadBytesPerSec: d.blockReadBytesPerSec, diskWriteBytesPerSec: d.blockWriteBytesPerSec))
        }
        try? context.save()
    }

    // MARK: Retention

    func pruneOld(now: Date = Date()) {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: now) else { return }
        try? context.delete(model: MetricSample.self, where: #Predicate { $0.timestamp < cutoff })
        try? context.delete(model: EventRecord.self, where: #Predicate { $0.timestamp < cutoff })
        try? context.save()
    }

    /// Wipe all recorded metrics and events (Templates are preserved). Used by the "Clear history"
    /// action in Settings.
    func clearAll() {
        try? context.delete(model: MetricSample.self)
        try? context.delete(model: EventRecord.self)
        try? context.save()
    }
}

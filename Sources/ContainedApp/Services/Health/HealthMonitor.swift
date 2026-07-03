import SwiftUI
import ContainedCore

/// Local store of per-container healthchecks (keyed by scoped container id), persisted in the app database.
@MainActor
@Observable
final class HealthCheckStore {
    private var checks: [String: Core.Container.HealthCheck]
    private let database: AppDatabase

    init(database: AppDatabase = AppDatabase()) {
        self.database = database
        checks = Dictionary(uniqueKeysWithValues: database.fetch(HealthCheckRecord.self).compactMap { record in
            do {
                return (record.containerScopedID,
                        try JSONDecoder().decode(Core.Container.HealthCheck.self, from: record.valueData))
            } catch {
                fatalError("Unable to decode health check for \(record.containerScopedID): \(error)")
            }
        })
    }

    func check(for id: String) -> Core.Container.HealthCheck? { checks[id] }

    func setCheck(_ check: Core.Container.HealthCheck, for id: String) {
        if check.command.isEmpty { checks[id] = nil } else { checks[id] = check }
        persist()
    }

    func clear(id: String) {
        checks[id] = nil
        persist()
    }

    func backupSnapshot() -> [String: Core.Container.HealthCheck] { checks }

    func applyBackup(_ snapshot: [String: Core.Container.HealthCheck], replace: Bool) {
        if replace { checks = snapshot }
        else { checks.merge(snapshot) { _, imported in imported } }
        persist()
    }

    func purgeOrphans(liveContainerIDs: Set<String>) -> Int {
        let before = checks.count
        checks = checks.filter { liveContainerIDs.contains($0.key) }
        persist()
        return before - checks.count
    }

    private func persist() {
        let wanted = Set(checks.keys)
        for record in database.fetch(HealthCheckRecord.self) where !wanted.contains(record.containerScopedID) {
            database.context.delete(record)
        }
        for (id, check) in checks {
            let data: Data
            do {
                data = try JSONEncoder().encode(check)
            } catch {
                fatalError("Unable to encode health check for \(id): \(error)")
            }
            if let record = database.fetch(HealthCheckRecord.self).first(where: { $0.containerScopedID == id }) {
                record.valueData = data
                record.updatedAt = Date()
            } else {
                database.context.insert(HealthCheckRecord(containerScopedID: id, valueData: data))
            }
        }
        database.save()
    }
}

/// App-managed healthcheck runner. On each poll tick it probes running containers whose check is due
/// (`exec` the probe; zero exit = pass), tracks consecutive failures, and flips status to unhealthy
/// once the retry budget is reached — surfacing a badge + a one-time callback. Runs only while the
/// app is open; it is not a daemon.
@MainActor
@Observable
final class HealthMonitor {
    private(set) var statusByID: [String: Core.Container.HealthStatus] = [:]
    private var consecutiveFailures: [String: Int] = [:]
    private var lastProbe: [String: Date] = [:]

    /// Fired once when a container transitions into the unhealthy state.
    var onUnhealthy: ((Core.Container.Snapshot) -> Void)?

    func evaluate(snapshots: [Core.Container.Snapshot],
                  store: HealthCheckStore,
                  client: Core.Orchestrator,
                  now: Date = Date()) async {
        let running = Dictionary(snapshots.filter { $0.state == .running }.map { ($0.scopedID, $0) },
                                 uniquingKeysWith: { a, _ in a })

        // Drop tracking for containers that stopped or whose check was removed/disabled.
        for id in Array(statusByID.keys) where running[id] == nil || store.check(for: id)?.isActive != true {
            statusByID[id] = nil; consecutiveFailures[id] = nil; lastProbe[id] = nil
        }

        for (id, snapshot) in running {
            guard let check = store.check(for: id), check.isActive else { continue }
            if let last = lastProbe[id], now.timeIntervalSince(last) < Double(check.intervalSeconds) { continue }
            lastProbe[id] = now

            let passed: Bool
            do { _ = try await client.execCapture(snapshot.id, check.command, runtimeKind: snapshot.runtimeKind); passed = true }
            catch { passed = false }

            let failures = passed ? 0 : (consecutiveFailures[id] ?? 0) + 1
            consecutiveFailures[id] = failures
            let newStatus = passed ? Core.Container.HealthStatus.healthy
                                   : Core.Container.HealthDecision.status(consecutiveFailures: failures, retries: check.retries)
            let previous = statusByID[id]
            statusByID[id] = newStatus
            if newStatus == .unhealthy && previous != .unhealthy { onUnhealthy?(snapshot) }
        }
    }

    func status(for id: String) -> Core.Container.HealthStatus { statusByID[id] ?? .unknown }

    func reset() { statusByID.removeAll(); consecutiveFailures.removeAll(); lastProbe.removeAll() }
}

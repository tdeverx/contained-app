import SwiftUI
import ContainedCore
import ContainedRuntime

/// Local store of per-container healthchecks (keyed by container id), persisted to UserDefaults.
/// Migrated to SwiftData in WS7, alongside personalization.
@MainActor
@Observable
final class HealthCheckStore {
    private var checks: [String: HealthCheck]
    private let defaults: UserDefaults
    private let key = "healthChecks"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: HealthCheck].self, from: data) {
            checks = decoded
        } else {
            checks = [:]
        }
    }

    func check(for id: String) -> HealthCheck? { checks[id] }

    func setCheck(_ check: HealthCheck, for id: String) {
        if check.command.isEmpty { checks[id] = nil } else { checks[id] = check }
        persist()
    }

    func clear(id: String) {
        checks[id] = nil
        persist()
    }

    func backupSnapshot() -> [String: HealthCheck] { checks }

    func applyBackup(_ snapshot: [String: HealthCheck], replace: Bool) {
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
        if let data = try? JSONEncoder().encode(checks) { defaults.set(data, forKey: key) }
    }
}

/// App-managed healthcheck runner. On each poll tick it probes running containers whose check is due
/// (`exec` the probe; zero exit = pass), tracks consecutive failures, and flips status to unhealthy
/// once the retry budget is reached — surfacing a badge + a one-time callback. Runs only while the
/// app is open; it is not a daemon.
@MainActor
@Observable
final class HealthMonitor {
    private(set) var statusByID: [String: HealthStatus] = [:]
    private var consecutiveFailures: [String: Int] = [:]
    private var lastProbe: [String: Date] = [:]

    /// Fired once when a container transitions into the unhealthy state.
    var onUnhealthy: ((ContainerSnapshot) -> Void)?

    func evaluate(snapshots: [ContainerSnapshot],
                  store: HealthCheckStore,
                  client: any ContainerRuntimeClient,
                  now: Date = Date()) async {
        let running = Dictionary(snapshots.filter { $0.state == .running }.map { ($0.id, $0) },
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
            do { _ = try await client.execCapture(id, check.command); passed = true }
            catch { passed = false }

            let failures = passed ? 0 : (consecutiveFailures[id] ?? 0) + 1
            consecutiveFailures[id] = failures
            let newStatus = passed ? HealthStatus.healthy
                                   : HealthDecision.status(consecutiveFailures: failures, retries: check.retries)
            let previous = statusByID[id]
            statusByID[id] = newStatus
            if newStatus == .unhealthy && previous != .unhealthy { onUnhealthy?(snapshot) }
        }
    }

    func status(for id: String) -> HealthStatus { statusByID[id] ?? .unknown }

    func reset() { statusByID.removeAll(); consecutiveFailures.removeAll(); lastProbe.removeAll() }
}

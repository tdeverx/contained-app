import SwiftUI
import ContainedDesignSystem
import OSLog
import ContainedCore

/// Owns the container list and derived live stats. Lifecycle actions run through the client and
/// trigger a refresh. Stats are sampled per refresh and converted into deltas for cards, expanded
/// panels, history, and restart/health context.
@MainActor
@Observable
final class ContainersStore {
    enum StatsRefreshDemand: Int, Comparable {
        case background
        case visible
        case force

        static func < (lhs: StatsRefreshDemand, rhs: StatsRefreshDemand) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var label: String {
            switch self {
            case .background: "background"
            case .visible: "visible"
            case .force: "force"
            }
        }
    }

    var snapshots: [ContainerSnapshot] = []
    var statsByID: [String: StatsDelta] = [:]
    /// Per-container, per-metric sparkline history.
    var historyByID: [String: [GraphMetric: SampleBuffer]] = [:]
    private(set) var statsRevision = 0
    var errorMessage: String?
    var busyIDs: Set<String> = []
    @ObservationIgnored var logger: AppLogger?
    @ObservationIgnored var now: () -> Date = Date.init

    var client: ContainerClient?

    private static let visibleStatsInterval: TimeInterval = 10
    private static let backgroundStatsInterval: TimeInterval = 30

    private var lastRawStats: [String: ContainerStats] = [:]
    private var lastStatsDate: Date?
    /// IDs the user (not a crash) just stopped/removed, so the RestartWatchdog won't fight them.
    private var intentionalStops: Set<String> = []

    /// The currently-running refresh, if any. Refresh requests are coalesced so a burst of user
    /// actions plus the polling loop only keeps one trailing pass alive instead of stacking a queue
    /// of redundant `list` + `stats` runs when a container is busy starting up.
    private var refreshTask: Task<Void, Never>?
    private var refreshRequested = false
    private var pendingStatsDemand: StatsRefreshDemand = .background
    private let diagnosticLogger = Logger(subsystem: "app.contained.Contained", category: "diagnostic")

    var running: [ContainerSnapshot] { snapshots.filter { $0.state == .running } }

    /// True (consuming the flag) if the given container's last stop was user-initiated.
    func consumeIntentionalStop(_ id: String) -> Bool {
        intentionalStops.remove(id) != nil
    }

    /// Re-list containers and opportunistically resample stats. Serialized: if a refresh is already
    /// running, this one is coalesced into the trailing pass once the current one finishes (never
    /// concurrently), and the caller awaits that combined pass.
    func refresh(statsDemand: StatsRefreshDemand = .background) async {
        refreshRequested = true
        pendingStatsDemand = max(pendingStatsDemand, statsDemand)
        if refreshTask != nil {
            logger?.record("Refresh already in flight; coalescing another pass",
                           category: .system,
                           severity: .debug)
            diagnosticLogger.debug("Refresh already in flight; coalescing another pass")
        }
        await refreshTaskOrStart().value
    }

    private func refreshTaskOrStart() -> Task<Void, Never> {
        if let refreshTask { return refreshTask }
        let task = Task { @MainActor [weak self] in
            _ = await self?.drainRefreshRequests()
        }
        refreshTask = task
        return task
    }

    private func drainRefreshRequests() async {
        let started = Date()
        var passes = 0
        repeat {
            passes += 1
            let statsDemand = pendingStatsDemand
            pendingStatsDemand = .background
            refreshRequested = false
            await performRefresh(statsDemand: statsDemand)
        } while refreshRequested
        refreshTask = nil
        let elapsed = Date().timeIntervalSince(started)
        if elapsed >= 0.75 || passes > 1 {
            let suffix = passes == 1 ? "" : "es"
            logger?.record("Refresh finished in \(elapsed.formatted(.number.precision(.fractionLength(2))))s across \(passes) pass\(passes == 1 ? "" : "es")",
                           category: .system,
                           severity: elapsed >= 1.5 ? .warning : .info)
            diagnosticLogger.log(level: elapsed >= 1.5 ? .default : .info,
                                 "Refresh finished in \(elapsed.formatted(.number.precision(.fractionLength(2))), privacy: .public)s across \(passes, privacy: .public) pass\(suffix, privacy: .public)")
        }
    }

    private func performRefresh(statsDemand: StatsRefreshDemand) async {
        guard let client else { return }
        do {
            let listed = try await client.listContainers(all: true)
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            // Only publish when the list actually changed: reassigning an identical array would
            // needlessly invalidate the whole grid (and every card's sparkline) on each idle tick.
            if listed != snapshots { snapshots = listed }
            // Drop intentional-stop flags for containers that no longer exist, so the set can't grow
            // unbounded as containers are recreated/removed over a long session.
            intentionalStops.formIntersection(Set(snapshots.map(\.id)))
            errorMessage = nil
            await refreshStats(statsDemand)
        } catch let error as CommandError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshStats(_ demand: StatsRefreshDemand) async {
        guard let client else { return }
        let runningIDs = running.map(\.id)
        let runningSet = Set(runningIDs)
        let prunedStats = statsByID.filter { runningSet.contains($0.key) }
        if prunedStats.count != statsByID.count { statsByID = prunedStats }
        lastRawStats = lastRawStats.filter { runningSet.contains($0.key) }
        guard !runningIDs.isEmpty else {
            if !historyByID.isEmpty { historyByID.removeAll() }
            lastStatsDate = nil
            return
        }
        let now = now()
        guard shouldSampleStats(demand, now: now) else { return }
        let started = Date()
        do {
            let samples = try await client.stats(ids: runningIDs)
            let interval = lastStatsDate.map { now.timeIntervalSince($0) } ?? 1
            var nextStats = statsByID
            var nextHistory = historyByID
            var producedDelta = false
            for sample in samples {
                if let previous = lastRawStats[sample.id] {
                    let delta = StatsDelta.between(previous: previous, current: sample, interval: interval)
                    nextStats[sample.id] = delta
                    var metrics = nextHistory[sample.id] ?? [:]
                    for metric in GraphMetric.allCases {
                        var buffer = metrics[metric] ?? SampleBuffer()
                        buffer.append(metric.value(from: delta))
                        metrics[metric] = buffer
                    }
                    nextHistory[sample.id] = metrics
                    producedDelta = true
                }
                lastRawStats[sample.id] = sample
            }
            if nextStats != statsByID { statsByID = nextStats }
            if nextHistory != historyByID { historyByID = nextHistory }
            lastStatsDate = now
            if producedDelta { statsRevision &+= 1 }
            let elapsed = Date().timeIntervalSince(started)
            if elapsed >= 0.75 || demand == .force {
                diagnosticLogger.log(level: elapsed >= 1.5 ? .default : .info,
                                     "Stats sample \(demand.label, privacy: .public) finished in \(elapsed.formatted(.number.precision(.fractionLength(2))), privacy: .public)s for \(runningIDs.count, privacy: .public) container(s)")
            }
        } catch {
            // Stats are best-effort; a failure here shouldn't blank the list.
        }
    }

    private func shouldSampleStats(_ demand: StatsRefreshDemand, now: Date) -> Bool {
        guard demand != .force else { return true }
        guard let lastStatsDate else { return true }
        let interval = switch demand {
        case .background: Self.backgroundStatsInterval
        case .visible: Self.visibleStatsInterval
        case .force: TimeInterval.zero
        }
        return now.timeIntervalSince(lastStatsDate) >= interval
    }

    // MARK: Lifecycle

    func start(_ id: String) async { await act(id, verb: "Start") { try await $0.start([id]) } }
    func stop(_ id: String) async {
        intentionalStops.insert(id)
        await act(id, verb: "Stop") { try await $0.stop([id]) }
    }
    func restart(_ id: String) async {
        await act(id, verb: "Restart") { _ = try await $0.stop([id]); _ = try await $0.start([id]) }
    }
    func remove(_ id: String, force: Bool) async {
        intentionalStops.insert(id)
        await act(id, verb: "Remove") { try await $0.deleteContainers([id], force: force) }
    }

    /// Create + run a container from the Create/Edit form. Returns the new container's id on success
    /// (the user-set name, or the id `container run` prints for a generated name), or nil on failure.
    /// The id lets the caller attach local personalization to exactly this container.
    @discardableResult
    func run(_ spec: RunSpec) async -> String? {
        guard let client else { return nil }
        let started = Date()
        logger?.record("Running container from creation flow",
                       category: .lifecycle,
                       severity: .info)
        diagnosticLogger.notice("Run started from creation flow")
        do {
            let output = try await client.runner.run(spec.arguments())
            performHaptic()
            await refresh(statsDemand: .force)
            let elapsed = Date().timeIntervalSince(started)
            logger?.record("Run finished in \(elapsed.formatted(.number.precision(.fractionLength(2))))s",
                           category: .lifecycle,
                           severity: elapsed >= 1.5 ? .warning : .info)
            diagnosticLogger.log(level: elapsed >= 1.5 ? .default : .info,
                                 "Run finished in \(elapsed.formatted(.number.precision(.fractionLength(2))), privacy: .public)s")
            if !spec.name.isEmpty { return spec.name }
            let printed = String(decoding: output, as: UTF8.self)
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .last(where: { !$0.isEmpty })
            return printed
        } catch let error as CommandError {
            errorMessage = error.userMessage
            let elapsed = Date().timeIntervalSince(started)
            logger?.record("Run failed after \(elapsed.formatted(.number.precision(.fractionLength(2))))s: \(error.userMessage)",
                           category: .lifecycle,
                           severity: .warning)
            diagnosticLogger.error("Run failed after \(elapsed.formatted(.number.precision(.fractionLength(2))))s: \(error.userMessage, privacy: .public)")
            return nil
        } catch {
            errorMessage = error.localizedDescription
            let elapsed = Date().timeIntervalSince(started)
            logger?.record("Run failed after \(elapsed.formatted(.number.precision(.fractionLength(2))))s: \(error.localizedDescription)",
                           category: .lifecycle,
                           severity: .warning)
            diagnosticLogger.error("Run failed after \(elapsed.formatted(.number.precision(.fractionLength(2))))s: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Recreate macro: tear down `originalID` and run `spec` in its place (container config is
    /// immutable, so "editing" means delete + re-run). Returns true on success. On failure the old
    /// container is already gone — the error is surfaced for the caller to show.
    @discardableResult
    func recreate(originalID: String, spec: RunSpec) async -> Bool {
        guard let client else { return false }
        busyIDs.insert(originalID)
        intentionalStops.insert(originalID)   // don't let the watchdog fight the teardown
        defer { busyIDs.remove(originalID) }
        let started = Date()
        logger?.record("Recreating \(originalID)", category: .lifecycle, containerID: originalID)
        diagnosticLogger.notice("Recreate started for \(originalID, privacy: .public)")
        do {
            _ = try? await client.stop([originalID])          // best-effort; may already be stopped
            _ = try await client.deleteContainers([originalID], force: true)
            _ = try await client.runner.run(spec.arguments())
            performHaptic()
            await refresh(statsDemand: .force)
            let elapsed = Date().timeIntervalSince(started)
            logger?.record("Recreated \(originalID) in \(elapsed.formatted(.number.precision(.fractionLength(2))))s",
                           category: .lifecycle,
                           severity: elapsed >= 1.5 ? .warning : .info,
                           containerID: originalID)
            diagnosticLogger.log(level: elapsed >= 1.5 ? .default : .info,
                                 "Recreated \(originalID, privacy: .public) in \(elapsed.formatted(.number.precision(.fractionLength(2))), privacy: .public)s")
            return true
        } catch let error as CommandError {
            errorMessage = error.userMessage
            let elapsed = Date().timeIntervalSince(started)
            logger?.record("Recreate failed after \(elapsed.formatted(.number.precision(.fractionLength(2))))s: \(error.userMessage)",
                           category: .lifecycle,
                           severity: .warning,
                           containerID: originalID)
            diagnosticLogger.error("Recreate failed after \(elapsed.formatted(.number.precision(.fractionLength(2))))s: \(error.userMessage, privacy: .public)")
            await refresh(statsDemand: .force)
            return false
        } catch {
            errorMessage = error.localizedDescription
            let elapsed = Date().timeIntervalSince(started)
            logger?.record("Recreate failed after \(elapsed.formatted(.number.precision(.fractionLength(2))))s: \(error.localizedDescription)",
                           category: .lifecycle,
                           severity: .warning,
                           containerID: originalID)
            diagnosticLogger.error("Recreate failed after \(elapsed.formatted(.number.precision(.fractionLength(2))))s: \(error.localizedDescription, privacy: .public)")
            await refresh(statsDemand: .force)
            return false
        }
    }

    private func act(_ id: String, verb: String, _ body: @escaping (ContainerClient) async throws -> Void) async {
        guard let client else { return }
        busyIDs.insert(id)
        defer { busyIDs.remove(id) }
        let started = Date()
        logger?.record("\(verb) \(id)", category: .lifecycle, containerID: id)
        diagnosticLogger.notice("\(verb) started for \(id, privacy: .public)")
        do {
            try await body(client)
            performHaptic()
            await refresh(statsDemand: .force)
            let elapsed = Date().timeIntervalSince(started)
            logger?.record("\(verb) finished in \(elapsed.formatted(.number.precision(.fractionLength(2))))s",
                           category: .lifecycle,
                           severity: elapsed >= 1.5 ? .warning : .info,
                           containerID: id)
            diagnosticLogger.log(level: elapsed >= 1.5 ? .default : .info,
                                 "\(verb) finished for \(id, privacy: .public) in \(elapsed.formatted(.number.precision(.fractionLength(2))), privacy: .public)s")
        } catch let error as CommandError {
            errorMessage = error.userMessage
            let elapsed = Date().timeIntervalSince(started)
            logger?.record("\(verb) failed after \(elapsed.formatted(.number.precision(.fractionLength(2))))s: \(error.userMessage)",
                           category: .lifecycle,
                           severity: .warning,
                           containerID: id)
            diagnosticLogger.error("\(verb) failed for \(id, privacy: .public) after \(elapsed.formatted(.number.precision(.fractionLength(2))))s: \(error.userMessage, privacy: .public)")
        } catch {
            errorMessage = error.localizedDescription
            let elapsed = Date().timeIntervalSince(started)
            logger?.record("\(verb) failed after \(elapsed.formatted(.number.precision(.fractionLength(2))))s: \(error.localizedDescription)",
                           category: .lifecycle,
                           severity: .warning,
                           containerID: id)
            diagnosticLogger.error("\(verb) failed for \(id, privacy: .public) after \(elapsed.formatted(.number.precision(.fractionLength(2))))s: \(error.localizedDescription, privacy: .public)")
        }
    }
}

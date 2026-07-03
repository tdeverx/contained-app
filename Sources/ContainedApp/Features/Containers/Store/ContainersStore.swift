import SwiftUI
import ContainedUI
import OSLog
import ContainedCore

/// Owns the container list and derived live stats. Lifecycle actions run through the Core orchestrator and
/// trigger a refresh. Stats arrive from the app-wide runtime stream and are converted into deltas
/// for cards, expanded panels, history, and restart/health context.
@MainActor
@Observable
final class ContainerMetricsState {
    let id: String
    var stats: Core.Metrics.StatsDelta?
    var historyByMetric: [Core.Metrics.GraphMetric: UI.Chart.SampleBuffer]
    private(set) var revision = 0

    init(id: String, stats: Core.Metrics.StatsDelta? = nil, historyByMetric: [Core.Metrics.GraphMetric: UI.Chart.SampleBuffer] = [:]) {
        self.id = id
        self.stats = stats
        self.historyByMetric = historyByMetric
    }

    func values(for metric: Core.Metrics.GraphMetric) -> [Double] {
        historyByMetric[metric]?.values ?? []
    }

    func update(stats: Core.Metrics.StatsDelta?, historyByMetric: [Core.Metrics.GraphMetric: UI.Chart.SampleBuffer]) {
        var changed = false
        if self.stats != stats {
            self.stats = stats
            changed = true
        }
        if self.historyByMetric != historyByMetric {
            self.historyByMetric = historyByMetric
            changed = true
        }
        if changed { revision &+= 1 }
    }
}

@MainActor
@Observable
final class ContainersStore {
    private static let minimumStreamedStatsInterval: TimeInterval = 1

    var snapshots: [Core.Container.Snapshot] = []
    @ObservationIgnored
    var statsByID: [String: Core.Metrics.StatsDelta] = [:]
    /// Per-container, per-metric sparkline history.
    @ObservationIgnored
    var historyByID: [String: [Core.Metrics.GraphMetric: UI.Chart.SampleBuffer]] = [:]
    @ObservationIgnored
    private(set) var statsRevision = 0
    var errorMessage: String?
    var busyIDs: Set<String> = []
    @ObservationIgnored var logger: AppLogger?
    @ObservationIgnored var now: () -> Date = Date.init
    @ObservationIgnored private var metricsStates: [String: ContainerMetricsState] = [:]
    @ObservationIgnored private var statsNormalizationContext: Core.Metrics.NormalizationContext = .containerSpecific

    var client: Core.Orchestrator?

    private var lastStreamedStats: [String: Core.Metrics.RuntimeStatsSnapshot] = [:]
    private var lastStreamedStatsDate: Date?
    /// IDs the user (not a crash) just stopped/removed, so the RestartWatchdog won't fight them.
    private var intentionalStops: Set<String> = []

    /// The currently-running refresh, if any. Refresh requests are coalesced so a burst of user
    /// actions plus the polling loop only keeps one trailing pass alive instead of stacking a queue
    /// of redundant `list` runs when a container is busy starting up.
    private var refreshTask: Task<Void, Never>?
    private var refreshRequested = false
    private let diagnosticLogger = Logger(subsystem: "app.contained.Contained", category: "diagnostic")

    var running: [Core.Container.Snapshot] { snapshots.filter { $0.state == .running } }

    func metricsState(for id: String) -> ContainerMetricsState {
        if let state = metricsStates[id] { return state }
        let state = ContainerMetricsState(id: id,
                                          stats: statsByID[id],
                                          historyByMetric: historyByID[id] ?? [:])
        metricsStates[id] = state
        return state
    }

    func configureStatsNormalization(_ context: Core.Metrics.NormalizationContext) {
        guard statsNormalizationContext != context else { return }
        statsNormalizationContext = context
        rebuildDisplayHistories()
    }

    /// True (consuming the flag) if the given container's last stop was user-initiated.
    func consumeIntentionalStop(_ id: String) -> Bool {
        intentionalStops.remove(id) != nil
    }

    /// Re-list containers and opportunistically resample stats. Serialized: if a refresh is already
    /// running, this one is coalesced into the trailing pass once the current one finishes (never
    /// concurrently), and the caller awaits that combined pass.
    func refresh() async {
        refreshRequested = true
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
            refreshRequested = false
            await performRefresh()
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

    private func performRefresh() async {
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
            pruneStatsForCurrentRunningSet()
        } catch let error as Core.Command.Error {
            errorMessage = error.appDisplayMessage
        } catch {
            errorMessage = error.appDisplayMessage
        }
    }

    private func pruneStatsForCurrentRunningSet() {
        let currentSet = Set(snapshots.map(\.id))
        let runningSet = Set(running.map(\.id))
        let prunedStats = statsByID.filter { runningSet.contains($0.key) }
        if prunedStats.count != statsByID.count { statsByID = prunedStats }
        let prunedHistory = historyByID.filter { runningSet.contains($0.key) }
        if prunedHistory.count != historyByID.count { historyByID = prunedHistory }
        lastStreamedStats = lastStreamedStats.filter { runningSet.contains($0.key) }
        for (id, state) in metricsStates {
            if runningSet.contains(id) {
                state.update(stats: statsByID[id], historyByMetric: historyByID[id] ?? [:])
            } else {
                state.update(stats: nil, historyByMetric: [:])
            }
        }
        metricsStates = metricsStates.filter { currentSet.contains($0.key) }
        guard !runningSet.isEmpty else {
            if !historyByID.isEmpty { historyByID.removeAll() }
            lastStreamedStatsDate = nil
            return
        }
    }

    func applyStreamedStats(_ samples: [Core.Metrics.RuntimeStatsSnapshot], observedAt: Date? = nil) {
        let runningSet = Set(running.map(\.id))
        let samples = samples.filter { runningSet.contains($0.id) }
        guard !samples.isEmpty else { return }

        let observedAt = observedAt ?? now()
        let rawInterval = lastStreamedStatsDate.map { observedAt.timeIntervalSince($0) }
        let interval = max(rawInterval ?? Self.minimumStreamedStatsInterval, Self.minimumStreamedStatsInterval)
        let snapshotsByID = Dictionary(snapshots.map { ($0.id, $0) }, uniquingKeysWith: { current, _ in current })
        var nextStats = statsByID
        var nextHistory = historyByID
        for sample in samples {
            let delta = Core.Metrics.StatsDelta.from(snapshot: sample,
                                        previous: lastStreamedStats[sample.id],
                                        interval: interval)
            record(delta, snapshot: snapshotsByID[sample.id], stats: &nextStats, history: &nextHistory)
            metricsStates[sample.id]?.update(stats: delta, historyByMetric: nextHistory[sample.id] ?? [:])
            lastStreamedStats[sample.id] = sample
        }

        if nextStats != statsByID { statsByID = nextStats }
        if nextHistory != historyByID { historyByID = nextHistory }
        lastStreamedStatsDate = observedAt
        statsRevision &+= 1
    }

    private func record(_ delta: Core.Metrics.StatsDelta,
                        snapshot: Core.Container.Snapshot?,
                        stats: inout [String: Core.Metrics.StatsDelta],
                        history: inout [String: [Core.Metrics.GraphMetric: UI.Chart.SampleBuffer]]) {
        stats[delta.id] = delta
        var metrics = history[delta.id] ?? [:]
        for metric in Core.Metrics.GraphMetric.allCases {
            var buffer = metrics[metric] ?? UI.Chart.SampleBuffer()
            buffer.append(metric.value(from: delta, snapshot: snapshot, normalization: statsNormalizationContext))
            metrics[metric] = buffer
        }
        history[delta.id] = metrics
    }

    private func rebuildDisplayHistories() {
        let snapshotsByID = Dictionary(snapshots.map { ($0.id, $0) }, uniquingKeysWith: { current, _ in current })
        let runningSet = Set(running.map(\.id))
        var rebuilt: [String: [Core.Metrics.GraphMetric: UI.Chart.SampleBuffer]] = [:]
        for (id, delta) in statsByID where runningSet.contains(id) {
            var metrics: [Core.Metrics.GraphMetric: UI.Chart.SampleBuffer] = [:]
            for metric in Core.Metrics.GraphMetric.allCases {
                var buffer = UI.Chart.SampleBuffer()
                buffer.append(metric.value(from: delta,
                                           snapshot: snapshotsByID[id],
                                           normalization: statsNormalizationContext))
                metrics[metric] = buffer
            }
            rebuilt[id] = metrics
        }
        historyByID = rebuilt
        for (id, state) in metricsStates {
            if runningSet.contains(id) {
                state.update(stats: statsByID[id], historyByMetric: rebuilt[id] ?? [:])
            } else {
                state.update(stats: nil, historyByMetric: [:])
            }
        }
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
    func run(_ spec: ContainerFormState) async -> String? {
        guard let client else { return nil }
        let started = Date()
        logger?.record("Running container from creation flow",
                       category: .lifecycle,
                       severity: .info)
        diagnosticLogger.notice("Run started from creation flow")
        do {
            let result = try await client.createContainer(spec.document)
            performHaptic()
            await refresh()
            let elapsed = Date().timeIntervalSince(started)
            logger?.record("Run finished in \(elapsed.formatted(.number.precision(.fractionLength(2))))s",
                           category: .lifecycle,
                           severity: elapsed >= 1.5 ? .warning : .info)
            diagnosticLogger.log(level: elapsed >= 1.5 ? .default : .info,
                                 "Run finished in \(elapsed.formatted(.number.precision(.fractionLength(2))), privacy: .public)s")
            return result.id
        } catch {
            errorMessage = error.appDisplayMessage
            let elapsed = Date().timeIntervalSince(started)
            logger?.recordFailure("Run failed after \(elapsed.formatted(.number.precision(.fractionLength(2))))s",
                                  error: error,
                                  category: .lifecycle,
                                  severity: .warning)
            diagnosticLogger.error("Run failed after \(elapsed.formatted(.number.precision(.fractionLength(2))))s: \(error.appDisplayMessage, privacy: .public)")
            return nil
        }
    }

    /// Recreate macro: tear down `originalID` and run `spec` in its place. Container config is
    /// immutable, so edits become a replacement run. Errors are surfaced for the caller to show.
    @discardableResult
    func recreate(originalID: String, spec: ContainerFormState) async -> Bool {
        guard let client else { return false }
        busyIDs.insert(originalID)
        intentionalStops.insert(originalID)   // don't let the watchdog fight the teardown
        defer { busyIDs.remove(originalID) }
        let started = Date()
        logger?.record("Recreating \(originalID)", category: .lifecycle, containerID: originalID)
        diagnosticLogger.notice("Recreate started for \(originalID, privacy: .public)")
        do {
            _ = try await client.recreateContainer(originalID: originalID, document: spec.document)
            performHaptic()
            await refresh()
            let elapsed = Date().timeIntervalSince(started)
            logger?.record("Recreated \(originalID) in \(elapsed.formatted(.number.precision(.fractionLength(2))))s",
                           category: .lifecycle,
                           severity: elapsed >= 1.5 ? .warning : .info,
                           containerID: originalID)
            diagnosticLogger.log(level: elapsed >= 1.5 ? .default : .info,
                                 "Recreated \(originalID, privacy: .public) in \(elapsed.formatted(.number.precision(.fractionLength(2))), privacy: .public)s")
            return true
        } catch {
            errorMessage = error.appDisplayMessage
            let elapsed = Date().timeIntervalSince(started)
            logger?.recordFailure("Recreate failed after \(elapsed.formatted(.number.precision(.fractionLength(2))))s",
                                  error: error,
                                  category: .lifecycle,
                                  severity: .warning,
                                  containerID: originalID)
            diagnosticLogger.error("Recreate failed after \(elapsed.formatted(.number.precision(.fractionLength(2))))s: \(error.appDisplayMessage, privacy: .public)")
            await refresh()
            return false
        }
    }

    private func act(_ id: String,
                     verb: String,
                     _ body: @escaping (Core.Orchestrator) async throws -> Void) async {
        guard let client else { return }
        busyIDs.insert(id)
        defer { busyIDs.remove(id) }
        let started = Date()
        logger?.record("\(verb) \(id)", category: .lifecycle, containerID: id)
        diagnosticLogger.notice("\(verb) started for \(id, privacy: .public)")
        do {
            try await body(client)
            performHaptic()
            await refresh()
            let elapsed = Date().timeIntervalSince(started)
            logger?.record("\(verb) finished in \(elapsed.formatted(.number.precision(.fractionLength(2))))s",
                           category: .lifecycle,
                           severity: elapsed >= 1.5 ? .warning : .info,
                           containerID: id)
            diagnosticLogger.log(level: elapsed >= 1.5 ? .default : .info,
                                 "\(verb) finished for \(id, privacy: .public) in \(elapsed.formatted(.number.precision(.fractionLength(2))), privacy: .public)s")
        } catch {
            errorMessage = error.appDisplayMessage
            let elapsed = Date().timeIntervalSince(started)
            logger?.recordFailure("\(verb) failed after \(elapsed.formatted(.number.precision(.fractionLength(2))))s",
                                  error: error,
                                  category: .lifecycle,
                                  severity: .warning,
                                  containerID: id)
            diagnosticLogger.error("\(verb) failed for \(id, privacy: .public) after \(elapsed.formatted(.number.precision(.fractionLength(2))))s: \(error.appDisplayMessage, privacy: .public)")
        }
    }
}

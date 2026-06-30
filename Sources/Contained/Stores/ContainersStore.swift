import SwiftUI
import ContainedCore

/// Owns the container list and derived live stats. Lifecycle actions run through the client and
/// trigger a refresh. (Full streaming + adaptive polling arrives in Phase 4; this does a simple
/// per-refresh stats sample and computes deltas, which is enough to drive the cards now.)
@MainActor
@Observable
final class ContainersStore {
    var snapshots: [ContainerSnapshot] = []
    var statsByID: [String: StatsDelta] = [:]
    /// Per-container, per-metric sparkline history.
    var historyByID: [String: [GraphMetric: SampleBuffer]] = [:]
    var errorMessage: String?
    var busyIDs: Set<String> = []

    var client: ContainerClient?

    private var lastRawStats: [String: ContainerStats] = [:]
    private var lastStatsDate: Date?
    /// IDs the user (not a crash) just stopped/removed, so the RestartWatchdog won't fight them.
    private var intentionalStops: Set<String> = []

    /// The currently-running refresh, if any. Refreshes are serialized through this so a user action
    /// and the background polling tick can't run `list`+`stats` concurrently — overlapping runs used
    /// to decode JSON on the main actor in parallel and stomp the shared stats dictionaries, which is
    /// what made start/stop feel like it hung the UI. Each caller awaits a pass that begins strictly
    /// after every previously-enqueued one, so an action always observes its own post-CLI state.
    private var refreshChain: Task<Void, Never>?

    var running: [ContainerSnapshot] { snapshots.filter { $0.state == .running } }

    /// True (consuming the flag) if the given container's last stop was user-initiated.
    func consumeIntentionalStop(_ id: String) -> Bool {
        intentionalStops.remove(id) != nil
    }

    /// Re-list containers and resample stats. Serialized: if a refresh is already running, this one is
    /// chained to begin once it finishes (never concurrently), and the caller awaits that later pass.
    func refresh() async {
        let previous = refreshChain
        let task = Task { @MainActor [weak self] in
            await previous?.value
            await self?.performRefresh()
        }
        refreshChain = task
        await task.value
        // Clear the chain once the tail pass finishes, so it doesn't pin an ever-growing task list.
        if refreshChain == task { refreshChain = nil }
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
            await refreshStats()
        } catch let error as CommandError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshStats() async {
        guard let client else { return }
        let runningIDs = running.map(\.id)
        guard !runningIDs.isEmpty else {
            statsByID.removeAll(); lastRawStats.removeAll(); return
        }
        do {
            let samples = try await client.stats(ids: runningIDs)
            let now = Date()
            let interval = lastStatsDate.map { now.timeIntervalSince($0) } ?? 1
            for sample in samples {
                if let previous = lastRawStats[sample.id] {
                    let delta = StatsDelta.between(previous: previous, current: sample, interval: interval)
                    statsByID[sample.id] = delta
                    var metrics = historyByID[sample.id] ?? [:]
                    for metric in GraphMetric.allCases {
                        var buffer = metrics[metric] ?? SampleBuffer()
                        buffer.append(metric.value(from: delta))
                        metrics[metric] = buffer
                    }
                    historyByID[sample.id] = metrics
                }
                lastRawStats[sample.id] = sample
            }
            lastStatsDate = now
        } catch {
            // Stats are best-effort; a failure here shouldn't blank the list.
        }
    }

    // MARK: Lifecycle

    func start(_ id: String) async { await act(id) { try await $0.start([id]) } }
    func stop(_ id: String) async {
        intentionalStops.insert(id)
        await act(id) { try await $0.stop([id]) }
    }
    func restart(_ id: String) async {
        await act(id) { _ = try await $0.stop([id]); _ = try await $0.start([id]) }
    }
    func remove(_ id: String, force: Bool) async {
        intentionalStops.insert(id)
        await act(id) { try await $0.deleteContainers([id], force: force) }
    }

    /// Create + run a container from the Create/Edit form. Returns the new container's id on success
    /// (the user-set name, or the id `container run` prints for a generated name), or nil on failure.
    /// The id lets the caller attach local personalization to exactly this container.
    @discardableResult
    func run(_ spec: RunSpec) async -> String? {
        guard let client else { return nil }
        do {
            let output = try await client.runner.run(spec.arguments())
            performHaptic()
            await refresh()
            if !spec.name.isEmpty { return spec.name }
            let printed = String(decoding: output, as: UTF8.self)
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .last(where: { !$0.isEmpty })
            return printed
        } catch let error as CommandError {
            errorMessage = error.userMessage
            return nil
        } catch {
            errorMessage = error.localizedDescription
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
        do {
            _ = try? await client.stop([originalID])          // best-effort; may already be stopped
            _ = try await client.deleteContainers([originalID], force: true)
            _ = try await client.runner.run(spec.arguments())
            performHaptic()
            await refresh()
            return true
        } catch let error as CommandError {
            errorMessage = error.userMessage
            await refresh()
            return false
        } catch {
            errorMessage = error.localizedDescription
            await refresh()
            return false
        }
    }

    private func act(_ id: String, _ body: @escaping (ContainerClient) async throws -> Void) async {
        guard let client else { return }
        busyIDs.insert(id)
        defer { busyIDs.remove(id) }
        do {
            try await body(client)
            performHaptic()
            await refresh()
        } catch let error as CommandError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

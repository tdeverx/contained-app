import SwiftUI
import ContainedCore

/// Root app state: locates the CLI, owns the typed client and the feature stores, and tracks the
/// service/CLI bootstrap status that gates plugin-dependent screens.
@MainActor
@Observable
final class AppModel {
    enum Bootstrap: Equatable {
        case checking
        case cliMissing
        case unsupported(version: String)
        case serviceStopped
        case ready
    }

    let settings: SettingsStore
    let containers = ContainersStore()
    let personalization = PersonalizationStore()
    let coordinator = RefreshCoordinator()
    let watchdog = RestartWatchdog()
    let notifier = Notifier()
    let healthChecks = HealthCheckStore()
    let health = HealthMonitor()
    let historyStore = HistoryStore()
    let updater = UpdaterController()

    private(set) var bootstrap: Bootstrap = .checking
    private(set) var client: ContainerClient?
    /// Resolved path to the `container` binary — needed to spawn the terminal's `exec` process.
    private(set) var cliURL: URL?
    private(set) var systemStatus: SystemStatus?
    private(set) var diskUsage: DiskUsage?
    private(set) var cliVersion: String?

    // Resource caches for the Images/Volumes/Networks pages, refreshed by the coordinator.
    private(set) var images: [ContainedCore.ImageResource] = []
    private(set) var volumes: [VolumeResource] = []
    private(set) var networks: [NetworkResource] = []
    private(set) var registries: [RegistryLogin] = []
    private(set) var properties: SystemProperties?
    private(set) var imagesError: String?
    /// Transient watchdog/crash banner text (auto-cleared).
    var banner: String?
    /// A long-running operation surfaced as a floating progress bar (e.g. pulling an image before a
    /// run). `nil` when idle.
    var activity: ActivityState?

    /// One in-flight operation shown in the bottom progress bar.
    struct ActivityState: Equatable {
        var title: String
        var detail: String = ""
        var fraction: Double? = nil   // nil → indeterminate
    }

    init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        historyStore.retentionDays = settings.historyRetentionDays
        updater.channel = settings.updateChannel
        watchdog.onRestart = { [weak self] snapshot, attempt in
            guard let self else { return }
            let name = self.personalization.resolved(id: snapshot.id, image: snapshot.image)
                .displayName(fallback: snapshot.id)
            self.flash("Restarted \(name) (attempt \(attempt))")
            self.historyStore.record(.watchdog, containerID: snapshot.id, message: "Restarted \(name) (attempt \(attempt))")
            self.notifier.containerRestarted(name: name, attempt: attempt, enabled: settings.notifyOnCrash)
        }
        watchdog.onUnexpectedExit = { [weak self] snapshot in
            guard let self else { return }
            let name = self.personalization.resolved(id: snapshot.id, image: snapshot.image)
                .displayName(fallback: snapshot.id)
            self.historyStore.record(.watchdog, containerID: snapshot.id, message: "\(name) exited unexpectedly")
            self.notifier.containerExited(name: name, enabled: settings.notifyOnCrash)
        }
        health.onUnhealthy = { [weak self] snapshot in
            guard let self else { return }
            let name = self.personalization.resolved(id: snapshot.id, image: snapshot.image)
                .displayName(fallback: snapshot.id)
            self.flash("\(name) is unhealthy")
            self.historyStore.record(.healthcheck, containerID: snapshot.id, message: "\(name) failed its healthcheck")
            self.notifier.containerUnhealthy(name: name, enabled: settings.notifyOnCrash)
            // Hand off to the restart policy (once per unhealthy transition, so it can't spin).
            let policy = RestartPolicy(label: snapshot.configuration.labels["contained.restart"])
            if policy != .no { Task { await self.containers.restart(snapshot.id) } }
        }
    }

    func bootstrapIfNeeded() async {
        guard let url = CLILocator.locate(override: settings.cliPathOverride) else {
            bootstrap = .cliMissing
            return
        }
        let runner = CommandRunner(executableURL: url)
        let client = ContainerClient(runner: runner)
        self.client = client
        self.cliURL = url
        containers.client = client

        // Version check.
        if let versionData = try? await runner.run(ContainerCommands.version) {
            let raw = String(decoding: versionData, as: UTF8.self)
            cliVersion = CLILocator.parseVersion(raw)
            if let v = cliVersion, !CLILocator.isSupported(v) {
                bootstrap = .unsupported(version: v)
                return
            }
        }

        await refreshSystem()
    }

    /// Re-run CLI/service detection (onboarding "Try again").
    func retryBootstrap() async {
        bootstrap = .checking
        await bootstrapIfNeeded()
    }

    /// Point at a specific `container` binary (onboarding "Locate…") and re-detect.
    func useCLIPath(_ path: String) async {
        settings.cliPathOverride = path
        await retryBootstrap()
    }

    /// Proceed despite an unsupported CLI version (onboarding "Continue anyway").
    func continueUnsupported() async {
        bootstrap = .checking
        await refreshSystem()
    }

    func refreshSystem() async {
        guard let client else { return }
        do {
            let status = try await client.systemStatus()
            systemStatus = status
            if status.isRunning {
                bootstrap = .ready
                await refreshDiskUsage()        // throttled — only the sidebar badge needs it off-page
                await containers.refresh()
                // One-time: import legacy contained.* card styles into the local store, now that we
                // no longer write personalization labels.
                personalization.migrateLegacyLabelsIfNeeded(containers.snapshots)
            } else {
                bootstrap = .serviceStopped
            }
        } catch {
            // `system status` exits non-zero when the service isn't running/registered.
            bootstrap = .serviceStopped
        }
    }

    /// `system df` is throttled off the System page (sidebar badge only); the banner self-clears.
    private static let diskUsageThrottle: TimeInterval = 8
    private static let bannerDuration: TimeInterval = 4

    private var lastDiskUsageDate: Date?
    /// Fetch `system df`. It's only needed for the sidebar badge off the System page, so throttle it
    /// to avoid spawning a process every tick; `force` (used by the System page) bypasses the throttle.
    private func refreshDiskUsage(force: Bool = false) async {
        guard let client else { return }
        if !force, let last = lastDiskUsageDate, Date().timeIntervalSince(last) < Self.diskUsageThrottle { return }
        if let usage = try? await client.diskUsage() { diskUsage = usage; lastDiskUsageDate = Date() }
    }

    /// Run a throwing CLI action, returning a user-facing error string on failure (nil on success).
    /// Collapses the repeated `do / catch CommandError / catch` blocks across the stores and sheets.
    func captured(_ work: () async throws -> Void) async -> String? {
        do { try await work(); return nil }
        catch let error as CommandError { return error.userMessage }
        catch { return error.localizedDescription }
    }

    /// One polling tick: refresh system + containers, run the restart watchdog, and refresh the
    /// resource list for whichever section is on screen. Called by `RefreshCoordinator`.
    func tick(section: AppSection) async {
        await refreshSystem()
        guard bootstrap == .ready, let client else { return }
        await watchdog.evaluate(snapshots: containers.snapshots, store: containers, client: client)
        await health.evaluate(snapshots: containers.snapshots, store: healthChecks, client: client)
        historyStore.recordMetrics(containers.statsByID)
        await refreshResource(section)
    }

    /// Refresh the cached list backing a resource page. Failures keep the last good data.
    func refreshResource(_ section: AppSection) async {
        guard let client, bootstrap == .ready else { return }
        switch section {
        case .images:
            imagesError = await captured { self.images = try await client.images() }
        case .volumes:
            if let v = try? await client.volumes() { volumes = v }
        case .networks:
            if let n = try? await client.networks() { networks = n }
        case .registries:
            if let r = try? await client.registries() { registries = r }
        case .system:
            await refreshDiskUsage(force: true)   // System page wants fresh numbers each tick
            if properties == nil, let p = try? await client.systemProperties() { properties = p }
        default:
            break
        }
    }

    // MARK: Create (pull-aware)

    /// Kick off a container create without blocking the caller (the Create sheet dismisses
    /// immediately and progress shows in the floating bar).
    func beginCreate(_ spec: RunSpec) {
        Task { await createContainer(spec) }
    }

    /// Create a container from the form. If its image isn't present locally, pull it first with a
    /// visible progress bar — so a fresh template or image "just works" instead of appearing to do
    /// nothing while the image silently downloads. Attaches local style + healthcheck on success.
    @discardableResult
    func createContainer(_ spec: RunSpec) async -> String? {
        guard client != nil else { return nil }
        if !(await imageIsLocal(spec.image)) {
            guard await pullImage(spec.image) else { return nil }   // pull failed; error surfaced
        }
        let newID = await containers.run(spec)
        if let newID {
            if !spec.personalization.isDefault { personalization.setOverride(spec.personalization, for: newID) }
            healthChecks.setCheck(spec.healthCheck, for: newID)
            historyStore.record(.lifecycle, containerID: newID, message: "Created \(newID)")
        }
        return newID
    }

    /// Pull an image, streaming `--progress` lines into the floating activity bar. Returns true on
    /// success. Used both by the create flow and as a standalone progress surface.
    @discardableResult
    func pullImage(_ reference: String) async -> Bool {
        guard let client else { return false }
        activity = ActivityState(title: "Pulling \(Format.shortImage(reference))…")
        defer { activity = nil }
        do {
            for try await line in client.streamPull(reference, platform: nil) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { activity?.detail = trimmed }
            }
            await refreshResource(.images)
            return true
        } catch let error as CommandError { flash(error.userMessage); return false }
        catch { flash(error.localizedDescription); return false }
    }

    /// Whether an image reference is already in the local store (tag-normalized compare so
    /// `nginx` matches `nginx:latest` and `docker.io/library/nginx:latest`).
    private func imageIsLocal(_ reference: String) async -> Bool {
        guard let client else { return false }
        let target = normalizedRef(reference)
        let list = (try? await client.images()) ?? images
        return list.contains { normalizedRef($0.reference) == target }
    }

    /// Strip the docker.io prefix and append `:latest` when no tag/digest is present.
    private func normalizedRef(_ reference: String) -> String {
        let short = Format.shortImage(reference)
        let nameStart = short.lastIndex(of: "/").map { short.index(after: $0) } ?? short.startIndex
        let namePart = short[nameStart...]
        if namePart.contains(":") || namePart.contains("@") { return short }
        return short + ":latest"
    }

    private var bannerClear: Task<Void, Never>?
    /// Show a transient banner for ~4s.
    func flash(_ message: String) {
        banner = message
        bannerClear?.cancel()
        bannerClear = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.bannerDuration))
            if !Task.isCancelled { self?.banner = nil }
        }
    }

    /// Apply a new history-retention window: persist it, sync the store, and prune immediately.
    func applyHistoryRetention(_ days: Int) {
        settings.historyRetentionDays = days
        historyStore.retentionDays = days
        historyStore.pruneOld()
    }

    /// Wipe all recorded metrics and events.
    func clearHistory() {
        historyStore.clearAll()
        flash("History cleared")
    }

    /// Start the container system service, then re-bootstrap.
    func startService() async {
        guard let client else { return }
        bootstrap = .checking
        _ = try? await client.runner.run(["system", "start"])
        await refreshSystem()
    }

    func stopService() async {
        guard let client else { return }
        bootstrap = .checking
        watchdog.reset()
        _ = try? await client.runner.run(["system", "stop"])
        await refreshSystem()
    }

    func restartService() async {
        guard let client else { return }
        bootstrap = .checking
        watchdog.reset()
        _ = try? await client.runner.run(["system", "stop"])
        _ = try? await client.runner.run(["system", "start"])
        await refreshSystem()
    }

    /// Short health label for the toolbar indicator.
    var serviceLabel: String {
        switch bootstrap {
        case .ready: return "Running"
        case .serviceStopped: return "Stopped"
        case .checking: return "Checking…"
        case .cliMissing: return "No CLI"
        case .unsupported(let v): return "v\(v)"
        }
    }

    var serviceHealthy: Bool { bootstrap == .ready }
}

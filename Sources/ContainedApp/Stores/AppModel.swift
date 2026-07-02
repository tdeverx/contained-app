import SwiftUI
import ContainedCore
import ContainedRuntime
import AppleContainerRuntime
import OSLog

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
    let migrator = StateMigrator()
    let logger: AppLogger
    /// Shared with `AppModel+ImageUpdates.swift` (Swift extensions in other files need ≥ internal).
    let manifestClient = RegistryManifestClient()

    private(set) var bootstrap: Bootstrap = .checking
    private(set) var client: (any ContainerRuntimeClient)?
    /// Resolved path to the `container` binary — needed to spawn the terminal's `exec` process.
    private(set) var cliURL: URL?
    private(set) var systemStatus: SystemStatus?
    private(set) var diskUsage: DiskUsage?
    private(set) var cliVersion: String?
    @ObservationIgnored private var containerStatsVisible = true
    @ObservationIgnored private var containerStatsStreamTask: Task<Void, Never>?
    @ObservationIgnored private var containerStatsStreamIDs: [String] = []
    @ObservationIgnored private var containerStatsStreamGeneration = 0
    @ObservationIgnored private var lastRecordedStatsRevision = 0
    @ObservationIgnored let diagnosticLogger = Logger(subsystem: "app.contained.Contained", category: "diagnostic")

    // Resource caches shared by toolbar panels, creation pages, and the container grid.
    private(set) var volumes: [VolumeResource] = []
    private(set) var networks: [NetworkResource] = []
    private(set) var registries: [RegistryLogin] = []
    private(set) var properties: SystemProperties?
    // `images`/`imagesError`/`imageUpdates` are written by both this file and the image-update sweep
    // in `AppModel+ImageUpdates.swift`, so their setters can't be `private(set)`.
    var images: [ContainedCore.ImageResource] = [] {
        didSet {
            imageGroupsCache = nil
            imageGroupIDByReferenceCache.removeAll(keepingCapacity: true)
        }
    }
    @ObservationIgnored var imageGroupsCache: [LocalImageTagGroup]?
    @ObservationIgnored var imageGroupIDByReferenceCache: [String: String] = [:]
    var imagesError: String?
    var imageUpdates: [String: ImageUpdateStatus] = [:] {
        didSet { Self.saveImageUpdates(imageUpdates) }
    }
    /// Transient watchdog/crash banner text (auto-cleared).
    var banner: String?
    /// A long-running operation surfaced as a floating progress bar (e.g. pulling an image before a
    /// run). `nil` when idle.
    var activity: ActivityState?
    var downgradeSchemaVersion: Int?
    /// The most recent create/pull failure, surfaced inline by the create form so the user can fix the
    /// problem without losing their spec. Cleared at the start of each attempt.
    var createError: String?
    // The image-update sweep state below is driven from `AppModel+ImageUpdates.swift`.
    var lastImageUpdateSweep: Date? {
        didSet { Self.saveLastImageUpdateSweep(lastImageUpdateSweep) }
    }
    static let imageUpdatesKey = "imageUpdateStatuses"
    static let imageUpdateLastSweepKey = "imageUpdateLastSweep"
    var imageUpdateInterval: TimeInterval { TimeInterval(settings.imageUpdateIntervalHours) * 60 * 60 }
    var imageUpdateLastRunDate: Date? { lastImageUpdateSweep }
    var imageUpdateNextRunDate: Date {
        lastImageUpdateSweep?.addingTimeInterval(imageUpdateInterval) ?? Date()
    }
    var imageUpdateIntervalDescription: String {
        "Every \(settings.imageUpdateIntervalHours) hour\(settings.imageUpdateIntervalHours == 1 ? "" : "s")"
    }
    var statsNormalizationContext: StatsNormalizationContext {
        StatsNormalizationContext(
            mode: settings.statsNormalizationMode,
            machineCPUs: properties?.machine?.cpus ?? ProcessInfo.processInfo.activeProcessorCount,
            machineMemoryBytes: Format.memoryBytes(fromSpec: properties?.machine?.memory)
                ?? ProcessInfo.processInfo.physicalMemory
        )
    }
    var availableRuntimeDescriptors: [RuntimeDescriptor] {
        [.appleContainer]
    }
    var runtimeCoreSelectorIsEnabled: Bool {
        availableRuntimeDescriptors.count > 1
    }
    var runtimeCoreSelectorDisabledReason: String {
        AppText.string(
            "runtime.coreSelector.disabledReason",
            defaultValue: "Apple container is the only available core in this build. Additional cores will enable this selector."
        )
    }

    /// One in-flight operation shown in the bottom progress bar.
    struct ActivityState: Equatable {
        var title: String
        var detail: String = ""
        var fraction: Double? = nil   // nil → indeterminate
    }

    init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        self.logger = AppLogger(settings: settings, history: historyStore)
        self.containers.logger = logger
        imageUpdates = Self.loadImageUpdates()
        lastImageUpdateSweep = Self.loadLastImageUpdateSweep()
        historyStore.retentionDays = settings.historyRetentionDays
        updater.channel = settings.updateChannel
        updater.automaticallyChecks = settings.appUpdateChecksEnabled
        applyStatsNormalizationContext()
        if case .newerOnDisk(let version) = migrator.reconcile() {
            downgradeSchemaVersion = version
        }
        watchdog.onRestart = { [weak self] snapshot, attempt in
            guard let self else { return }
            let name = self.containerStyle(for: snapshot)
                .displayName(fallback: snapshot.id)
            self.flash("Restarted \(name) (attempt \(attempt))")
            self.logger.record("Restarted \(name) (attempt \(attempt))",
                               category: .health,
                               severity: .warning,
                               containerID: snapshot.id)
            self.notifier.containerRestarted(name: name, attempt: attempt, enabled: settings.notifyOnCrash)
        }
        watchdog.onUnexpectedExit = { [weak self] snapshot in
            guard let self else { return }
            let name = self.containerStyle(for: snapshot)
                .displayName(fallback: snapshot.id)
            self.logger.record("\(name) exited unexpectedly",
                               category: .health,
                               severity: .warning,
                               containerID: snapshot.id)
            self.notifier.containerExited(name: name, enabled: settings.notifyOnCrash)
        }
        health.onUnhealthy = { [weak self] snapshot in
            guard let self else { return }
            let name = self.containerStyle(for: snapshot)
                .displayName(fallback: snapshot.id)
            self.flash("\(name) is unhealthy")
            self.logger.record("\(name) failed its healthcheck",
                               category: .health,
                               severity: .warning,
                               containerID: snapshot.id)
            self.notifier.containerUnhealthy(name: name, enabled: settings.notifyOnCrash)
            // Hand off to the restart policy (once per unhealthy transition, so it can't spin).
            let policy = RestartPolicy(label: snapshot.configuration.labels["contained.restart"])
            if policy != .no { Task { await self.containers.restart(snapshot.id) } }
        }
    }

    func bootstrapIfNeeded() async {
        logger.record("Checking container CLI", category: .system, severity: .debug)
        guard let url = AppleContainerCLILocator.locate(override: settings.cliPathOverride) else {
            bootstrap = .cliMissing
            logger.record("Container CLI missing", category: .system, severity: .error)
            return
        }
        let runner = CommandRunner(executableURL: url)
        let client = AppleContainerClient(runner: runner)
        self.client = client
        self.cliURL = url
        containers.client = client

        // Version check.
        if let versionData = try? await runner.run(ContainerCommands.version) {
            let raw = String(decoding: versionData, as: UTF8.self)
            cliVersion = AppleContainerCLILocator.parseVersion(raw)
            if let v = cliVersion, !AppleContainerCLILocator.isSupported(v) {
                bootstrap = .unsupported(version: v)
                logger.record("Unsupported container CLI version \(v)", category: .system, severity: .error)
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

    func setContainerStatsVisible(_ visible: Bool) {
        guard containerStatsVisible != visible else { return }
        containerStatsVisible = visible
        if visible { coordinator.wake() }
    }

    func setStatsNormalizationMode(_ mode: StatsNormalizationMode) {
        guard settings.statsNormalizationMode != mode else { return }
        settings.statsNormalizationMode = mode
        applyStatsNormalizationContext()
        guard mode == .machine else { return }
        Task {
            await self.loadPropertiesIfNeeded()
            self.applyStatsNormalizationContext()
        }
    }

    func runtimeDescriptor(for kind: RuntimeKind) -> RuntimeDescriptor {
        availableRuntimeDescriptors.first { $0.kind == kind } ?? .appleContainer
    }

    func runtimeClient(for kind: RuntimeKind) -> (any ContainerRuntimeClient)? {
        guard let client, client.descriptor.kind == kind else { return nil }
        return client
    }

    func applyStatsNormalizationContext() {
        containers.configureStatsNormalization(statsNormalizationContext)
    }

    func refreshSystem() async {
        guard let client else { return }
        let started = Date()
        do {
            let status = try await client.systemStatus()
            systemStatus = status
            if status.isRunning {
                bootstrap = .ready
                logger.record("Container service is running", category: .system, severity: .debug)
                if settings.statsNormalizationMode == .machine { await loadPropertiesIfNeeded() }
                applyStatsNormalizationContext()
                await refreshDiskUsage()        // throttled; the System panel can force a fresh read
                await containers.refresh()
                updateContainerStatsStream()
                // One-time: import legacy contained.* card styles into the local store, now that we
                // no longer write personalization labels.
                personalization.migrateLegacyLabelsIfNeeded(containers.snapshots)
            } else {
                bootstrap = .serviceStopped
                stopContainerStatsStream()
                logger.record("Container service is stopped", category: .system, severity: .warning)
            }
        } catch {
            // `system status` exits non-zero when the service isn't running/registered.
            bootstrap = .serviceStopped
            stopContainerStatsStream()
            logger.recordFailure("Couldn't read container service status",
                                 error: error,
                                 category: .system,
                                 severity: .error)
        }
        let elapsed = Date().timeIntervalSince(started)
        if elapsed >= 0.75 {
            diagnosticLogger.log(level: elapsed >= 1.5 ? .default : .info,
                                 "System refresh finished in \(elapsed.formatted(.number.precision(.fractionLength(2))), privacy: .public)s")
        }
    }

    /// `system df` is throttled during background refresh; the System panel can force a fresh read.
    private static let diskUsageThrottle: TimeInterval = 8
    private static let bannerDuration: TimeInterval = 4

    private var lastDiskUsageDate: Date?
    /// Fetch `system df`. Throttle background ticks to avoid spawning a process every poll; `force`
    /// bypasses the throttle for explicit System-panel refreshes.
    private func refreshDiskUsage(force: Bool = false) async {
        guard let client else { return }
        if !force, let last = lastDiskUsageDate, Date().timeIntervalSince(last) < Self.diskUsageThrottle { return }
        if let usage = try? await client.diskUsage() { diskUsage = usage; lastDiskUsageDate = Date() }
    }

    /// `images list` backs the toolbar Images panel, creation local-image choices, and update badges.
    /// Keep it warm app-wide, but throttle background ticks to avoid spawning a process each poll.
    private static let imagesThrottle: TimeInterval = 15
    private var lastImagesDate: Date?
    func refreshImagesIfStale(force: Bool = false) async {
        guard let client, bootstrap == .ready else { return }
        if !force, let last = lastImagesDate, Date().timeIntervalSince(last) < Self.imagesThrottle { return }
        let started = Date()
        imagesError = await captured { self.images = try await client.images() }
        lastImagesDate = Date()
        let elapsed = Date().timeIntervalSince(started)
        if elapsed >= 0.75 || force {
            let mode = force ? "force" : "stale"
            diagnosticLogger.log(level: elapsed >= 1.5 ? .default : .info,
                                 "Image refresh \(mode, privacy: .public) finished in \(elapsed.formatted(.number.precision(.fractionLength(2))), privacy: .public)s with \(self.images.count, privacy: .public) image(s)")
        }
    }

    /// Run a throwing CLI action, returning a user-facing error string on failure (nil on success).
    /// Collapses the repeated `do / catch CommandError / catch` blocks across the stores and sheets.
    func captured(_ work: () async throws -> Void) async -> String? {
        await capturedError(work)?.appDisplayMessage
    }

    func previewCreateCommand(for spec: RunSpec) -> [String] {
        (try? runtimeClient(for: spec.effectiveRuntimeKind)?.previewCreateCommand(for: spec.createRequest).command)
            ?? spec.arguments()
    }

    func imageDefaults(for spec: RunSpec) -> ContainerImageDefaults? {
        guard let client = runtimeClient(for: spec.effectiveRuntimeKind) else { return nil }
        return try? client.imageDefaults(for: spec.createRequest, in: images)
    }

    /// Run a throwing action while preserving the original error for Activity/package metadata.
    func capturedError(_ work: () async throws -> Void) async -> Error? {
        do {
            try await work()
            return nil
        } catch {
            return error
        }
    }

    /// One polling tick: refresh system + containers, run the restart watchdog, and keep the cached
    /// resources warm. Called by `RefreshCoordinator`.
    func tick() async {
        let started = Date()
        await refreshSystem()
        guard bootstrap == .ready, let client else { return }
        if settings.autoRestartEnabled {
            await watchdog.evaluate(snapshots: containers.snapshots, store: containers, client: client)
        }
        await health.evaluate(snapshots: containers.snapshots, store: healthChecks, client: client)
        recordFreshMetricsIfNeeded()
        await refreshNetworks()
        // Keep the image list warm app-wide (throttled), so the toolbar Images panel and the
        // update badges populate without first opening the Images panel.
        await refreshImagesIfStale()
        await checkImageUpdatesIfNeeded()
        let elapsed = Date().timeIntervalSince(started)
        if elapsed >= 0.75 {
            diagnosticLogger.log(level: elapsed >= 1.5 ? .default : .info,
                                 "Refresh tick finished in \(elapsed.formatted(.number.precision(.fractionLength(2))), privacy: .public)s")
        }
    }

    private func updateContainerStatsStream() {
        guard bootstrap == .ready, let client else {
            stopContainerStatsStream()
            return
        }
        let ids = containers.running.map(\.id).sorted()
        guard !ids.isEmpty else {
            stopContainerStatsStream()
            return
        }
        guard containerStatsStreamTask == nil || ids != containerStatsStreamIDs else { return }

        stopContainerStatsStream()
        containerStatsStreamGeneration &+= 1
        let generation = containerStatsStreamGeneration
        containerStatsStreamIDs = ids
        diagnosticLogger.info("Stats stream starting for \(ids.count, privacy: .public) container(s)")
        containerStatsStreamTask = Task(priority: .utility) { [weak self, client, ids, generation] in
            do {
                for try await samples in client.streamStats(ids: ids) {
                    guard !Task.isCancelled else { return }
                    guard !samples.isEmpty else { continue }
                    await MainActor.run {
                        guard let self,
                              self.containerStatsStreamGeneration == generation else { return }
                        self.containers.applyStreamedStats(samples)
                        self.recordFreshMetricsIfNeeded()
                    }
                }
            } catch {
                await MainActor.run {
                    guard let self,
                          self.containerStatsStreamGeneration == generation else { return }
                    self.diagnosticLogger.error("Stats stream failed: \(error.appDisplayMessage, privacy: .public)")
                }
            }

            await MainActor.run {
                guard let self,
                      self.containerStatsStreamGeneration == generation else { return }
                self.containerStatsStreamTask = nil
                self.containerStatsStreamIDs = []
                if self.containerStatsVisible { self.coordinator.wake() }
            }
        }
    }

    private func stopContainerStatsStream() {
        containerStatsStreamGeneration &+= 1
        containerStatsStreamTask?.cancel()
        containerStatsStreamTask = nil
        containerStatsStreamIDs = []
    }

    private func recordFreshMetricsIfNeeded() {
        guard containers.statsRevision != lastRecordedStatsRevision else { return }
        lastRecordedStatsRevision = containers.statsRevision
        historyStore.recordMetrics(containers.statsByID)
    }

    /// Refresh the data behind the System toolbar panel (volumes + a forced `system df`). Called from
    /// the panel's `.task` since System is no longer a standing page refreshed by the tick.
    func refreshSystemResources() async {
        guard client != nil, bootstrap == .ready else { return }
        await refreshDiskUsage(force: true)
        await refreshVolumes()
    }

    /// Refresh the registry-login list for Settings.
    func refreshRegistries() async {
        guard let client, bootstrap == .ready else { return }
        if let r = try? await client.registries() { registries = r }
    }

    /// Load the daemon's system properties once (the read-only Defaults shown in Settings). Cheap and
    /// idempotent — skips the call when already loaded.
    func loadPropertiesIfNeeded() async {
        guard properties == nil else { return }
        await reloadProperties()
    }

    /// Force-reload the daemon's system properties (e.g. after a kernel change).
    func reloadProperties() async {
        guard let client, bootstrap == .ready else { return }
        if let p = try? await client.systemProperties() {
            properties = p
            applyStatsNormalizationContext()
        }
    }

    /// Refresh the cached volume list. Volumes live in the System panel, so this is exposed directly
    /// and called when that panel opens.
    func refreshVolumes() async {
        guard let client, bootstrap == .ready else { return }
        if let v = try? await client.volumes() { volumes = v }
    }

    /// Refresh the cached network list. Networks back the collapsible groups on the Containers page.
    func refreshNetworks() async {
        guard let client, bootstrap == .ready else { return }
        if let n = try? await client.networks() { networks = n }
    }

    // MARK: Create (pull-aware)

    /// Create a container from the form. If its image isn't present locally, pull it first with a
    /// visible progress bar — so a fresh template or image "just works" instead of appearing to do
    /// nothing while the image silently downloads. Attaches local style + healthcheck on success.
    @discardableResult
    func createContainer(_ spec: RunSpec) async -> String? {
        guard runtimeClient(for: spec.effectiveRuntimeKind) != nil else {
            let error = UnsupportedRuntimeCapability(kind: spec.effectiveRuntimeKind, capability: .containers)
            createError = error.appDisplayMessage
            logger.recordFailure("Create requested unavailable runtime",
                                 error: error,
                                 category: .lifecycle,
                                 severity: .warning)
            return nil
        }
        createError = nil
        if !(await imageIsLocal(spec.image)) {
            guard await pullImage(spec.image) else {
                // pullImage already flashed; mirror it inline so the form can show it without dismissing.
                createError = banner ?? "Couldn't pull \(Format.shortImage(spec.image))."
                return nil
            }
        }
        let newID = await containers.run(spec)
        if newID == nil { createError = containers.errorMessage ?? "Couldn't create the container." }
        if let newID {
            if !spec.personalization.isDefault { personalization.setOverride(spec.personalization, for: newID) }
            healthChecks.setCheck(spec.healthCheck, for: newID)
            logger.record("Created \(newID)", category: .lifecycle, containerID: newID)
            flash("Created \(newID)")
        }
        return newID
    }

    /// Recreate an existing container from an edited spec. Pulls the replacement image before
    /// deleting the current container so an unavailable image does not strand the edit flow.
    @discardableResult
    func recreateContainer(originalID: String, spec: RunSpec) async -> String? {
        guard runtimeClient(for: spec.effectiveRuntimeKind) != nil else {
            let error = UnsupportedRuntimeCapability(kind: spec.effectiveRuntimeKind, capability: .containers)
            flash(error.appDisplayMessage)
            logger.recordFailure("Recreate requested unavailable runtime",
                                 error: error,
                                 category: .lifecycle,
                                 severity: .warning,
                                 containerID: originalID)
            return nil
        }
        if !(await imageIsLocal(spec.image)) {
            guard await pullImage(spec.image) else { return nil }
        }
        guard await containers.recreate(originalID: originalID, spec: spec) else { return nil }
        let newID = spec.name.isEmpty ? originalID : spec.name
        if newID != originalID {
            personalization.clearOverride(id: originalID)
            healthChecks.clear(id: originalID)
        }
        if spec.personalization.isDefault {
            personalization.clearOverride(id: newID)
        } else {
            personalization.setOverride(spec.personalization, for: newID)
        }
        healthChecks.setCheck(spec.healthCheck, for: newID)
        logger.record("Recreated \(newID)", category: .lifecycle, containerID: newID)
        return newID
    }

    /// Load images from an OCI `.tar` archive into the local store. Shared by app-wide drop, menu
    /// commands, and the add panel's image-archive path.
    func loadImageTar(at url: URL) {
        guard let client else { return }
        Task {
            if let error = await capturedError({ _ = try await client.loadImages(from: url.path) }) {
                flash(error.appDisplayMessage)
                logger.recordFailure("Failed loading image archive \(url.lastPathComponent)",
                                     error: error,
                                     category: .image,
                                     severity: .error)
            } else {
                await refreshImagesIfStale(force: true)
                flash("Loaded \(url.lastPathComponent)")
                logger.record("Loaded image archive \(url.lastPathComponent)", category: .image)
            }
        }
    }

    @discardableResult
    func createVolume(name: String, size: String?) async -> Bool {
        guard let client else { return false }
        let error = await capturedError {
            _ = try await client.createVolume(name: name, size: size)
            await refreshVolumes()
        }
        if let error {
            flash(error.appDisplayMessage)
            logger.recordFailure("Failed creating volume \(name)",
                                 error: error,
                                 category: .system,
                                 severity: .error)
            return false
        }
        flash("Created volume \(name)")
        logger.record("Created volume \(name)", category: .system)
        return true
    }

    @discardableResult
    func createNetwork(name: String, subnet: String?, internalOnly: Bool) async -> Bool {
        guard let client else { return false }
        let error = await capturedError {
            _ = try await client.createNetwork(name: name, subnet: subnet, internalOnly: internalOnly)
            await refreshNetworks()
        }
        if let error {
            flash(error.appDisplayMessage)
            logger.recordFailure("Failed creating network \(name)",
                                 error: error,
                                 category: .system,
                                 severity: .error)
            return false
        }
        flash("Created network \(name)")
        logger.record("Created network \(name)", category: .system)
        return true
    }

    /// Ensure an image is present locally, pulling it (with the progress bar) only if missing.
    /// Returns true when the image is available. Used by compose import before prefilling a form.
    @discardableResult
    func ensureImage(_ reference: String) async -> Bool {
        guard client != nil else { return false }
        if await imageIsLocal(reference) { return true }
        return await pullImage(reference)
    }

    /// Pull an image, streaming `--progress` lines into the floating activity bar. Returns true on
    /// success.
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
            await refreshImagesIfStale(force: true)
            logger.record("Pulled \(Format.shortImage(reference))", category: .image)
            return true
        } catch {
            flash(error.appDisplayMessage)
            logger.recordFailure("Failed pulling \(Format.shortImage(reference))",
                                 error: error,
                                 category: .image,
                                 severity: .error)
            return false
        }
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
        logger.record(message, category: .ui, severity: .warning)
        bannerClear?.cancel()
        bannerClear = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.bannerDuration))
            if !Task.isCancelled { self?.banner = nil }
        }
    }

    /// Start the container system service, then re-bootstrap.
    func startService() async {
        await runServiceLifecycle([.start], resetWatchdog: false)
        logger.record("Started container service", category: .system)
    }

    /// Stop the container system service, then re-bootstrap.
    func stopService() async {
        await runServiceLifecycle([.stop], resetWatchdog: true)
        logger.record("Stopped container service", category: .system, severity: .warning)
    }

    /// Stop then start the container system service, then re-bootstrap.
    func restartService() async {
        await runServiceLifecycle([.stop, .start], resetWatchdog: true)
        logger.record("Restarted container service", category: .system, severity: .warning)
    }

    /// Shared driver for service lifecycle commands. Marks the app `.checking` for immediate UI
    /// feedback, optionally resets the restart watchdog, runs each typed runtime action in order,
    /// then re-reads service status. Failures are intentionally ignored because `refreshSystem`
    /// reports the resulting state regardless.
    private func runServiceLifecycle(_ actions: [RuntimeSystemAction], resetWatchdog: Bool) async {
        guard let client else { return }
        bootstrap = .checking
        if resetWatchdog { watchdog.reset() }
        for action in actions { _ = try? await client.performSystemAction(action) }
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

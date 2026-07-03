import SwiftUI
import ContainedCore
import OSLog

/// Root app state: locates the CLI through Core, owns the backend orchestrator and feature stores, and tracks the
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

    let database: AppDatabase
    let settings: SettingsStore
    let containers = ContainersStore()
    let personalization: PersonalizationStore
    let coordinator = RefreshCoordinator()
    let watchdog = RestartWatchdog()
    let notifier = Notifier()
    let healthChecks: HealthCheckStore
    let health = HealthMonitor()
    let historyStore: HistoryStore
    let updater = UpdaterController()
    let migrator = StateMigrator()
    let logger: AppLogger
    /// Shared with `AppModel+ImageUpdates.swift` (Swift extensions in other files need ≥ internal).
    let manifestClient = Core.Registry.ManifestClient()

    private(set) var bootstrap: Bootstrap = .checking
    private(set) var client: Core.Orchestrator?
    private(set) var systemStatus: Core.System.Status?
    private(set) var diskUsage: Core.System.DiskUsage?
    private(set) var runtimeReadiness: [Core.Runtime.Kind: Core.RuntimeReadiness] = [:]
    @ObservationIgnored private var containerStatsVisible = true
    @ObservationIgnored private var containerStatsStreamTask: Task<Void, Never>?
    @ObservationIgnored private var containerStatsStreamIDs: [String] = []
    @ObservationIgnored private var containerStatsStreamGeneration = 0
    @ObservationIgnored private var lastRecordedStatsRevision = 0
    @ObservationIgnored var migrationStabilizationTimeout: TimeInterval = 120
    @ObservationIgnored var migrationPollInterval: TimeInterval = 2
    @ObservationIgnored let diagnosticLogger = Logger(subsystem: "app.contained.Contained", category: "diagnostic")

    // Resource caches shared by toolbar panels, creation pages, and the container grid.
    private(set) var volumes: [Core.Volume.Resource] = []
    private(set) var networks: [Core.Network.Resource] = []
    private(set) var registries: [Core.Registry.Login] = []
    private(set) var properties: Core.System.Properties?
    // `images`/`imagesError`/`imageUpdates` are written by both this file and the image-update sweep
    // in `AppModel+ImageUpdates.swift`, so their setters can't be `private(set)`.
    var images: [Core.Image.Resource] = [] {
        didSet {
            imageGroupsCache = nil
            imageGroupIDByReferenceCache.removeAll(keepingCapacity: true)
            database.upsertImages(images)
        }
    }
    @ObservationIgnored var imageGroupsCache: [Core.Image.LocalTagGroup]?
    @ObservationIgnored var imageGroupIDByReferenceCache: [String: String] = [:]
    var imagesError: String?
    var imageUpdates: [String: Core.Image.UpdateStatus] = [:] {
        didSet { database.updateImageStatuses(imageUpdates) }
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
        didSet {
            if let lastImageUpdateSweep {
                database.setSetting(lastImageUpdateSweep, for: Self.imageUpdateLastSweepKey)
            } else {
                database.deleteSetting(Self.imageUpdateLastSweepKey)
            }
        }
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
    var statsNormalizationContext: Core.Metrics.NormalizationContext {
        Core.Metrics.NormalizationContext(
            mode: settings.statsNormalizationMode,
            machineCPUs: properties?.machine?.cpus ?? ProcessInfo.processInfo.activeProcessorCount,
            machineMemoryBytes: Format.memoryBytes(fromSpec: properties?.machine?.memory)
                ?? ProcessInfo.processInfo.physicalMemory
        )
    }
    var registeredRuntimeDescriptors: [Core.Runtime.Descriptor] {
        client?.availableRuntimeDescriptors ?? []
    }
    var availableRuntimeDescriptors: [Core.Runtime.Descriptor] {
        registeredRuntimeDescriptors.filter { runtimeIsReady($0.kind) }
    }
    var supportedRuntimeDescriptors: [Core.Runtime.Descriptor] {
        Core.Runtime.supportedDescriptors
    }
    var runtimePickerIsEnabled: Bool {
        availableRuntimeDescriptors.count > 1
    }
    var runtimePickerDisabledReason: String {
        AppText.string(
            "runtime.selector.disabledReason",
            defaultValue: "Only one container runtime is reachable. Additional runtimes will appear here automatically."
        )
    }
    var appleRuntimeAvailable: Bool {
        client?.supportsRuntime(.appleContainer) == true
    }
    var appleRuntimeReady: Bool {
        runtimeIsReady(.appleContainer)
    }

    func runtimeIsReady(_ kind: Core.Runtime.Kind) -> Bool {
        runtimeReadiness[kind]?.state == .ready
    }

    func runtimeCLIURL(for kind: Core.Runtime.Kind) -> URL? {
        runtimeReadiness[kind]?.cliURL ?? client?.cliURL(for: kind)
    }

    func runtimeVersion(for kind: Core.Runtime.Kind) -> String? {
        runtimeReadiness[kind]?.version
    }

    /// One in-flight operation shown in the bottom progress bar.
    struct ActivityState: Equatable {
        var title: String
        var detail: String = ""
        var fraction: Double? = nil   // nil → indeterminate
    }

    init(database: AppDatabase = AppDatabase()) {
        self.database = database
        self.settings = SettingsStore(database: database)
        self.personalization = PersonalizationStore(database: database)
        self.healthChecks = HealthCheckStore(database: database)
        self.historyStore = HistoryStore(database: database)
        self.logger = AppLogger(settings: settings, history: historyStore)
        self.containers.logger = logger
        self.containers.database = database
        imageUpdates = database.imageStatusesSnapshot()
        lastImageUpdateSweep = database.setting(Self.imageUpdateLastSweepKey, fallback: Optional<Date>.none)
        historyStore.retentionDays = settings.historyRetentionDays
        updater.channel = settings.updateChannel
        updater.automaticallyChecks = settings.appUpdateChecksEnabled
        applyStatsNormalizationContext()
        let storedSchemaVersion: Int? = database.setting(StateMigrator.schemaVersionSettingKey, fallback: Optional<Int>.none)
        if case .newerOnDisk(let version) = migrator.reconcile(storedVersion: storedSchemaVersion) {
            downgradeSchemaVersion = version
        } else {
            database.setSetting(StateMigrator.currentSchemaVersion, for: StateMigrator.schemaVersionSettingKey)
        }
        watchdog.onRestart = { [weak self] snapshot, attempt in
            guard let self else { return }
            let name = self.containerStyle(for: snapshot)
                .displayName(fallback: snapshot.id)
            self.flash(AppText.restartedContainer(name, attempt: attempt))
            self.logger.record("Restarted \(name) (attempt \(attempt))",
                               category: .health,
                               severity: .warning,
                               containerID: snapshot.scopedID)
            self.notifier.containerRestarted(name: name, attempt: attempt, enabled: settings.notifyOnCrash)
        }
        watchdog.onUnexpectedExit = { [weak self] snapshot in
            guard let self else { return }
            let name = self.containerStyle(for: snapshot)
                .displayName(fallback: snapshot.id)
            self.logger.record("\(name) exited unexpectedly",
                               category: .health,
                               severity: .warning,
                               containerID: snapshot.scopedID)
            self.notifier.containerExited(name: name, enabled: settings.notifyOnCrash)
        }
        health.onUnhealthy = { [weak self] snapshot in
            guard let self else { return }
            let name = self.containerStyle(for: snapshot)
                .displayName(fallback: snapshot.id)
            self.flash(AppText.containerUnhealthy(name))
            self.logger.record("\(name) failed its healthcheck",
                               category: .health,
                               severity: .warning,
                               containerID: snapshot.scopedID)
            self.notifier.containerUnhealthy(name: name, enabled: settings.notifyOnCrash)
            // Hand off to the restart policy (once per unhealthy transition, so it can't spin).
            let policy = Core.Container.RestartPolicy(label: snapshot.configuration.labels["contained.restart"])
            if policy != .no { Task { await self.containers.restart(snapshot.scopedID) } }
        }
    }

    func bootstrapIfNeeded() async {
        logger.record("Checking container CLI", category: .system, severity: .debug)
        let configuration = Core.Configuration(runtimes: [
            .appleContainer: .init(cliPathOverride: settings.cliPathOverride),
            .docker: .init(cliPathOverride: settings.dockerCLIPathOverride),
        ])
        let result = await Core.Orchestrator.bootstrap(configuration: configuration)
        switch result {
        case .cliMissing(let readiness):
            runtimeReadiness = Dictionary(uniqueKeysWithValues: readiness.map { ($0.kind, $0) })
            database.upsertRuntimeReadiness(readiness,
                                            descriptors: supportedRuntimeDescriptors)
            bootstrap = .cliMissing
            logger.record("Container CLI missing", category: .system, severity: .error)
            return
        case .ready(let orchestrator, let readiness):
            client = orchestrator
            runtimeReadiness = Dictionary(uniqueKeysWithValues: readiness.map { ($0.kind, $0) })
            containers.client = orchestrator
            database.upsertRuntimeReadiness(readiness,
                                            descriptors: supportedRuntimeDescriptors)
            let anyReady = runtimeReadiness.values.contains { $0.state == .ready }
            if !anyReady, let apple = runtimeReadiness[.appleContainer], apple.state == .unsupported {
                bootstrap = .unsupported(version: apple.version ?? "")
                logger.record("Unsupported container CLI version \(apple.version ?? "unknown")", category: .system, severity: .error)
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

    func setStatsNormalizationMode(_ mode: Core.Metrics.NormalizationMode) {
        guard settings.statsNormalizationMode != mode else { return }
        settings.statsNormalizationMode = mode
        applyStatsNormalizationContext()
        guard mode == .machine else { return }
        Task {
            await self.loadPropertiesIfNeeded()
            self.applyStatsNormalizationContext()
        }
    }

    func runtimeDescriptor(for kind: Core.Runtime.Kind) -> Core.Runtime.Descriptor? {
        client?.descriptor(for: kind)
            ?? supportedRuntimeDescriptors.first { $0.kind == kind }
    }

    func core(for kind: Core.Runtime.Kind) -> Core.Orchestrator? {
        guard let client, runtimeIsReady(kind), client.supportsRuntime(kind) else { return nil }
        return client
    }

    func installRuntimeClientForTesting(_ orchestrator: Core.Orchestrator,
                                        readiness: [Core.RuntimeReadiness]? = nil,
                                        bootstrap: Bootstrap = .ready) {
        client = orchestrator
        containers.client = orchestrator
        if let readiness {
            runtimeReadiness = Dictionary(uniqueKeysWithValues: readiness.map { ($0.kind, $0) })
        } else {
            runtimeReadiness = Dictionary(uniqueKeysWithValues: orchestrator.availableRuntimeDescriptors.compactMap { descriptor in
                guard let cliURL = orchestrator.cliURL(for: descriptor.kind) else { return nil }
                return (descriptor.kind, Core.RuntimeReadiness(kind: descriptor.kind, cliURL: cliURL))
            })
        }
        database.upsertRuntimeReadiness(Array(runtimeReadiness.values),
                                        descriptors: supportedRuntimeDescriptors)
        self.bootstrap = bootstrap
    }

    func applyStatsNormalizationContext() {
        containers.configureStatsNormalization(statsNormalizationContext)
    }

    func refreshSystem() async {
        guard let client else { return }
        let started = Date()
        var firstStatus: Core.System.Status?
        for descriptor in registeredRuntimeDescriptors where descriptor.supports(.systemStatus) {
            guard runtimeReadiness[descriptor.kind]?.state != .unsupported else { continue }
            do {
                let status = try await client.systemStatus(runtimeKind: descriptor.kind)
                firstStatus = firstStatus ?? status
                if descriptor.kind == .appleContainer { systemStatus = status }
                if status.isRunning {
                    logger.record("\(descriptor.displayName) is running", category: .system, severity: .debug)
                    markRuntimeReadiness(descriptor.kind, state: .ready)
                } else {
                    logger.record("\(descriptor.displayName) is stopped", category: .system, severity: .warning)
                    markRuntimeReadiness(descriptor.kind, state: .endpointUnavailable)
                }
            } catch {
                logger.recordFailure("Couldn't read \(descriptor.displayName) status",
                                     error: error,
                                     category: .system,
                                     severity: .error)
                markRuntimeReadiness(descriptor.kind, state: .endpointUnavailable, message: error.appDisplayMessage)
            }
        }
        if systemStatus == nil { systemStatus = firstStatus }
        let hasReadyRuntime = runtimeReadiness.values.contains { $0.state == .ready }
        bootstrap = hasReadyRuntime ? .ready : .serviceStopped
        if hasReadyRuntime {
            if settings.statsNormalizationMode == .machine { await loadPropertiesIfNeeded() }
            applyStatsNormalizationContext()
            await refreshDiskUsage()
        }
        await containers.refresh()
        if hasReadyRuntime || !containers.running.isEmpty {
            updateContainerStatsStream()
        } else {
            stopContainerStatsStream()
        }
        let elapsed = Date().timeIntervalSince(started)
        if elapsed >= 0.75 {
            diagnosticLogger.log(level: elapsed >= 1.5 ? .default : .info,
                                 "System refresh finished in \(elapsed.formatted(.number.precision(.fractionLength(2))), privacy: .public)s")
        }
    }

    private func markRuntimeReadiness(_ kind: Core.Runtime.Kind,
                                      state: Core.RuntimeReadiness.State,
                                      message: String? = nil) {
        guard var readiness = runtimeReadiness[kind] else { return }
        readiness.state = state
        readiness.message = message
        runtimeReadiness[kind] = readiness
        database.upsertRuntimeReadiness(Array(runtimeReadiness.values),
                                        descriptors: supportedRuntimeDescriptors)
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
        if appleRuntimeReady, let usage = try? await client.diskUsage(runtimeKind: .appleContainer) {
            diskUsage = usage
            lastDiskUsageDate = Date()
        }
    }

    /// `images list` backs the toolbar Images panel, creation local-image choices, and update badges.
    /// Keep it warm app-wide, but throttle background ticks to avoid spawning a process each poll.
    private static let imagesThrottle: TimeInterval = 15
    private var lastImagesDate: Date?
    func refreshImagesIfNeeded(force: Bool = false) async {
        guard let client else { return }
        if !force, let last = lastImagesDate, Date().timeIntervalSince(last) < Self.imagesThrottle { return }
        let started = Date()
        imagesError = await captured { self.images = try await client.runtimeImages() }
        lastImagesDate = Date()
        let elapsed = Date().timeIntervalSince(started)
        if elapsed >= 0.75 || force {
            let mode = force ? "force" : "scheduled"
            diagnosticLogger.log(level: elapsed >= 1.5 ? .default : .info,
                                 "Image refresh \(mode, privacy: .public) finished in \(elapsed.formatted(.number.precision(.fractionLength(2))), privacy: .public)s with \(self.images.count, privacy: .public) image(s)")
        }
    }

    /// Run a throwing CLI action, returning a user-facing error string on failure (nil on success).
    /// Collapses the repeated `do / catch Core.Command.Error / catch` blocks across the stores and sheets.
    func captured(_ work: () async throws -> Void) async -> String? {
        await capturedError(work)?.appDisplayMessage
    }

    func previewCreateCommand(for spec: ContainerFormState) -> [String] {
        (try? core(for: spec.effectiveRuntimeKind)?.previewCreateCommand(for: spec.document).command)
            ?? []
    }

    func imageDefaults(for spec: ContainerFormState) -> Core.Container.ImageDefaults? {
        guard let client = core(for: spec.effectiveRuntimeKind) else { return nil }
        return try? client.imageDefaults(for: spec.document,
                                         in: images.filter { $0.runtimeKind == spec.effectiveRuntimeKind })
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
        guard let client else { return }
        if settings.autoRestartEnabled {
            await watchdog.evaluate(snapshots: containers.snapshots, store: containers, client: client)
        }
        await health.evaluate(snapshots: containers.snapshots, store: healthChecks, client: client)
        recordFreshMetricsIfNeeded()
        await refreshNetworks()
        // Keep the image list warm app-wide (throttled), so the toolbar Images panel and the
        // update badges populate without first opening the Images panel.
        await refreshImagesIfNeeded()
        await checkImageUpdatesIfNeeded()
        let elapsed = Date().timeIntervalSince(started)
        if elapsed >= 0.75 {
            diagnosticLogger.log(level: elapsed >= 1.5 ? .default : .info,
                                 "Refresh tick finished in \(elapsed.formatted(.number.precision(.fractionLength(2))), privacy: .public)s")
        }
    }

    private func updateContainerStatsStream() {
        guard let client else {
            stopContainerStatsStream()
            return
        }
        let scopedIDs = containers.running.map(\.scopedID).sorted()
        guard !scopedIDs.isEmpty else {
            stopContainerStatsStream()
            return
        }
        guard containerStatsStreamTask == nil || scopedIDs != containerStatsStreamIDs else { return }

        stopContainerStatsStream()
        containerStatsStreamGeneration &+= 1
        let generation = containerStatsStreamGeneration
        containerStatsStreamIDs = scopedIDs
        let groups = Dictionary(grouping: containers.running, by: \.runtimeKind)
            .mapValues { snapshots in snapshots.map(\.id).sorted() }
        diagnosticLogger.info("Stats stream starting for \(scopedIDs.count, privacy: .public) container(s)")
        containerStatsStreamTask = Task(priority: .utility) { [weak self, client, groups, generation] in
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for (runtimeKind, ids) in groups {
                        group.addTask {
                            for try await samples in client.streamStats(ids: ids, runtimeKind: runtimeKind) {
                                guard !Task.isCancelled else { return }
                                guard !samples.isEmpty else { continue }
                                await MainActor.run {
                                    guard let self,
                                          self.containerStatsStreamGeneration == generation else { return }
                                    self.containers.applyStreamedStats(samples)
                                    self.recordFreshMetricsIfNeeded()
                                }
                            }
                        }
                    }
                    try await group.waitForAll()
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
        let runtimeKinds = availableRuntimeDescriptors.filter { $0.supports(.registries) }.map(\.kind)
        var next: [Core.Registry.Login] = []
        for kind in runtimeKinds {
            next += (try? await client.registries(runtimeKind: kind)) ?? []
        }
        registries = next
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
        guard appleRuntimeReady else { return }
        if let p = try? await client.systemProperties(runtimeKind: .appleContainer) {
            properties = p
            applyStatsNormalizationContext()
        }
    }

    /// Refresh the cached volume list. Volumes live in the System panel, so this is exposed directly
    /// and called when that panel opens.
    func refreshVolumes() async {
        guard let client, bootstrap == .ready else { return }
        if let v = try? await client.runtimeVolumes() {
            volumes = v
            database.upsertVolumes(v)
        }
    }

    /// Refresh the cached network list. Networks back the collapsible groups on the Containers page.
    func refreshNetworks() async {
        guard let client, bootstrap == .ready else { return }
        if let n = try? await client.runtimeNetworks() {
            networks = n
            database.upsertNetworks(n)
        }
    }

    // MARK: Create (pull-aware)

    /// Create a container from the form. If its image isn't present locally, pull it first with a
    /// visible progress bar — so a fresh template or image "just works" instead of appearing to do
    /// nothing while the image silently downloads. Attaches local style + healthcheck on success.
    @discardableResult
    func createContainer(_ spec: ContainerFormState) async -> String? {
        guard core(for: spec.effectiveRuntimeKind) != nil else {
            let error = Core.Runtime.UnsupportedCapability(kind: spec.effectiveRuntimeKind, capability: .containers)
            createError = error.appDisplayMessage
            logger.recordFailure("Create requested unavailable runtime",
                                 error: error,
                                 category: .lifecycle,
                                 severity: .warning)
            return nil
        }
        createError = nil
        if !(await imageIsLocal(spec.image, runtimeKind: spec.effectiveRuntimeKind)) {
            guard await pullImage(spec.image, runtimeKind: spec.effectiveRuntimeKind) else {
                // pullImage already flashed; mirror it inline so the form can show it without dismissing.
                createError = banner ?? "Couldn't pull \(Format.shortImage(spec.image))."
                return nil
            }
        }
        let newID = await containers.run(spec)
        if newID == nil { createError = containers.errorMessage ?? "Couldn't create the container." }
        if let newID {
            let scopedID = containers.snapshots.first { $0.id == newID && $0.runtimeKind == spec.effectiveRuntimeKind }?.scopedID
                ?? spec.effectiveRuntimeKind.scopedID(for: newID)
            if !spec.personalization.isDefault { personalization.setOverride(spec.personalization, for: scopedID) }
            healthChecks.setCheck(spec.healthCheck, for: scopedID)
            logger.record("Created \(newID)", category: .lifecycle, containerID: scopedID)
            flash(AppText.createdContainer(newID))
        }
        return newID
    }

    /// Recreate an existing container from an edited spec. Pulls the replacement image before
    /// deleting the current container so an unavailable image does not strand the edit flow.
    @discardableResult
    func recreateContainer(originalID: String, spec: ContainerFormState) async -> String? {
        let originalSnapshot = containers.snapshots.first { $0.scopedID == originalID || $0.id == originalID }
        let originalRuntimeID = originalSnapshot?.id ?? originalID
        let originalScopedID = originalSnapshot?.scopedID ?? originalID
        guard core(for: spec.effectiveRuntimeKind) != nil else {
            let error = Core.Runtime.UnsupportedCapability(kind: spec.effectiveRuntimeKind, capability: .containers)
            flash(error.appDisplayMessage)
            logger.recordFailure("Recreate requested unavailable runtime",
                                 error: error,
                                 category: .lifecycle,
                                 severity: .warning,
                                 containerID: originalScopedID)
            return nil
        }
        if !(await imageIsLocal(spec.image, runtimeKind: spec.effectiveRuntimeKind)) {
            guard await pullImage(spec.image, runtimeKind: spec.effectiveRuntimeKind) else { return nil }
        }
        guard await containers.recreate(originalID: originalID, spec: spec) else { return nil }
        let newID = spec.name.isEmpty ? originalRuntimeID : spec.name
        let newScopedID = containers.snapshots.first { $0.id == newID && $0.runtimeKind == spec.effectiveRuntimeKind }?.scopedID
            ?? spec.effectiveRuntimeKind.scopedID(for: newID)
        if newID != originalRuntimeID {
            personalization.clearOverride(id: originalScopedID)
            healthChecks.clear(id: originalScopedID)
        }
        if spec.personalization.isDefault {
            personalization.clearOverride(id: newScopedID)
        } else {
            personalization.setOverride(spec.personalization, for: newScopedID)
        }
        healthChecks.setCheck(spec.healthCheck, for: newScopedID)
        logger.record("Recreated \(newID)", category: .lifecycle, containerID: newScopedID)
        return newID
    }

    /// Move a logical container record to another runtime. The source runtime instance is hidden and
    /// stopped first, then deleted only after the target is created and stabilizes.
    @discardableResult
    func migrateContainer(scopedID: String, to targetRuntimeKind: Core.Runtime.Kind) async -> Bool {
        guard let client else { return false }
        guard let source = containers.snapshots.first(where: { $0.scopedID == scopedID || $0.id == scopedID }) else {
            flash(ContainerRuntimeMigrationError.sourceNotFound.appDisplayMessage)
            return false
        }
        guard source.runtimeKind != targetRuntimeKind else { return true }
        guard client.supportsRuntime(targetRuntimeKind, capability: .containers) else {
            let error = Core.Runtime.UnsupportedCapability(kind: targetRuntimeKind, capability: .containers)
            flash(error.appDisplayMessage)
            return false
        }

        let sourceScopedID = source.scopedID
        let sourceRuntimeKind = source.runtimeKind
        let sourceDocument = Core.Schema.Document.containerEdit(from: source.configuration)
        let sourceStyle = containerStyle(for: source)
        let sourceHealthCheck = healthChecks.check(for: sourceScopedID)
        database.markContainerMigrationStarted(source: source,
                                               targetRuntimeKind: targetRuntimeKind,
                                               sourceDocument: sourceDocument)
        await containers.refresh()
        logger.record("Migrating \(source.displayName) from \(sourceRuntimeKind.rawValue) to \(targetRuntimeKind.rawValue)",
                      category: .lifecycle,
                      containerID: sourceScopedID)

        do {
            activity = ActivityState(title: AppText.string("container.migration.activity",
                                                           defaultValue: "Moving \(source.displayName)"))
            defer { activity = nil }
            let result = try await client.migrateContainer(source,
                                                           sourceDocument: sourceDocument,
                                                           targetRuntimeKind: targetRuntimeKind,
                                                           healthCheck: sourceHealthCheck,
                                                           stabilizationTimeout: migrationStabilizationTimeout,
                                                           pollInterval: migrationPollInterval,
                                                           onPullProgress: { line in
                                                               let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                                                               guard !trimmed.isEmpty else { return }
                                                               await MainActor.run { self.activity?.detail = trimmed }
                                                           })
            let target = result.target

            database.completeContainerMigration(sourceScopedID: sourceScopedID,
                                                target: target,
                                                targetDocument: result.targetDocument,
                                                sourceRuntimeKind: sourceRuntimeKind,
                                                sourceDocument: sourceDocument)
            if sourceStyle.isDefault {
                personalization.clearOverride(id: target.scopedID)
            } else {
                personalization.setOverride(sourceStyle, for: target.scopedID)
            }
            personalization.clearOverride(id: sourceScopedID)
            if let sourceHealthCheck {
                healthChecks.setCheck(sourceHealthCheck, for: target.scopedID)
                healthChecks.clear(id: sourceScopedID)
            }

            await containers.refresh()
            let runtimeName = runtimeDescriptor(for: targetRuntimeKind)?.displayName ?? targetRuntimeKind.rawValue
            flash(AppText.string("container.migration.complete", defaultValue: "Container moved to \(runtimeName)."))
            logger.record("Migrated \(source.displayName) to \(targetRuntimeKind.rawValue)",
                          category: .lifecycle,
                          containerID: target.scopedID)
            return true
        } catch {
            database.markContainerMigrationFailed(scopedID: sourceScopedID, message: error.appDisplayMessage)
            await containers.refresh()
            flash(error.appDisplayMessage)
            logger.recordFailure("Container migration failed",
                                 error: error,
                                 category: .lifecycle,
                                 severity: .error,
                                 containerID: sourceScopedID)
            return false
        }
    }

    /// Load images from an OCI `.tar` archive into the local store. Shared by app-wide drop, menu
    /// commands, and the add panel's image-archive path.
    func loadImageTar(at url: URL, runtimeKind: Core.Runtime.Kind) {
        guard let client else { return }
        Task {
            if let error = await capturedError({ _ = try await client.loadImages(from: url.path, runtimeKind: runtimeKind) }) {
                flash(error.appDisplayMessage)
                logger.recordFailure("Failed loading image archive \(url.lastPathComponent)",
                                     error: error,
                                     category: .image,
                                     severity: .error,
                                     containerID: runtimeKind.scopedID(for: url.lastPathComponent))
            } else {
                await refreshImagesIfNeeded(force: true)
                flash(AppText.loadedFile(url.lastPathComponent))
                logger.record("Loaded image archive \(url.lastPathComponent)",
                              category: .image,
                              containerID: runtimeKind.scopedID(for: url.lastPathComponent))
            }
        }
    }

    @discardableResult
    func createVolume(name: String,
                      size: String?,
                      runtimeKind: Core.Runtime.Kind) async -> Bool {
        guard let client else { return false }
        let error = await capturedError {
            _ = try await client.createVolume(name: name,
                                              size: size,
                                              runtimeKind: runtimeKind)
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
        flash(AppText.createdVolume(name))
        logger.record("Created volume \(name)", category: .system, containerID: runtimeKind.scopedID(for: name))
        return true
    }

    @discardableResult
    func createNetwork(name: String,
                       subnet: String?,
                       internalOnly: Bool,
                       runtimeKind: Core.Runtime.Kind) async -> Bool {
        guard let client else { return false }
        let error = await capturedError {
            _ = try await client.createNetwork(name: name,
                                               subnet: subnet,
                                               internalOnly: internalOnly,
                                               runtimeKind: runtimeKind)
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
        flash(AppText.createdNetwork(name))
        logger.record("Created network \(name)", category: .system, containerID: runtimeKind.scopedID(for: name))
        return true
    }

    /// Ensure an image is present locally, pulling it (with the progress bar) only if missing.
    /// Returns true when the image is available. Used by compose import before prefilling a form.
    @discardableResult
    func ensureImage(_ reference: String,
                     runtimeKind: Core.Runtime.Kind) async -> Bool {
        guard client != nil else { return false }
        if await imageIsLocal(reference, runtimeKind: runtimeKind) { return true }
        return await pullImage(reference, runtimeKind: runtimeKind)
    }

    /// Pull an image, streaming `--progress` lines into the floating activity bar. Returns true on
    /// success.
    @discardableResult
    func pullImage(_ reference: String, runtimeKind: Core.Runtime.Kind) async -> Bool {
        guard let client else { return false }
        activity = ActivityState(title: AppText.activityPullingImage(Format.shortImage(reference)))
        defer { activity = nil }
        do {
            for try await line in client.streamPull(reference, platform: nil, runtimeKind: runtimeKind) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { activity?.detail = trimmed }
            }
            await refreshImagesIfNeeded(force: true)
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
    private func imageIsLocal(_ reference: String, runtimeKind: Core.Runtime.Kind) async -> Bool {
        guard let client else { return false }
        let target = normalizedRef(reference)
        let list = (try? await client.runtimeImages()) ?? images
        return list.contains { $0.runtimeKind == runtimeKind && normalizedRef($0.reference) == target }
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
    private func runServiceLifecycle(_ actions: [Core.Runtime.SystemAction], resetWatchdog: Bool) async {
        guard appleRuntimeAvailable else {
            flash(AppText.string("runtime.service.appleOnly",
                                 defaultValue: "Service controls are only available for Apple container. Start Docker externally, then retry."))
            return
        }
        guard let client else { return }
        bootstrap = .checking
        if resetWatchdog { watchdog.reset() }
        for action in actions { _ = try? await client.performSystemAction(action, runtimeKind: .appleContainer) }
        await refreshSystem()
    }

    /// Short health label for the toolbar indicator.
    var serviceLabel: String {
        switch bootstrap {
        case .ready: return "Running"
        case .serviceStopped: return appleRuntimeAvailable ? "Stopped" : "Endpoint unavailable"
        case .checking: return "Checking…"
        case .cliMissing: return "No CLI"
        case .unsupported(let v): return "v\(v)"
        }
    }

    var serviceHealthy: Bool { bootstrap == .ready }
}

private enum ContainerRuntimeMigrationError: LocalizedError {
    case sourceNotFound

    var errorDescription: String? {
        switch self {
        case .sourceNotFound:
            return AppText.string("container.migration.error.sourceMissing",
                                  defaultValue: "The source container is no longer available.")
        }
    }
}

import SwiftUI
import AppKit
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
    let migrator = StateMigrator()
    let logger: AppLogger
    private let manifestClient = RegistryManifestClient()

    private(set) var bootstrap: Bootstrap = .checking
    private(set) var client: ContainerClient?
    /// Resolved path to the `container` binary — needed to spawn the terminal's `exec` process.
    private(set) var cliURL: URL?
    private(set) var systemStatus: SystemStatus?
    private(set) var diskUsage: DiskUsage?
    private(set) var cliVersion: String?

    // Resource caches shared by toolbar panels, creation pages, and the container grid.
    private(set) var images: [ContainedCore.ImageResource] = []
    private(set) var volumes: [VolumeResource] = []
    private(set) var networks: [NetworkResource] = []
    private(set) var registries: [RegistryLogin] = []
    private(set) var properties: SystemProperties?
    private(set) var imagesError: String?
    private(set) var imageUpdates: [String: ImageUpdateStatus] = [:] {
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
    private var lastImageUpdateSweep: Date? {
        didSet { Self.saveLastImageUpdateSweep(lastImageUpdateSweep) }
    }
    private static let imageUpdatesKey = "imageUpdateStatuses"
    private static let imageUpdateLastSweepKey = "imageUpdateLastSweep"
    private var imageUpdateInterval: TimeInterval { TimeInterval(settings.imageUpdateIntervalHours) * 60 * 60 }
    var imageUpdateLastRunDate: Date? { lastImageUpdateSweep }
    var imageUpdateNextRunDate: Date {
        lastImageUpdateSweep?.addingTimeInterval(imageUpdateInterval) ?? Date()
    }
    var imageUpdateIntervalDescription: String {
        "Every \(settings.imageUpdateIntervalHours) hour\(settings.imageUpdateIntervalHours == 1 ? "" : "s")"
    }

    var defaultImageStyle: Personalization {
        settings.imageDefaultStyleEnabled ? personalization.defaultImageStyle : Personalization()
    }

    func imageStyle(for reference: String) -> Personalization {
        let groupID = LocalImageTagGroup.groups(for: images).first { group in
            group.references.contains(reference)
        }?.id
        return personalization.imageDefault(for: reference, groupID: groupID) ?? defaultImageStyle
    }

    func imageGroupStyle(for group: LocalImageTagGroup) -> Personalization {
        personalization.imageGroupDefault(for: group.id) ?? defaultImageStyle
    }

    /// The group's style by id (used where only the id is known, e.g. a tag resolving its parent).
    func imageGroupStyle(forID id: String) -> Personalization {
        personalization.imageGroupDefault(for: id) ?? defaultImageStyle
    }

    func volumeStyle(for name: String) -> Personalization {
        var style = personalization.volumeStyle(for: name) ?? Personalization()
        style.normalizeVolumeWidgets()
        return style
    }

    // MARK: Per-volume I/O (aggregated from the containers that mount the volume)

    /// Containers that mount the named volume (matches a named-volume mount source).
    func containersMounting(volume name: String) -> [ContainerSnapshot] {
        containers.snapshots.filter { snapshot in
            snapshot.configuration.mounts.contains { $0.source == name }
        }
    }

    /// The current block read/write rate for a volume — summed across every container mounting it.
    func volumeIORate(for name: String, metric: GraphMetric) -> Double {
        containersMounting(volume: name).reduce(0) { total, snapshot in
            total + (containers.statsByID[snapshot.id].map { metric.value(from: $0) } ?? 0)
        }
    }

    /// A read/write sparkline series for a volume — the element-wise sum of the mounting containers'
    /// block-I/O history, right-aligned so the most recent samples line up.
    func volumeIOHistory(for name: String, metric: GraphMetric) -> [Double] {
        let series = containersMounting(volume: name).compactMap {
            containers.historyByID[$0.id]?[metric]?.values
        }
        return Self.sumRightAligned(series)
    }

    private static func sumRightAligned(_ series: [[Double]]) -> [Double] {
        let maxLen = series.map(\.count).max() ?? 0
        guard maxLen > 0 else { return [] }
        var result = [Double](repeating: 0, count: maxLen)
        for s in series {
            let offset = maxLen - s.count
            for (i, value) in s.enumerated() { result[offset + i] += value }
        }
        return result
    }

    func containerStyle(for snapshot: ContainerSnapshot) -> Personalization {
        let groupID = LocalImageTagGroup.groups(for: images).first { group in
            group.references.contains(snapshot.image)
        }?.id
        return personalization.resolved(id: snapshot.id,
                                        image: snapshot.image,
                                        groupID: groupID,
                                        fallback: defaultImageStyle)
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
        imageUpdates = Self.loadImageUpdates()
        lastImageUpdateSweep = Self.loadLastImageUpdateSweep()
        historyStore.retentionDays = settings.historyRetentionDays
        updater.channel = settings.updateChannel
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
        guard let url = CLILocator.locate(override: settings.cliPathOverride) else {
            bootstrap = .cliMissing
            logger.record("Container CLI missing", category: .system, severity: .error)
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

    func refreshSystem() async {
        guard let client else { return }
        do {
            let status = try await client.systemStatus()
            systemStatus = status
            if status.isRunning {
                bootstrap = .ready
                logger.record("Container service is running", category: .system, severity: .debug)
                await refreshDiskUsage()        // throttled; the System panel can force a fresh read
                await containers.refresh()
                // One-time: import legacy contained.* card styles into the local store, now that we
                // no longer write personalization labels.
                personalization.migrateLegacyLabelsIfNeeded(containers.snapshots)
            } else {
                bootstrap = .serviceStopped
                logger.record("Container service is stopped", category: .system, severity: .warning)
            }
        } catch {
            // `system status` exits non-zero when the service isn't running/registered.
            bootstrap = .serviceStopped
            logger.record("Couldn't read container service status: \(error.localizedDescription)",
                          category: .system,
                          severity: .error)
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
        imagesError = await captured { self.images = try await client.images() }
        lastImagesDate = Date()
    }

    /// Run a throwing CLI action, returning a user-facing error string on failure (nil on success).
    /// Collapses the repeated `do / catch CommandError / catch` blocks across the stores and sheets.
    func captured(_ work: () async throws -> Void) async -> String? {
        do { try await work(); return nil }
        catch let error as CommandError { return error.userMessage }
        catch { return error.localizedDescription }
    }

    /// One polling tick: refresh system + containers, run the restart watchdog, and keep the cached
    /// resources warm. Called by `RefreshCoordinator`.
    func tick() async {
        await refreshSystem()
        guard bootstrap == .ready, let client else { return }
        await watchdog.evaluate(snapshots: containers.snapshots, store: containers, client: client)
        await health.evaluate(snapshots: containers.snapshots, store: healthChecks, client: client)
        historyStore.recordMetrics(containers.statsByID)
        await refreshNetworks()
        // Keep the image list warm app-wide (throttled), so the toolbar Images panel and the
        // update badges populate without first opening the Images panel.
        await refreshImagesIfStale()
        await checkImageUpdatesIfNeeded()
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
        if let p = try? await client.systemProperties() { properties = p }
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
        guard client != nil else { return nil }
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
        guard client != nil else { return nil }
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
            if let error = await captured({ _ = try await client.loadImages(from: url.path) }) {
                flash(error)
                logger.record("Failed loading image archive \(url.lastPathComponent): \(error)",
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
        let error = await captured {
            _ = try await client.createVolume(name: name, size: size)
            await refreshVolumes()
        }
        if let error {
            flash(error)
            logger.record("Failed creating volume \(name): \(error)", category: .system, severity: .error)
            return false
        }
        flash("Created volume \(name)")
        logger.record("Created volume \(name)", category: .system)
        return true
    }

    @discardableResult
    func createNetwork(name: String, subnet: String?, internalOnly: Bool) async -> Bool {
        guard let client else { return false }
        let error = await captured {
            _ = try await client.createNetwork(name: name, subnet: subnet, internalOnly: internalOnly)
            await refreshNetworks()
        }
        if let error {
            flash(error)
            logger.record("Failed creating network \(name): \(error)", category: .system, severity: .error)
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
        } catch let error as CommandError {
            flash(error.userMessage)
            logger.record("Failed pulling \(Format.shortImage(reference)): \(error.userMessage)",
                          category: .image,
                          severity: .error)
            return false
        } catch {
            flash(error.localizedDescription)
            logger.record("Failed pulling \(Format.shortImage(reference)): \(error.localizedDescription)",
                          category: .image,
                          severity: .error)
            return false
        }
    }

    // MARK: Image updates

    func imageUpdateStatus(for reference: String) -> ImageUpdateStatus {
        imageUpdates[imageUpdateKey(reference)] ?? ImageUpdateStatus()
    }

    func imageUpdateKey(_ reference: String) -> String {
        RegistryImageReference.normalizedKey(reference)
    }

    func checkAllImageUpdates(manual: Bool = false) async {
        let unique = uniqueImageReferences()
        guard !unique.isEmpty else {
            if manual { flash("No local images to check") }
            return
        }
        for reference in unique {
            await checkImageUpdate(reference, notify: false)
        }
        lastImageUpdateSweep = Date()
        if manual {
            let available = unique.filter { imageUpdateStatus(for: $0).state == .updateAvailable }.count
            flash(available == 0 ? "Images are up to date" : "\(available) image update\(available == 1 ? "" : "s") available")
        }
    }

    func runImageUpdateSweepNow() async {
        await checkAllImageUpdates(manual: true)
    }

    @discardableResult
    func pullAvailableImageUpdates(manual: Bool = false) async -> Int {
        let references = uniqueImageReferences()
            .filter { imageUpdateStatus(for: $0).state == .updateAvailable }
        guard !references.isEmpty else {
            if manual { flash("No image updates available") }
            return 0
        }
        var updated = 0
        for reference in references where await pullImageUpdate(reference) {
            updated += 1
        }
        if manual {
            flash("Updated \(updated) image\(updated == 1 ? "" : "s")")
        }
        return updated
    }

    func checkContainerImageUpdates(manual: Bool = true) async {
        let references = uniqueContainerImageReferences()
        guard !references.isEmpty else {
            if manual { flash("No container images to check") }
            return
        }
        for reference in references {
            await checkImageUpdate(reference, notify: false)
        }
        if manual {
            let available = references.filter { imageUpdateStatus(for: $0).state == .updateAvailable }.count
            flash(available == 0 ? "Container images are up to date" : "\(available) container image update\(available == 1 ? "" : "s") available")
        }
    }

    @discardableResult
    func pullAvailableContainerImageUpdates(manual: Bool = true) async -> Int {
        let references = uniqueContainerImageReferences()
            .filter { imageUpdateStatus(for: $0).state == .updateAvailable }
        guard !references.isEmpty else {
            if manual { flash("No container image updates available") }
            return 0
        }
        var updated = 0
        for reference in references where await pullImageUpdate(reference) {
            updated += 1
        }
        if manual {
            flash("Updated \(updated) container image\(updated == 1 ? "" : "s")")
        }
        return updated
    }

    func checkImageUpdate(_ reference: String, notify: Bool = true) async {
        let key = imageUpdateKey(reference)
        let localDigest = localDigest(for: key)
        imageUpdates[key] = .checking(localDigest: localDigest)
        do {
            let remoteDigest = try await manifestClient.remoteDigest(for: reference)
            guard let localDigest, !localDigest.isEmpty else {
                imageUpdates[key] = .failed(localDigest: nil, message: "Local digest unavailable")
                if notify { flash("Couldn't compare \(Format.shortImage(reference)): local digest unavailable") }
                return
            }
            let status = ImageUpdateStatus.resolved(localDigest: localDigest, remoteDigest: remoteDigest)
            imageUpdates[key] = status
            if notify {
                switch status.state {
                case .updateAvailable:
                    flash("Update available for \(Format.shortImage(reference))")
                    logger.record("Update available for \(Format.shortImage(reference))",
                                  category: .image,
                                  severity: .warning)
                case .current:
                    flash("\(Format.shortImage(reference)) is up to date")
                default:
                    break
                }
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            imageUpdates[key] = .failed(localDigest: localDigest, message: message)
            if notify { flash(message) }
            logger.record("Failed checking image update for \(Format.shortImage(reference)): \(message)",
                          category: .image,
                          severity: .error)
        }
    }

    @discardableResult
    func pullImageUpdate(_ reference: String) async -> Bool {
        let ok = await pullImage(reference)
        if ok {
            await checkImageUpdate(reference, notify: false)
            flash("Updated \(Format.shortImage(reference))")
            logger.record("Updated \(Format.shortImage(reference))", category: .image)
        }
        return ok
    }

    private func checkImageUpdatesIfNeeded(now: Date = Date()) async {
        if let lastImageUpdateSweep, now.timeIntervalSince(lastImageUpdateSweep) < imageUpdateInterval { return }
        if images.isEmpty, let client {
            do {
                images = try await client.images()
                imagesError = nil
            } catch let error as CommandError {
                imagesError = error.userMessage
                return
            } catch {
                imagesError = error.localizedDescription
                return
            }
        }
        guard !images.isEmpty else { return }
        await checkAllImageUpdates(manual: false)
    }

    private func uniqueImageReferences() -> [String] {
        Array(Set(images.map(\.reference))).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private func uniqueContainerImageReferences() -> [String] {
        Array(Set(containers.snapshots.map(\.image))).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private func localDigest(for key: String) -> String? {
        images.first { imageUpdateKey($0.reference) == key }?.digest
    }

    private static func loadImageUpdates(defaults: UserDefaults = .standard) -> [String: ImageUpdateStatus] {
        guard let data = defaults.data(forKey: imageUpdatesKey),
              let decoded = try? JSONDecoder().decode([String: ImageUpdateStatus].self, from: data) else {
            return [:]
        }
        return decoded.mapValues { status in
            status.state == .checking ? ImageUpdateStatus() : status
        }
    }

    private static func saveImageUpdates(_ updates: [String: ImageUpdateStatus], defaults: UserDefaults = .standard) {
        let stable = updates.mapValues { status in
            status.state == .checking ? ImageUpdateStatus() : status
        }
        if let data = try? JSONEncoder().encode(stable) {
            defaults.set(data, forKey: imageUpdatesKey)
        }
    }

    private static func loadLastImageUpdateSweep(defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: imageUpdateLastSweepKey) as? Date
    }

    private static func saveLastImageUpdateSweep(_ date: Date?, defaults: UserDefaults = .standard) {
        if let date {
            defaults.set(date, forKey: imageUpdateLastSweepKey)
        } else {
            defaults.removeObject(forKey: imageUpdateLastSweepKey)
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
        logger.record("History cleared", category: .system, severity: .warning)
    }

    func exportConfiguration(to url: URL, sections: Set<AppStateSection> = Set(AppStateSection.allCases)) throws {
        let envelope = try AppStateEnvelope.make(from: self, sections: sections)
        let data = try JSONEncoder.containedBackup().encode(envelope)
        try data.write(to: url, options: .atomic)
    }

    func importConfiguration(from url: URL,
                             sections selected: Set<AppStateSection> = Set(AppStateSection.allCases),
                             replace: Bool) throws {
        let data = try Data(contentsOf: url)
        let imported = try JSONDecoder.containedBackup().decode(AppStateEnvelope.self, from: data)
        let envelope = try migrator.migrateToCurrent(imported)
        try apply(envelope: envelope, selected: selected, replace: replace)
        UserDefaults.standard.set(StateMigrator.currentSchemaVersion, forKey: StateMigrator.schemaVersionKey)
    }

    func resolveDowngradeByKeepingReadableData() {
        UserDefaults.standard.set(StateMigrator.currentSchemaVersion, forKey: StateMigrator.schemaVersionKey)
        downgradeSchemaVersion = nil
        flash("Kept readable local data")
    }

    func exportForDowngradeAndReset() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.containedBackup, .json]
        panel.nameFieldStringValue = "Contained Downgrade Backup.containedbackup"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try exportConfiguration(to: url)
            resetIncompatibleLocalState()
            downgradeSchemaVersion = nil
            flash("Exported backup and reset local state")
        } catch {
            flash(error.localizedDescription)
        }
    }

    func resetIncompatibleLocalState() {
        historyStore.clearAll()
        UserDefaults.standard.set(StateMigrator.currentSchemaVersion, forKey: StateMigrator.schemaVersionKey)
    }

    func purgeDeadRows() {
        let liveContainerIDs = Set(containers.snapshots.map(\.id))
        let liveImageRefs = Set(images.map(\.reference))
        let personalizations = personalization.purgeOrphans(liveContainerIDs: liveContainerIDs,
                                                            liveImageRefs: liveImageRefs)
        let checks = healthChecks.purgeOrphans(liveContainerIDs: liveContainerIDs)
        let history = historyStore.purgeOrphans(liveContainerIDs: liveContainerIDs)
        flash("Cleaned \(personalizations + checks + history.events + history.metrics) stale row(s)")
    }

    private func apply(envelope: AppStateEnvelope, selected: Set<AppStateSection>, replace: Bool) throws {
        if selected.contains(.settings), let value = envelope.sections[.settings] {
            settings.applyBackup(try value.decode(SettingsBackup.self))
            historyStore.retentionDays = settings.historyRetentionDays
            updater.channel = settings.updateChannel
        }
        if selected.contains(.personalization), let value = envelope.sections[.personalization] {
            personalization.applyBackup(try value.decode(PersonalizationBackup.self), replace: replace)
        }
        if selected.contains(.healthChecks), let value = envelope.sections[.healthChecks] {
            healthChecks.applyBackup(try value.decode([String: HealthCheck].self), replace: replace)
        }
        if selected.contains(.templates), let value = envelope.sections[.templates] {
            historyStore.applyTemplates(try value.decode([TemplateSnapshot].self), replace: replace)
        }
        if selected.contains(.history), let value = envelope.sections[.history] {
            historyStore.applyHistory(try value.decode(HistoryBackup.self), replace: replace)
        }
    }

    /// Start the container system service, then re-bootstrap.
    func startService() async {
        guard let client else { return }
        bootstrap = .checking
        _ = try? await client.runner.run(["system", "start"])
        await refreshSystem()
        logger.record("Started container service", category: .system)
    }

    func stopService() async {
        guard let client else { return }
        bootstrap = .checking
        watchdog.reset()
        _ = try? await client.runner.run(["system", "stop"])
        await refreshSystem()
        logger.record("Stopped container service", category: .system, severity: .warning)
    }

    func restartService() async {
        guard let client else { return }
        bootstrap = .checking
        watchdog.reset()
        _ = try? await client.runner.run(["system", "stop"])
        _ = try? await client.runner.run(["system", "start"])
        await refreshSystem()
        logger.record("Restarted container service", category: .system, severity: .warning)
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

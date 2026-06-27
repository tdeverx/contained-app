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
    private let manifestClient = RegistryManifestClient()

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
    private static let imageUpdateInterval: TimeInterval = 6 * 60 * 60
    private static let imageUpdatesKey = "imageUpdateStatuses"
    private static let imageUpdateLastSweepKey = "imageUpdateLastSweep"
    var imageUpdateLastRunDate: Date? { lastImageUpdateSweep }
    var imageUpdateNextRunDate: Date {
        lastImageUpdateSweep?.addingTimeInterval(Self.imageUpdateInterval) ?? Date()
    }
    var imageUpdateIntervalDescription: String { "Every 6 hours" }

    /// One in-flight operation shown in the bottom progress bar.
    struct ActivityState: Equatable {
        var title: String
        var detail: String = ""
        var fraction: Double? = nil   // nil → indeterminate
    }

    init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        imageUpdates = Self.loadImageUpdates()
        lastImageUpdateSweep = Self.loadLastImageUpdateSweep()
        historyStore.retentionDays = settings.historyRetentionDays
        updater.channel = settings.updateChannel
        if case .newerOnDisk(let version) = migrator.reconcile() {
            downgradeSchemaVersion = version
        }
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
        await checkImageUpdatesIfNeeded()
    }

    /// Refresh the cached list backing a resource page. Failures keep the last good data.
    func refreshResource(_ section: AppSection) async {
        guard let client, bootstrap == .ready else { return }
        switch section {
        case .images:
            imagesError = await captured { self.images = try await client.images() }
        case .volumes:
            if let v = try? await client.volumes() { volumes = v }
        case .containers:
            await refreshNetworks()   // networks are grouped into the Containers page now
        case .registries:
            if let r = try? await client.registries() { registries = r }
        case .system:
            await refreshDiskUsage(force: true)   // System page wants fresh numbers each tick
            if properties == nil, let p = try? await client.systemProperties() { properties = p }
        default:
            break
        }
    }

    /// Refresh the cached network list. Networks back the collapsible groups on the Containers page
    /// (there's no standalone Networks section), so this is exposed directly rather than via a key.
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
            historyStore.record(.lifecycle, containerID: newID, message: "Created \(newID)")
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
        historyStore.record(.lifecycle, containerID: newID, message: "Recreated \(newID)")
        return newID
    }

    /// Load images from an OCI `.tar` archive into the local store. Shared by the Images page drop
    /// target, the menu loader, and the creation wizard's "Select a file" path.
    func loadImageTar(at url: URL) {
        guard let client else { return }
        Task {
            if let error = await captured({ _ = try await client.loadImages(from: url.path) }) {
                flash(error)
            } else {
                await refreshResource(.images)
                flash("Loaded \(url.lastPathComponent)")
            }
        }
    }

    @discardableResult
    func createVolume(name: String, size: String?) async -> Bool {
        guard let client else { return false }
        let error = await captured {
            _ = try await client.createVolume(name: name, size: size)
            await refreshResource(.volumes)
        }
        if let error {
            flash(error)
            return false
        }
        flash("Created volume \(name)")
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
            return false
        }
        flash("Created network \(name)")
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
            historyStore.record(.pull, message: "Pulled \(Format.shortImage(reference))")
            return true
        } catch let error as CommandError { flash(error.userMessage); return false }
        catch { flash(error.localizedDescription); return false }
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
                    historyStore.record(.alert, message: "Update available for \(Format.shortImage(reference))")
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
        }
    }

    @discardableResult
    func pullImageUpdate(_ reference: String) async -> Bool {
        let ok = await pullImage(reference)
        if ok {
            await checkImageUpdate(reference, notify: false)
            flash("Updated \(Format.shortImage(reference))")
            historyStore.record(.pull, message: "Updated \(Format.shortImage(reference))")
        }
        return ok
    }

    private func checkImageUpdatesIfNeeded(now: Date = Date()) async {
        if let lastImageUpdateSweep, now.timeIntervalSince(lastImageUpdateSweep) < Self.imageUpdateInterval { return }
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

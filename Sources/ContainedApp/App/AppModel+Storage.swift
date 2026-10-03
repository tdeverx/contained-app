import Foundation
import ContainedCore

extension AppModel {
    var storageRuntimes: [Core.Runtime.Descriptor] {
        availableRuntimeDescriptors.filter { $0.supports(.storageManagement) }
    }

    func cleanupRuntimes(for action: Core.System.CleanupAction) -> [Core.Runtime.Descriptor] {
        Self.cleanupRuntimes(availableRuntimeDescriptors, for: action)
    }

    static func cleanupRuntimes(_ descriptors: [Core.Runtime.Descriptor], for action: Core.System.CleanupAction) -> [Core.Runtime.Descriptor] {
        descriptors.filter { descriptor in
            descriptor.supports(.storageManagement) || action.pruneCapability.map { descriptor.supports($0) } == true
        }
    }

    func refreshStorageAnalysis() async {
        guard let client else { return }
        for runtime in storageRuntimes {
            do {
                storageAnalyses[runtime.kind] = try await client.storageAnalysis(runtimeKind: runtime.kind)
                storageAnalysisErrors.removeValue(forKey: runtime.kind)
            } catch { storageAnalysisErrors[runtime.kind] = storageFailureMessage(error) }
        }
    }

    func prepareStorageCleanup(_ action: Core.System.CleanupAction) async {
        await prepareStorageCleanup([action], recommended: false)
    }

    /// Compaction is the only default selection. Cache and resource deletion always require opt-in.
    static func cleanupSelectedByDefault(_ action: Core.System.CleanupAction, recommended: Bool) -> Bool {
        !recommended || action.risk == .compaction
    }

    private func storageDeletionAllowed(runtimeKind: Core.Runtime.Kind) -> Bool {
        // Missing runtime objects do not protect their saved images, mounts, or networks from prune.
        let recoveries = containerRecreationRecoveries
        guard database.canPersist, !recoveries.contains(where: { $0.snapshot.runtimeKind == runtimeKind }) else {
            flash(AppText.string("storage.recoveryProtected", defaultValue: "Resolve container recreation and database recovery before deleting storage resources. Saved recovery images, volumes, and networks must be kept."))
            return false
        }
        return true
    }

    func prepareFreeUpSpace() async {
        await prepareStorageCleanup([.compactRunningContainers, .compactRunningBuilder,
                                     .resetBuilderCache, .unusedImages, .unusedVolumes, .unusedNetworks],
                                    recommended: true)
    }

    private func prepareStorageCleanup(_ actions: [Core.System.CleanupAction], recommended: Bool) async {
        guard let client, !storagePlanInFlight, !storageCleanupInFlight else { return }
        storagePlanInFlight = true
        defer { storagePlanInFlight = false }
        var plans: [Core.System.CleanupPlan] = []
        var requests: [RuntimePruneRequest] = []
        var deletionBlocked = false
        for action in actions {
            for runtime in cleanupRuntimes(for: action) {
                if action.risk != .compaction, !storageDeletionAllowed(runtimeKind: runtime.kind) {
                    deletionBlocked = true
                    continue
                }
                if runtime.supports(.storageManagement) {
                    do { plans.append(try await client.cleanupPlan(action, runtimeKind: runtime.kind)) }
                    catch { flash(storageFailureMessage(error)); return }
                } else {
                    requests.append(RuntimePruneRequest(runtimeKind: runtime.kind, action: action))
                }
            }
        }
        storageCleanupRecommended = recommended
        storageCleanupPlans = plans
        runtimePruneRequests = requests
        if plans.isEmpty && requests.isEmpty && !deletionBlocked {
            flash(AppText.string("storage.noCleanupRuntime", defaultValue: "No available runtime supports storage cleanup."))
        }
    }

    func performStorageCleanup(_ plans: [Core.System.CleanupPlan], pruneRequests: [RuntimePruneRequest] = [], automatic: Bool = false) async {
        guard let client, !storageCleanupInFlight, activity == nil, activeImageBuilds == 0,
              containers.busyIDs.isEmpty else { return }
        storageCleanupInFlight = true
        defer { storageCleanupInFlight = false }
        for plan in plans {
            if plan.action.risk != .compaction, !storageDeletionAllowed(runtimeKind: plan.runtimeKind) { continue }
            do {
                let result = try await client.executeCleanup(plan)
                // Failed candidates must not starve the rest of a larger inventory either.
                if automatic, result.completedCount + result.failureCodes.count > 0, let cursor = plan.resourceIDs.last {
                    storageAutomationCursors[plan.runtimeKind.scopedID(for: plan.action.rawValue)] = cursor
                    database.setSetting(storageAutomationCursors, for: "storageCleanupCursors")
                }
                if let after = result.after { storageAnalyses[plan.runtimeKind] = after }
                let before = result.before.map { Format.bytes($0.totalAllocatedBytes) } ?? "unknown"
                let after = result.after.map { Format.bytes($0.totalAllocatedBytes) } ?? "unknown"
                let reclaimed = result.reclaimedHostBytes.map(Format.bytes) ?? "unknown"
                let message = AppText.string("storage.cleanup.result", defaultValue: "Storage \(plan.action.rawValue): \(result.completedCount) commands completed, \(result.failureCodes.count) failed. Host allocation \(before) → \(after); observed reclaimed \(reclaimed).")
                logger.record(message, category: .system, severity: result.failureCodes.isEmpty ? .info : .warning)
                if !result.failureCodes.isEmpty {
                    flash(AppText.string("storage.cleanup.partialFailure", defaultValue: "Storage cleanup partially failed: \(result.failureCodes.joined(separator: ", ")). Refresh the preview before retrying."))
                }
            } catch {
                let message = storageFailureMessage(error)
                flash(message)
                logger.record(message, category: .system, severity: .warning)
            }
        }
        // Runtimes without exact storage planning retain their explicitly confirmed prune routes.
        for request in pruneRequests {
            guard storageDeletionAllowed(runtimeKind: request.runtimeKind) else { continue }
            do {
                switch request.action {
                case .stoppedContainers: _ = try await client.pruneContainers(runtimeKind: request.runtimeKind)
                case .danglingImages, .unusedImages:
                    _ = try await client.pruneImages(all: request.action == .unusedImages, runtimeKind: request.runtimeKind)
                case .unusedVolumes: _ = try await client.pruneVolumes(runtimeKind: request.runtimeKind)
                case .unusedNetworks: _ = try await client.pruneNetworks(runtimeKind: request.runtimeKind)
                default: continue
                }
                logger.record("Runtime prune completed: \(request.runtimeKind.rawValue), \(request.action.rawValue)", category: .system)
            } catch { flash(storageFailureMessage(error)) }
        }
        await refreshSystemResources()
        await refreshImagesIfNeeded(force: true)
        await containers.refresh()
    }

    func runStorageAutomationIfNeeded(now: Date = Date()) async {
        guard settings.storageCleanupPolicy.enabled, activity == nil, activeImageBuilds == 0,
              !storageCleanupInFlight, !storagePlanInFlight,
              lastStorageAutomationCheck.map({ now.timeIntervalSince($0) >= 3600 }) ?? true else { return }
        storagePlanInFlight = true
        defer { storagePlanInFlight = false }
        lastStorageAutomationCheck = now
        await refreshStorageAnalysis()
        guard let client else { return }
        var plans: [Core.System.CleanupPlan] = []
        for runtime in storageRuntimes {
            guard let analysis = storageAnalyses[runtime.kind],
                  analysis.measuredAt >= now.addingTimeInterval(-60),
                  settings.storageCleanupPolicy.shouldRun(analysis: analysis, lastRun: lastStorageAutomationRun, now: now) else { continue }
            var actions: [Core.System.CleanupAction] = []
            if settings.storageCleanupPolicy.compactContainers { actions.append(.compactRunningContainers) }
            if settings.storageCleanupPolicy.compactBuilder { actions.append(.compactRunningBuilder) }
            for action in actions {
                do {
                    let plan = try await client.cleanupPlan(action, runtimeKind: runtime.kind, automatic: true,
                                                            afterResourceID: storageAutomationCursors[runtime.kind.scopedID(for: action.rawValue)])
                    if !plan.commands.isEmpty { plans.append(plan) }
                } catch { storageAnalysisErrors[runtime.kind] = storageFailureMessage(error) }
            }
        }
        plans = plans.filter {
            ($0.action == .compactRunningContainers && settings.storageCleanupPolicy.compactContainers) ||
                ($0.action == .compactRunningBuilder && settings.storageCleanupPolicy.compactBuilder)
        }
        guard settings.storageCleanupPolicy.enabled, !plans.isEmpty,
              activity == nil, activeImageBuilds == 0 else { return }
        lastStorageAutomationRun = now
        database.setSetting(now, for: "lastStorageCleanupRun")
        await performStorageCleanup(plans, automatic: true)
    }

    func permitStorageIntensiveOperation(runtimeKind: Core.Runtime.Kind) async -> Bool {
        guard !storageCleanupInFlight else { return false }
        guard let client, client.supportsRuntime(runtimeKind, capability: .storageManagement) else { return true }
        guard let capacity = try? await client.storageCapacity(runtimeKind: runtimeKind) else { return true }
        if capacity.isLow {
            let free = ByteCountFormatter.string(fromByteCount: capacity.availableBytes, countStyle: .file)
            let message = AppText.string("storage.lowSpace", defaultValue: "Only \(free) is available on the runtime disk. Open System → Storage to review safe cleanup. Storage-intensive operations pause below 1 GiB.")
            if capacity.isCritical { lowStorageWarning = message }
            else { flash(message) }
        }
        return !capacity.isCritical && !storageCleanupInFlight
    }

    func storageFailureMessage(_ error: Error) -> String {
        if let storage = error as? Core.System.StorageError {
            switch storage {
            case .inventoryChanged, .stalePlan:
                return AppText.string("storage.previewChanged", defaultValue: "Storage inventory changed or the preview expired. Refresh the preview; nothing was removed.")
            default: break
            }
        }
        let code = (error as? any Core.Error.PackageError)?.packageErrorCode ?? "storageUnavailable"
        return AppText.string("storage.unavailable", defaultValue: "Storage operation unavailable [\(code)]. Check runtime status and refresh the analysis.")
    }
}

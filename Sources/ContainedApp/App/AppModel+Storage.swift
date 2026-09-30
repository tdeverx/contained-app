import Foundation
import ContainedCore

extension AppModel {
    var storageRuntimes: [Core.Runtime.Descriptor] {
        availableRuntimeDescriptors.filter { $0.supports(.storageManagement) }
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
        guard let client, !storagePlanInFlight, !storageCleanupInFlight else { return }
        storagePlanInFlight = true
        defer { storagePlanInFlight = false }
        var plans: [Core.System.CleanupPlan] = []
        for runtime in storageRuntimes {
            do { plans.append(try await client.cleanupPlan(action, runtimeKind: runtime.kind)) }
            catch { flash(storageFailureMessage(error)); return }
        }
        storageCleanupPlans = plans
    }

    func performStorageCleanup(_ plans: [Core.System.CleanupPlan]) async {
        guard let client, !storageCleanupInFlight, activity == nil, activeImageBuilds == 0 else { return }
        storageCleanupInFlight = true
        defer { storageCleanupInFlight = false }
        for plan in plans {
            do {
                let result = try await client.executeCleanup(plan)
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
                    let plan = try await client.cleanupPlan(action, runtimeKind: runtime.kind, automatic: true)
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
        await performStorageCleanup(plans)
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

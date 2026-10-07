import Foundation
import ContainedCore

extension AppModel {
    var containerRecreationRecoveries: [AppDatabase.ContainerRecreationRecovery] {
        database.containerRecreationRecoveries()
    }

    func keepExistingContainerRecreation(_ recovery: AppDatabase.ContainerRecreationRecovery) async -> Bool {
        guard database.canPersist, let client = core(for: recovery.snapshot.runtimeKind),
              !containers.busyIDs.contains(recovery.id) else { return false }
        do {
            let inventory = try await client.containerInventory(all: true)
            guard inventory.items.contains(where: { $0.scopedID == recovery.id }) else {
                flash(AppText.recreateOriginalUnavailable)
                return false
            }
            return database.completeContainerRecreate(sourceScopedID: recovery.id, replacementScopedID: recovery.id)
        } catch { flash(error.appDisplayMessage); return false }
    }

    @discardableResult
    func restoreContainerRecreation(_ recovery: AppDatabase.ContainerRecreationRecovery) async -> Bool {
        guard database.canPersist, let client = core(for: recovery.snapshot.runtimeKind),
              !containers.busyIDs.contains(recovery.id),
              await permitStorageIntensiveOperation(runtimeKind: recovery.snapshot.runtimeKind) else { return false }
        containers.busyIDs.insert(recovery.id)
        defer { containers.busyIDs.remove(recovery.id) }
        do {
            _ = try await client.restoreContainer(recovery.document, originalWasRunning: recovery.snapshot.state == .running)
            let recorded = database.completeContainerRecreate(sourceScopedID: recovery.id, replacementScopedID: recovery.id)
            await containers.refresh()
            logger.record("Restored original container from recreation recovery", category: .lifecycle, containerID: recovery.id)
            if !recorded {
                flash(AppText.string("recreate.recoverySaveFailed", defaultValue: "The original container was restored, but its recovery record could not be saved. Retry database recovery before closing this recovery."))
            }
            return recorded
        } catch {
            database.markContainerRecreateFailed(scopedID: recovery.id)
            await containers.refresh()
            flash(error.appDisplayMessage)
            logger.recordFailure("Container recreation recovery failed", error: error, category: .lifecycle,
                                 severity: .warning, containerID: recovery.id)
            return false
        }
    }
}

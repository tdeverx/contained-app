import Foundation
import ContainedCore

extension AppModel {
    /// Apply a new history-retention window: persist it, sync the store, and prune immediately.
    func applyHistoryRetention(_ days: Int) {
        settings.historyRetentionDays = days
        historyStore.retentionDays = days
        historyStore.pruneOld()
    }

    /// Wipe all recorded metrics and events.
    func clearHistory() {
        historyStore.clearAll()
        flash(AppText.historyCleared)
        logger.record("History cleared", category: .system, severity: .warning)
    }

    func exportConfiguration(to url: URL, sections: Set<AppStateSection> = Set(AppStateSection.allCases)) throws {
        try configurationData(sections: sections).write(to: url, options: .atomic)
    }

    func configurationData(sections: Set<AppStateSection> = Set(AppStateSection.allCases)) throws -> Data {
        let envelope = try AppStateEnvelope.make(from: self, sections: sections)
        return try JSONEncoder.containedBackup().encode(envelope)
    }

    func importConfiguration(from url: URL,
                             sections selected: Set<AppStateSection> = Set(AppStateSection.allCases),
                             replace: Bool) throws {
        let data = try Data(contentsOf: url)
        let imported = try JSONDecoder.containedBackup().decode(AppStateEnvelope.self, from: data)
        let envelope = try migrator.migrateToCurrent(imported)
        try apply(envelope: envelope, selected: selected, replace: replace)
        database.setSetting(StateMigrator.currentSchemaVersion, for: StateMigrator.schemaVersionSettingKey)
    }

    func resolveDowngradeByKeepingReadableData() {
        guard recoverPersistenceForDowngradeDecision() else { return }
        database.setSetting(StateMigrator.currentSchemaVersion, for: StateMigrator.schemaVersionSettingKey)
        guard database.canPersist, database.lastFailure == nil else { return }
        downgradeSchemaVersion = nil
        Task { await retryBootstrap() }
        flash(AppText.keptReadableLocalData)
    }

    @discardableResult
    func resetIncompatibleLocalState() -> Bool {
        guard recoverPersistenceForDowngradeDecision() else { return false }
        historyStore.clearAll()
        guard database.canPersist else { return false }
        database.setSetting(StateMigrator.currentSchemaVersion, for: StateMigrator.schemaVersionSettingKey)
        guard database.canPersist, database.lastFailure == nil else { return false }
        downgradeSchemaVersion = nil
        Task { await retryBootstrap() }
        return true
    }

    func purgeDeadRows() async {
        guard let client, database.canPersist, !purgingOrphans else { return }
        purgingOrphans = true
        defer { purgingOrphans = false }
        await containers.refresh()
        await refreshImagesIfNeeded(force: true)
        let containerKinds = Set(client.availableRuntimeDescriptors.filter { $0.supports(.containers) }.map(\.kind))
        let imageKinds = Set(client.availableRuntimeDescriptors.filter { $0.supports(.images) }.map(\.kind))
        guard database.canPersist, !containerKinds.isEmpty, !imageKinds.isEmpty,
              containerKinds.isSubset(of: containers.authoritativeRuntimeKinds),
              imageKinds.isSubset(of: imageInventoryRuntimeKinds) else {
            flash(AppText.string("settings.orphans.inventoryUnavailable", defaultValue: "Orphan cleanup requires successful container and image inventories from every connected runtime. Nothing was removed."))
            return
        }
        let records: [ContainerRecord]
        let tags: [ImageTagRecord]
        do {
            records = try database.fetchRequired(ContainerRecord.self)
            tags = try database.fetchRequired(ImageTagRecord.self)
        } catch { return }
        // Hidden migrations and missing recreations still own their saved configuration.
        let protected = records.filter { $0.isHiddenDuringMigration || $0.migrationStateRaw != "none" }
        let protectedImageRefs: [String]
        do {
            // A partial replacement updates the scalar image field, not the saved original.
            protectedImageRefs = try protected.map { record in
                guard let data = record.snapshotData else { return record.imageReference }
                return try JSONDecoder().decode(Core.Container.Snapshot.self, from: data).image
            }
        } catch {
            database.recordFailure(.decodeRecord(record: "protected container snapshot", detail: AppDatabase.safeDetail(error)))
            return
        }
        let liveContainerIDs = Set(containers.snapshots.map(\.scopedID) + protected.map(\.scopedID))
        let unavailableImageRefs = tags.filter { !imageKinds.contains(Core.Runtime.Kind(rawValue: $0.runtimeKindRaw)) }.map(\.reference)
        let liveImageRefs = Set(images.map(\.reference) + containers.snapshots.map(\.image) + protected.map(\.imageReference) + protectedImageRefs + unavailableImageRefs)
        let personalizations = personalization.purgeOrphans(liveContainerIDs: liveContainerIDs,
                                                            liveImageRefs: liveImageRefs,
                                                            authoritativeRuntimeKinds: containerKinds)
        let checks = healthChecks.purgeOrphans(liveContainerIDs: liveContainerIDs, authoritativeRuntimeKinds: containerKinds)
        let history = historyStore.purgeOrphans(liveContainerIDs: liveContainerIDs, authoritativeRuntimeKinds: containerKinds)
        flash(AppText.cleanedOrphanedRows(personalizations + checks + history.events + history.metrics))
    }

    private func apply(envelope: AppStateEnvelope, selected: Set<AppStateSection>, replace: Bool) throws {
        if selected.contains(.settings), let value = envelope.sections[.settings] {
            settings.applyBackup(try value.decode(SettingsBackup.self))
            historyStore.retentionDays = settings.historyRetentionDays
            updater.channel = settings.updateChannel
            applyStatsNormalizationContext()
        }
        if selected.contains(.personalization), let value = envelope.sections[.personalization] {
            personalization.applyBackup(try value.decode(PersonalizationBackup.self), replace: replace)
        }
        if selected.contains(.healthChecks), let value = envelope.sections[.healthChecks] {
            healthChecks.applyBackup(try value.decode([String: Core.Container.HealthCheck].self), replace: replace)
        }
        if selected.contains(.templates), let value = envelope.sections[.templates] {
            historyStore.applyTemplates(try value.decode([RecipeSnapshot].self), replace: replace)
        }
        if selected.contains(.history), let value = envelope.sections[.history] {
            historyStore.applyHistory(try value.decode(HistoryBackup.self), replace: replace)
        }
    }
}

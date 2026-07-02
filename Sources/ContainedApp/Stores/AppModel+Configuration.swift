import AppKit
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
        flash(AppText.keptReadableLocalData)
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
            flash(AppText.exportedBackupAndReset)
        } catch {
            flash(error.appDisplayMessage)
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
        flash(AppText.cleanedStaleRows(personalizations + checks + history.events + history.metrics))
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
            healthChecks.applyBackup(try value.decode([String: HealthCheck].self), replace: replace)
        }
        if selected.contains(.templates), let value = envelope.sections[.templates] {
            historyStore.applyTemplates(try value.decode([TemplateSnapshot].self), replace: replace)
        }
        if selected.contains(.history), let value = envelope.sections[.history] {
            historyStore.applyHistory(try value.decode(HistoryBackup.self), replace: replace)
        }
    }
}

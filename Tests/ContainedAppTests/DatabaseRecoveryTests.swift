import Foundation
import SwiftData
import Testing
import ContainedCore
@testable import ContainedApp

@Suite("Database failure recovery")
@MainActor
struct DatabaseRecoveryTests {
    private let diskFull = NSError(domain: NSCocoaErrorDomain, code: 640,
                                   userInfo: [NSLocalizedDescriptionKey: "secret-token must never appear"])

    @Test func prerequisiteFailureCannotInsertOrMarkContainersMissing() async {
        let db = AppDatabase(isStoredInMemoryOnly: true)
        let first = Core.Container.Snapshot.placeholder(id: "first", image: "alpine", runtimeKind: .appleContainer)
        _ = await db.upsertContainers([first])
        db.failureInjector = { operation in
            if operation == "fetch:PersonalizationRecord" { throw diskFull }
        }
        let second = Core.Container.Snapshot.placeholder(id: "second", image: "alpine", runtimeKind: .appleContainer)
        let result = await db.upsertContainers([second])
        #expect(!result.succeeded)
        #expect(!db.canPersist)
        #expect(db.lastFailure?.localizedDescription.contains("secret-token") == false)
        let saved = try? db.context.fetch(FetchDescriptor<ContainerRecord>())
        #expect(saved?.map(\.scopedID) == [first.scopedID])
        #expect(saved?.first?.isMissing == false)
        #expect(!db.context.hasChanges)
    }

    @Test func failedSaveRollsBackAndRemainsPausedUntilExplicitRecovery() async throws {
        let db = AppDatabase(isStoredInMemoryOnly: true)
        var date = Date()
        db.now = { date }
        db.setSetting("original", for: "test")
        var attempts = 0
        db.failureInjector = { operation in
            if operation == "save" { attempts += 1; throw diskFull }
        }
        db.setSetting("failed", for: "test")
        db.setSetting("still-paused", for: "test")
        #expect(attempts == 1)
        #expect(!db.context.hasChanges)
        db.failureInjector = nil
        date = date.addingTimeInterval(61)
        #expect(!db.canPersist)
        db.setSetting("must-not-overwrite", for: "test")
        #expect(db.retryPersistence())
        #expect(db.setting("test", fallback: "") == "original")
        db.setSetting("recovered", for: "test")
        #expect(db.lastFailure == nil)
        #expect(db.setting("test", fallback: "") == "recovered")
    }

    @Test func failedStartupReadsCannotErasePersonalizationOrHealthChecksAfterRetry() throws {
        for failingModel in ["PersonalizationRecord", "HealthCheckRecord", "ImageRecord"] {
            let database = AppDatabase(isStoredInMemoryOnly: true)
            var style = Personalization()
            style.nickname = "Retained style"
            let check = Core.Container.HealthCheck(command: ["true"], enabled: true)
            PersonalizationStore(database: database).setOverride(style, for: "first")
            HealthCheckStore(database: database).setCheck(check, for: "first")
            database.failureInjector = { operation in
                if operation == "fetch:\(failingModel)" { throw diskFull }
            }
            // Whichever store fails first pauses all writes; neither empty cache
            // may become an authoritative replacement after recovery.
            let styles = PersonalizationStore(database: database)
            let health = HealthCheckStore(database: database)
            styles.clearOverride(id: "first")
            health.clear(id: "first")
            #expect(!database.canPersist)
            database.failureInjector = nil
            database.retryPersistence()
            styles.setOverride(style, for: "second")
            health.setCheck(check, for: "second")
            #expect(styles.override(for: "first") == style)
            #expect(health.check(for: "first") == check)
            #expect(try database.fetchRequired(PersonalizationRecord.self).filter { $0.scopeRaw == "personalizationOverrides" }.count == 2)
            #expect(try database.fetchRequired(HealthCheckRecord.self).count == 2)
        }
    }

    @Test func appRetryReloadsStartupSettingsAndScheduledStateWithoutSavingDefaults() async {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let original = SettingsStore(database: database)
        original.refreshInterval = 17
        original.imageUpdateChecksEnabled = false
        original.historyRetentionDays = 30
        original.loggingLevel = .off
        var policy = Core.System.StorageCleanupPolicy()
        policy.enabled = true
        original.storageCleanupPolicy = policy
        let lastRun = Date(timeIntervalSince1970: 1_000)
        database.setSetting(lastRun, for: "lastStorageCleanupRun")
        database.setSetting(lastRun, for: AppModel.imageUpdateLastSweepKey)
        database.setSetting(["apple-container::compactRunningContainers": "c15"], for: "storageCleanupCursors")
        database.failureInjector = { operation in
            if operation == "fetch:AppSettingRecord" { throw diskFull }
        }
        var savesBeforeRuntimeDetection = 0
        let app = AppModel(database: database, bootstrapRuntime: { _ in
            savesBeforeRuntimeDetection = database.successfulSaveCount
            return .cliMissing(runtimes: [])
        })
        #expect(app.settings.refreshInterval == 2)
        #expect(!database.canPersist)
        app.settings.refreshInterval = 99
        let saves = database.successfulSaveCount
        await app.retryPersistence()
        #expect(!database.canPersist)
        #expect(app.settings.refreshInterval == 99)
        database.failureInjector = nil
        await app.retryPersistence()
        #expect(app.settings.refreshInterval == 17)
        #expect(!app.settings.imageUpdateChecksEnabled)
        #expect(app.settings.storageCleanupPolicy.enabled)
        #expect(app.historyStore.retentionDays == 30)
        #expect(app.lastStorageAutomationRun == lastRun)
        #expect(app.lastImageUpdateSweep == lastRun)
        #expect(app.storageAutomationCursors["apple-container::compactRunningContainers"] == "c15")
        // Runtime re-detection may persist new readiness; the cache reload itself must not write.
        #expect(savesBeforeRuntimeDetection == saves)
        #expect(database.lastFailure == nil)
        app.settings.refreshInterval = 18
        #expect(database.setting("refreshInterval", fallback: 0) == 18)
        #expect(database.setting("historyRetentionDays", fallback: 0) == 30)
    }

    @Test func backgroundUpdatesCannotOverwriteSavedStartupStateAfterTheOldCooldown() async throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        var date = Date()
        database.now = { date }
        SettingsStore(database: database).loggingLevel = .off
        var saved = Core.Registry.UpdateRetryPolicy()
        saved.failed("ghcr.io/team/saved", runtimeKind: .appleContainer, kind: .unauthorized, now: date)
        database.setSetting(saved, for: "registryUpdateRetryPolicy")
        database.setSetting(date, for: AppModel.imageUpdateLastSweepKey)
        let originalSweep = date
        database.failureInjector = { operation in
            if operation == "fetch:AppSettingRecord" { throw diskFull }
        }
        let app = AppModel(database: database, bootstrapRuntime: { _ in .cliMissing(runtimes: []) })
        database.failureInjector = nil
        date = date.addingTimeInterval(61)
        app.registryManifestLookup = { _, _ in throw Core.Registry.ManifestError.unauthorized }
        await app.checkImageUpdate("ghcr.io/team/background", runtimeKind: .appleContainer, notify: false)
        app.lastImageUpdateSweep = date
        #expect(!database.canPersist)
        let rows = try database.context.fetch(FetchDescriptor<AppSettingRecord>())
        let retryData = try #require(rows.first { $0.key == "registryUpdateRetryPolicy" }?.valueData)
        #expect(try JSONDecoder().decode(Core.Registry.UpdateRetryPolicy.self, from: retryData) == saved)
        let sweepData = try #require(rows.first { $0.key == AppModel.imageUpdateLastSweepKey }?.valueData)
        #expect(try JSONDecoder().decode(Date.self, from: sweepData) == originalSweep)
        await app.retryPersistence()
        #expect(database.canPersist)
        #expect(app.registryRetryPolicy == saved)
        #expect(app.lastImageUpdateSweep == originalSweep)
    }

    @Test func retryRebootstrapsWithTheRestoredCLIOverride() async {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let settings = SettingsStore(database: database)
        settings.loggingLevel = .off
        settings.setRuntimePathOverride("/fixture/custom/container", for: .appleContainer)
        database.failureInjector = { operation in
            if operation == "fetch:AppSettingRecord" { throw diskFull }
        }
        var configurations: [Core.Configuration] = []
        let app = AppModel(database: database, bootstrapRuntime: { configuration in
            configurations.append(configuration)
            return .cliMissing(runtimes: [])
        })
        await app.bootstrapIfNeeded()
        #expect(app.bootstrap == .cliMissing)
        #expect(configurations.count == 1)
        #expect(configurations.first?.configuration(for: .appleContainer).cliPathOverride == "")
        database.failureInjector = nil
        await app.retryPersistence()
        #expect(configurations.count == 2)
        #expect(configurations.last?.configuration(for: .appleContainer).cliPathOverride == "/fixture/custom/container")
    }

    @Test func recoveryReloadsHistoryCountsAndLoadedRecentActivity() async throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        SettingsStore(database: database).loggingLevel = .off
        let event = EventRecord(timestamp: Date(), containerID: nil, kind: .system, message: "original")
        database.context.insert(event)
        database.context.insert(RecipeRecord(name: "saved template", documentData: Data()))
        #expect(database.save())
        database.failureInjector = { operation in
            if operation == "fetch:EventRecord" { throw diskFull }
        }
        let app = AppModel(database: database, bootstrapRuntime: { _ in .cliMissing(runtimes: []) })
        #expect(app.historyStore.activitySummary == ActivitySummary())
        await app.historyStore.loadRecentActivity()
        #expect(app.historyStore.recentActivity.first?.message == "original")
        // Simulate saved data changing independently while the app's projections are stale.
        event.message = "restored"
        event.isRead = true
        try database.context.save()
        let revision = app.historyStore.activityRevision
        database.failureInjector = nil
        await app.retryPersistence()
        #expect(app.historyStore.activitySummary == ActivitySummary(totalEvents: 1, unreadEvents: 0, templateCount: 1))
        #expect(app.historyStore.recentActivity.first?.message == "restored")
        #expect(app.historyStore.recentActivity.first?.isRead == true)
        #expect(app.historyStore.activityRevision > revision)
        #expect(database.canPersist)
    }

    @Test func recoveryRestoresNewerSchemaDecisionBeforeAnyWritesOrBootstrap() async throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        SettingsStore(database: database).loggingLevel = .off
        let future = StateMigrator.currentSchemaVersion + 1
        database.setSetting(future, for: StateMigrator.schemaVersionSettingKey)
        database.failureInjector = { operation in
            if operation == "fetch:AppSettingRecord" { throw diskFull }
        }
        var calls = 0
        let app = AppModel(database: database, bootstrapRuntime: { _ in
            calls += 1
            return .cliMissing(runtimes: [])
        })
        #expect(app.downgradeSchemaVersion == nil)
        // An unrepaired older duplicate must not hide the authoritative newer schema.
        database.context.insert(AppSettingRecord(key: StateMigrator.schemaVersionSettingKey,
                                                  valueData: try AppDatabase.encoded(StateMigrator.currentSchemaVersion),
                                                  updatedAt: .distantPast))
        try database.context.save()
        database.failureInjector = nil
        let saves = database.successfulSaveCount
        await app.retryPersistence()
        #expect(app.downgradeSchemaVersion == future)
        #expect(!database.canPersist)
        #expect(database.successfulSaveCount == saves)
        #expect(try database.context.fetch(FetchDescriptor<AppSettingRecord>()).filter {
            $0.key == StateMigrator.schemaVersionSettingKey
        }.count == 2)
        #expect(calls == 0)
        app.resolveDowngradeByKeepingReadableData()
        #expect(app.downgradeSchemaVersion == nil)
        #expect(database.canPersist)
        #expect(database.setting(StateMigrator.schemaVersionSettingKey, fallback: 0) == StateMigrator.currentSchemaVersion)
    }

    @Test func retryQueuesRestoredConfigurationBehindAnInFlightBootstrap() async {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let settings = SettingsStore(database: database)
        settings.loggingLevel = .off
        settings.setRuntimePathOverride("/fixture/restored/container", for: .appleContainer)
        database.failureInjector = { operation in
            if operation == "fetch:AppSettingRecord" { throw diskFull }
        }
        let started = AsyncStream<Void>.makeStream()
        var release: CheckedContinuation<Void, Never>?
        var paths: [String?] = []
        let app = AppModel(database: database, bootstrapRuntime: { configuration in
            paths.append(configuration.configuration(for: .appleContainer).cliPathOverride)
            if paths.count == 1 {
                await withCheckedContinuation { continuation in
                    release = continuation
                    started.continuation.yield(())
                }
            }
            return .cliMissing(runtimes: [])
        })
        let initial = Task { await app.bootstrapIfNeeded() }
        for await _ in started.stream { break }
        database.failureInjector = nil
        let retry = Task { await app.retryPersistence() }
        for _ in 0..<100 {
            if app.settings.runtimePathOverride(for: .appleContainer) == "/fixture/restored/container" { break }
            await Task.yield()
        }
        #expect(app.settings.runtimePathOverride(for: .appleContainer) == "/fixture/restored/container")
        #expect(paths == [""])
        release?.resume()
        await initial.value
        await retry.value
        #expect(paths == ["", "/fixture/restored/container"])
        started.continuation.finish()
    }

    @Test func repairKeepsNewestSnapshotAndRecoveryMetadata() throws {
        let db = AppDatabase(isStoredInMemoryOnly: true)
        let older = ContainerRecord(scopedID: "apple-container::web", runtimeKindRaw: "apple-container",
                                    runtimeID: "web", displayName: "old", imageReference: "old",
                                    statusRaw: "stopped", documentData: Data([1]),
                                    migrationStateRaw: "recreateFailed", updatedAt: .distantPast)
        let newer = ContainerRecord(scopedID: older.scopedID, runtimeKindRaw: older.runtimeKindRaw,
                                    runtimeID: "web", displayName: "new", imageReference: "new",
                                    statusRaw: "running", snapshotData: Data([2]))
        db.context.insert(older)
        db.context.insert(newer)
        db.context.insert(NetworkRecord(scopedID: "apple-container::default", runtimeKindRaw: "apple-container", name: "default"))
        db.context.insert(NetworkRecord(scopedID: "apple-container::default", runtimeKindRaw: "apple-container", name: "default"))
        #expect(db.save())
        db.repairDuplicateRecords()
        let records = try db.fetchRequired(ContainerRecord.self)
        #expect(records.count == 1)
        #expect(records.first?.imageReference == "new")
        #expect(records.first?.documentData == Data([1]))
        #expect(records.first?.migrationStateRaw == "recreateFailed")
        #expect(try db.fetchRequired(NetworkRecord.self).count == 1)
    }

    @Test func repeatedSettingsAndRuntimeReadinessCreateNoWrites() {
        let db = AppDatabase(isStoredInMemoryOnly: true)
        db.setSetting(true, for: "enabled")
        db.upsertRuntimeReadiness([], descriptors: Core.Runtime.supportedDescriptors)
        let saves = db.successfulSaveCount
        for _ in 0..<1000 {
            db.setSetting(true, for: "enabled")
            db.upsertRuntimeReadiness([], descriptors: Core.Runtime.supportedDescriptors)
        }
        #expect(db.successfulSaveCount == saves)
        let dictionary = ["b": "two", "a": "one"]
        db.setSetting(dictionary, for: "dictionary")
        let dictionarySaves = db.successfulSaveCount
        for _ in 0..<100 { db.setSetting(dictionary, for: "dictionary") }
        #expect(db.successfulSaveCount == dictionarySaves)
    }

    @Test func diskBackedRepairSurvivesReopenAndPreservesUserMetadata() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("repair.store")
        var database: AppDatabase? = AppDatabase(storeURL: url)
        let scopedID = "apple-container::web"
        let link = VolumeLinkedPath(volumeID: UUID(), volumeSource: "data", volumeTarget: "/data",
                                    hostPath: "/fixture", linkPath: "cache")
        let older = ContainerRecord(scopedID: scopedID, runtimeKindRaw: "apple-container", runtimeID: "web",
                                    displayName: "old", imageReference: "old", statusRaw: "stopped",
                                    documentData: Data([1]), updatedAt: .distantPast)
        older.linkedVolumePathsData = try AppDatabase.encoded([link])
        database?.context.insert(older)
        database?.context.insert(ContainerRecord(scopedID: scopedID, runtimeKindRaw: "apple-container", runtimeID: "web",
                                                  displayName: "new", imageReference: "new", statusRaw: "running"))
        database?.context.insert(PersonalizationRecord(key: scopedID, scopeRaw: "container", valueData: Data([3]), updatedAt: .distantPast))
        database?.context.insert(PersonalizationRecord(key: scopedID, scopeRaw: "container", valueData: Data([4])))
        database?.context.insert(HealthCheckRecord(containerScopedID: scopedID, valueData: Data([5])))
        database?.context.insert(RecipeRecord(name: "retained", documentData: Data([6])))
        #expect(database?.save() == true)
        await database?.historyMaintenanceTask?.value
        database = nil
        let reopened = AppDatabase(storeURL: url)
        let container = try #require(reopened.fetchRequired(ContainerRecord.self).first)
        #expect(try reopened.fetchRequired(ContainerRecord.self).count == 1)
        #expect(container.imageReference == "new")
        #expect(container.documentData == Data([1]))
        #expect(try container.linkedVolumePathsData.map { try JSONDecoder().decode([VolumeLinkedPath].self, from: $0) } == [link])
        #expect(try reopened.fetchRequired(PersonalizationRecord.self).map(\.valueData) == [Data([4])])
        #expect(try reopened.fetchRequired(HealthCheckRecord.self).map(\.valueData) == [Data([5])])
        #expect(try reopened.fetchRequired(RecipeRecord.self).map(\.documentData) == [Data([6])])
        await reopened.historyMaintenanceTask?.value
    }

    @Test func longRunningHistoryRetainsOnlyTheConfiguredWindow() throws {
        let db = AppDatabase(isStoredInMemoryOnly: true)
        let history = HistoryStore(database: db)
        history.retentionDays = 7
        let start = Date()
        let delta = Core.Metrics.StatsDelta(id: "web", cpuCoreFraction: 1,
                                          memoryUsageBytes: 512, memoryLimitBytes: 1024,
                                          netRxBytesPerSec: 0, netTxBytesPerSec: 0,
                                          blockReadBytesPerSec: 0, blockWriteBytesPerSec: 0,
                                          numProcesses: 1)
        for hour in 0..<24 * 10 {
            let date = start.addingTimeInterval(Double(hour) * 3600)
            history.record(.system, message: "hour \(hour)", at: date)
            history.recordMetrics(["one": delta, "two": delta, "three": delta], at: date)
        }
        let events = try db.fetchRequired(EventRecord.self)
        #expect(events.count == 169)
        #expect(try db.fetchRequired(MetricSample.self).count == 3 * 169)
        #expect(events.allSatisfy { $0.timestamp >= start.addingTimeInterval(Double(24 * 10 - 1 - 168) * 3600) })
    }

    @Test func concurrentInventoryPreparationsCannotInsertDuplicateIdentities() async {
        let db = AppDatabase(isStoredInMemoryOnly: true)
        let snapshot = Core.Container.Snapshot.placeholder(id: "web", image: "alpine", runtimeKind: .appleContainer)
        async let first = db.upsertContainers([snapshot, snapshot])
        async let second = db.upsertContainers([snapshot])
        _ = await (first, second)
        #expect(db.fetch(ContainerRecord.self).count == 1)
    }

    @Test func historyMaintenanceDeletesFrameworkTransactionsButKeepsAppData() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let db = AppDatabase(storeURL: directory.appendingPathComponent("test.store"))
        db.setSetting("retained", for: "setting")
        await db.historyMaintenanceTask?.value
        for value in 0..<100 { db.setSetting(value, for: "counter") }
        #expect(try db.context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).count > 0)
        db.maintainTransactionHistory(force: true)
        await db.historyMaintenanceTask?.value
        #expect(try db.context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).isEmpty)
        #expect(db.setting("setting", fallback: "") == "retained")
        #expect(db.maintenanceFailureCode == nil)
        await db.compactDatabase()
        #expect(db.maintenanceFailureCode == nil)
        #expect(db.setting("setting", fallback: "") == "retained")
        #expect(db.canPersist)
    }
}

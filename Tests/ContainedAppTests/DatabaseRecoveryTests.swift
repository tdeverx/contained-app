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

    @Test func failedSaveRollsBackAndCooldownAllowsRecovery() async throws {
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

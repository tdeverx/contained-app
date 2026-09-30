import Foundation
import SwiftData
import ContainedCore
import Observation

@MainActor
@Observable
final class AppDatabase {
    enum Failure: LocalizedError, Equatable {
        case fetch(model: String, detail: String)
        case save(detail: String)
        case encodeSetting(key: String, detail: String)
        case decodeSetting(key: String, detail: String)
        case encodeRecord(type: String, detail: String)
        case decodeRecord(record: String, detail: String)

        var errorDescription: String? {
            switch self {
            case .fetch(let model, let detail):
                return "Unable to fetch \(model): \(detail)"
            case .save(let detail):
                return "Unable to save app database: \(detail)"
            case .encodeSetting(let key, let detail):
                return "Unable to encode app setting \(key): \(detail)"
            case .decodeSetting(let key, let detail):
                return "Unable to decode app setting \(key): \(detail)"
            case .encodeRecord(let type, let detail):
                return "Unable to encode app database value \(type): \(detail)"
            case .decodeRecord(let record, let detail):
                return "Unable to decode app database record \(record): \(detail)"
            }
        }
    }

    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    private(set) var lastFailure: Failure?
    private(set) var retryAfter: Date?
    private(set) var successfulSaveCount = 0
    private(set) var mutationRevision = 0
    let isStoredInMemoryOnly: Bool
    private(set) var lastHistoryMaintenance: Date?
    var maintenanceFailureCode: String?
    var isCompacting = false
    @ObservationIgnored var historyMaintenanceTask: Task<Void, Never>?
    @ObservationIgnored var now: () -> Date = { Date() }
    @ObservationIgnored var failureInjector: ((String) throws -> Void)?
    var canPersist: Bool { !isCompacting && (retryAfter.map { now() >= $0 } ?? true) }
    var containerInventoryPreparationCount = 0
    var containerInventoryEncodedCount = 0

    init(isStoredInMemoryOnly: Bool = false, storeURL: URL? = nil) {
        self.isStoredInMemoryOnly = isStoredInMemoryOnly
        let schema = Schema(AppDatabaseSchemaV1.models)
        do {
            let config = storeURL.map { ModelConfiguration("ContainedAppDatabase", schema: schema, url: $0,
                                                           cloudKitDatabase: .none) }
                ?? ModelConfiguration("ContainedAppDatabase",
                                            schema: schema,
                                            isStoredInMemoryOnly: isStoredInMemoryOnly,
                                            cloudKitDatabase: .none)
            container = try ModelContainer(for: schema, configurations: config)
            container.mainContext.autosaveEnabled = false
        } catch {
            fatalError("Unable to create app database: \(error)")
        }
        repairDuplicateRecords()
    }

    /// Required reads never turn an unavailable store into an empty inventory.
    func fetchRequired<T: PersistentModel>(_ model: T.Type) throws -> [T] {
        guard retryAfter.map({ now() >= $0 }) ?? true else {
            throw lastFailure ?? .save(detail: "Persistence is paused")
        }
        do {
            try failureInjector?("fetch:\(String(describing: T.self))")
            return try context.fetch(FetchDescriptor<T>())
        } catch {
            let failure = Failure.fetch(model: String(describing: T.self), detail: Self.safeDetail(error))
            recordFailure(failure)
            throw failure
        }
    }

    func fetch<T: PersistentModel>(_ model: T.Type) -> [T] {
        (try? fetchRequired(model)) ?? []
    }

    func performMutation(_ operation: () throws -> Void) {
        guard canPersist else { return }
        do { try operation() }
        catch {
            context.rollback()
            if let failure = error as? Failure { recordFailure(failure) }
            else { recordFailure(.save(detail: Self.safeDetail(error))) }
        }
    }

    @discardableResult
    func save() -> Bool {
        guard canPersist else { context.rollback(); return false }
        guard context.hasChanges else { return true }
        do {
            try failureInjector?("save")
            try context.save()
            successfulSaveCount += 1
            mutationRevision &+= 1
            lastFailure = nil
            retryAfter = nil
            maintainTransactionHistory()
            return true
        } catch {
            context.rollback()
            recordFailure(.save(detail: Self.safeDetail(error)))
            return false
        }
    }

    nonisolated static func safeDetail(_ error: Error) -> String {
        let value = error as NSError
        return "\(value.domain) (\(value.code))"
    }

    nonisolated static func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(value)
    }

    /// Explicit retry bypasses the cooldown, verifies reads and repairs legacy duplicates.
    @discardableResult
    func retryPersistence() -> Bool {
        retryAfter = nil
        repairDuplicateRecords()
        guard canPersist else { return false }
        do {
            _ = try fetchRequired(AppSettingRecord.self)
            lastFailure = nil
            return true
        } catch { return false }
    }

    func setting<T: Codable>(_ key: String, fallback: T) -> T {
        guard let record = fetch(AppSettingRecord.self).first(where: { $0.key == key }) else {
            return fallback
        }
        do {
            return try JSONDecoder().decode(T.self, from: record.valueData)
        } catch {
            recordFailure(.decodeSetting(key: key, detail: AppDatabase.safeDetail(error)))
            return fallback
        }
    }

    func setSetting<T: Codable>(_ value: T, for key: String) {
        guard canPersist else { return }
        let data: Data
        do {
            data = try Self.encoded(value)
        } catch {
            recordFailure(.encodeSetting(key: key, detail: AppDatabase.safeDetail(error)))
            return
        }
        guard let records = try? fetchRequired(AppSettingRecord.self) else { return }
        if let record = records.first(where: { $0.key == key }) {
            guard record.valueData != data else { return }
            record.valueData = data
            record.updatedAt = Date()
        } else {
            context.insert(AppSettingRecord(key: key, valueData: data))
        }
        save()
    }

    func recordFailure(_ failure: Failure) {
        lastFailure = failure
        switch failure {
        case .fetch, .save:
            context.rollback()
            retryAfter = now().addingTimeInterval(60)
        default: break
        }
    }

    func maintainTransactionHistory(force: Bool = false) {
        guard !isStoredInMemoryOnly, canPersist, historyMaintenanceTask == nil else { return }
        let date = now()
        if !force, let lastHistoryMaintenance, date.timeIntervalSince(lastHistoryMaintenance) < 3600 { return }
        let container = container
        historyMaintenanceTask = Task {
            let failure = await Task.detached(priority: .utility) {
                let maintainer = DatabaseHistoryMaintainer(modelContainer: container)
                return await maintainer.purge()
            }.value
            maintenanceFailureCode = failure
            lastHistoryMaintenance = date
            historyMaintenanceTask = nil
        }
    }

    var allocatedDatabaseBytes: Int64 {
        guard !isStoredInMemoryOnly, let url = container.configurations.first?.url else { return 0 }
        return ["", "-wal", "-shm"].reduce(0) { total, suffix in
            let file = URL(fileURLWithPath: url.path + suffix)
            let values = try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
            return total + Int64(values?.totalFileAllocatedSize ?? 0)
        }
    }

    func deleteSetting(_ key: String) {
        guard canPersist else { return }
        guard let records = try? fetchRequired(AppSettingRecord.self),
              let record = records.first(where: { $0.key == key }) else { return }
        context.delete(record)
        save()
    }

    func runtimeRecord(for kind: Core.Runtime.Kind) -> RuntimeRecord? {
        guard canPersist else { return nil }
        let raw = kind.rawValue
        guard let records = try? fetchRequired(RuntimeRecord.self) else { return nil }
        if let record = records.first(where: { $0.runtimeKindRaw == raw }) {
            return record
        }
        let record = RuntimeRecord(runtimeKindRaw: raw)
        context.insert(record)
        guard save() else { return nil }
        return record
    }

    func runtimePathOverride(for kind: Core.Runtime.Kind) -> String {
        let raw = kind.rawValue
        return fetch(RuntimeRecord.self).first(where: { $0.runtimeKindRaw == raw })?.cliPathOverride ?? ""
    }

    func setRuntimePathOverride(_ path: String, for kind: Core.Runtime.Kind) {
        guard let record = runtimeRecord(for: kind), record.cliPathOverride != path else { return }
        record.cliPathOverride = path
        record.updatedAt()
        save()
    }

    func upsertRuntimeReadiness(_ readiness: [Core.RuntimeReadiness],
                                descriptors: [Core.Runtime.Descriptor]) {
        guard canPersist else { return }
        guard let records = try? fetchRequired(RuntimeRecord.self) else { return }
        let now = Date()
        let readyByKind = Dictionary(uniqueKeysWithValues: readiness.map { ($0.kind, $0) })
        for descriptor in descriptors {
            let record = records.first { $0.runtimeKindRaw == descriptor.kind.rawValue }
                ?? RuntimeRecord(runtimeKindRaw: descriptor.kind.rawValue)
            let state = readyByKind[descriptor.kind]
            let available = state?.state == .ready
            let raw = state?.state.rawValue ?? "unavailable"
            guard record.modelContext == nil || record.isAvailable != available ||
                    record.readinessRaw != raw || record.lastError != state?.message else { continue }
            if record.modelContext == nil { context.insert(record) }
            record.isAvailable = available
            record.readinessRaw = state?.state.rawValue ?? "unavailable"
            record.lastCheckedAt = now
            record.lastError = state?.message
        }
        save()
    }
}

private extension RuntimeRecord {
    func updatedAt() {
        lastCheckedAt = Date()
    }
}

private extension AppModel.Bootstrap {
    var rawDatabaseValue: String {
        switch self {
        case .checking: return "checking"
        case .cliMissing: return "cliMissing"
        case .unsupported: return "unsupported"
        case .serviceStopped: return "endpointUnavailable"
        case .ready: return "ready"
        }
    }
}

enum AppDatabaseSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [
            AppSettingRecord.self,
            RuntimeRecord.self,
            ContainerRecord.self,
            RecipeRecord.self,
            ImageRecord.self,
            ImageTagRecord.self,
            VolumeRecord.self,
            NetworkRecord.self,
            PersonalizationRecord.self,
            HealthCheckRecord.self,
            EventRecord.self,
            MetricSample.self,
        ]
    }
}

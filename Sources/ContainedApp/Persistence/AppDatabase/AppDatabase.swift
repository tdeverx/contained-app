import Foundation
import SwiftData
import ContainedCore

@MainActor
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

    init(isStoredInMemoryOnly: Bool = false) {
        let schema = Schema(AppDatabaseSchemaV1.models)
        do {
            let config = ModelConfiguration("ContainedAppDatabase",
                                            schema: schema,
                                            isStoredInMemoryOnly: isStoredInMemoryOnly)
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Unable to create app database: \(error)")
        }
    }

    func fetch<T: PersistentModel>(_ model: T.Type) -> [T] {
        do {
            return try context.fetch(FetchDescriptor<T>())
        } catch {
            recordFailure(.fetch(model: String(describing: T.self), detail: String(describing: error)))
            return []
        }
    }

    func save() {
        do {
            try context.save()
        } catch {
            recordFailure(.save(detail: String(describing: error)))
        }
    }

    func setting<T: Codable>(_ key: String, fallback: T) -> T {
        guard let record = fetch(AppSettingRecord.self).first(where: { $0.key == key }) else {
            return fallback
        }
        do {
            return try JSONDecoder().decode(T.self, from: record.valueData)
        } catch {
            recordFailure(.decodeSetting(key: key, detail: String(describing: error)))
            return fallback
        }
    }

    func setSetting<T: Codable>(_ value: T, for key: String) {
        let data: Data
        do {
            data = try JSONEncoder().encode(value)
        } catch {
            recordFailure(.encodeSetting(key: key, detail: String(describing: error)))
            return
        }
        if let record = fetch(AppSettingRecord.self).first(where: { $0.key == key }) {
            record.valueData = data
            record.updatedAt = Date()
        } else {
            context.insert(AppSettingRecord(key: key, valueData: data))
        }
        save()
    }

    func recordFailure(_ failure: Failure) {
        lastFailure = failure
    }

    func deleteSetting(_ key: String) {
        guard let record = fetch(AppSettingRecord.self).first(where: { $0.key == key }) else { return }
        context.delete(record)
        save()
    }

    func runtimeRecord(for kind: Core.Runtime.Kind) -> RuntimeRecord {
        let raw = kind.rawValue
        if let record = fetch(RuntimeRecord.self).first(where: { $0.runtimeKindRaw == raw }) {
            return record
        }
        let record = RuntimeRecord(runtimeKindRaw: raw)
        context.insert(record)
        return record
    }

    func runtimePathOverride(for kind: Core.Runtime.Kind) -> String {
        let raw = kind.rawValue
        return fetch(RuntimeRecord.self).first(where: { $0.runtimeKindRaw == raw })?.cliPathOverride ?? ""
    }

    func setRuntimePathOverride(_ path: String, for kind: Core.Runtime.Kind) {
        let record = runtimeRecord(for: kind)
        record.cliPathOverride = path
        record.updatedAt()
        save()
    }

    func upsertRuntimeReadiness(_ readiness: [Core.RuntimeReadiness],
                                descriptors: [Core.Runtime.Descriptor]) {
        let now = Date()
        let readyByKind = Dictionary(uniqueKeysWithValues: readiness.map { ($0.kind, $0) })
        for descriptor in descriptors {
            let record = runtimeRecord(for: descriptor.kind)
            let state = readyByKind[descriptor.kind]
            record.isAvailable = state?.state == .ready
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

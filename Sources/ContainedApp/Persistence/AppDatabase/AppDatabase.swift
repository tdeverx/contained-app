import Foundation
import SwiftData
import ContainedCore

@MainActor
final class AppDatabase {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

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
            fatalError("Unable to fetch \(T.self): \(error)")
        }
    }

    func save() {
        do {
            try context.save()
        } catch {
            fatalError("Unable to save app database: \(error)")
        }
    }

    func setting<T: Codable>(_ key: String, fallback: T) -> T {
        guard let record = fetch(AppSettingRecord.self).first(where: { $0.key == key }) else {
            return fallback
        }
        do {
            return try JSONDecoder().decode(T.self, from: record.valueData)
        } catch {
            fatalError("Unable to decode app setting \(key): \(error)")
        }
    }

    func setSetting<T: Codable>(_ value: T, for key: String) {
        let data: Data
        do {
            data = try JSONEncoder().encode(value)
        } catch {
            fatalError("Unable to encode app setting \(key): \(error)")
        }
        if let record = fetch(AppSettingRecord.self).first(where: { $0.key == key }) {
            record.valueData = data
            record.updatedAt = Date()
        } else {
            context.insert(AppSettingRecord(key: key, valueData: data))
        }
        save()
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

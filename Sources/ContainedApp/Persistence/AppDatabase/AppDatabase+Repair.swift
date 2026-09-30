import Foundation
import SwiftData
import ContainedCore

extension AppDatabase {
    /// Read every prerequisite before touching a legacy store. Opaque payloads are carried
    /// forward independently of the newest runtime snapshot.
    func repairDuplicateRecords() {
        performMutation {
            let settings = try fetchRequired(AppSettingRecord.self)
            let runtimes = try fetchRequired(RuntimeRecord.self)
            let containers = try fetchRequired(ContainerRecord.self)
            let images = try fetchRequired(ImageRecord.self)
            let tags = try fetchRequired(ImageTagRecord.self)
            let volumes = try fetchRequired(VolumeRecord.self)
            let networks = try fetchRequired(NetworkRecord.self)
            let styles = try fetchRequired(PersonalizationRecord.self)
            let checks = try fetchRequired(HealthCheckRecord.self)
            let recipes = try fetchRequired(RecipeRecord.self)

            try consolidate(settings, key: { $0.key }, date: { $0.updatedAt })
            consolidate(runtimes, key: { $0.runtimeKindRaw }, date: { $0.lastCheckedAt ?? .distantPast }) { keep, other in
                if keep.cliPathOverride.isEmpty { keep.cliPathOverride = other.cliPathOverride }
            }
            try consolidate(containers, key: { $0.scopedID }, date: { $0.updatedAt }) { keep, other in
                keep.documentData = keep.documentData ?? other.documentData
                keep.snapshotData = keep.snapshotData ?? other.snapshotData
                if let data = other.runtimeProjectionsData {
                    var projections = try keep.runtimeProjectionsData.map {
                        try JSONDecoder().decode([String: Core.Schema.Document].self, from: $0)
                    } ?? [:]
                    let older = try JSONDecoder().decode([String: Core.Schema.Document].self, from: data)
                    projections.merge(older) { newest, _ in newest }
                    keep.runtimeProjectionsData = try JSONEncoder().encode(projections)
                }
                if let data = other.linkedVolumePathsData {
                    var links = try keep.linkedVolumePathsData.map {
                        try JSONDecoder().decode([VolumeLinkedPath].self, from: $0)
                    } ?? []
                    let older = try JSONDecoder().decode([VolumeLinkedPath].self, from: data)
                    for link in older where !links.contains(link) { links.append(link) }
                    keep.linkedVolumePathsData = try JSONEncoder().encode(links)
                }
                if keep.migrationStateRaw == "none", other.migrationStateRaw != "none" {
                    keep.migrationStateRaw = other.migrationStateRaw
                    keep.isHiddenDuringMigration = other.isHiddenDuringMigration
                }
            }
            consolidate(images, key: { $0.identity }, date: { $0.updatedAt }) { keep, other in
                keep.personalizationData = keep.personalizationData ?? other.personalizationData
                keep.registryMetadataData = keep.registryMetadataData ?? other.registryMetadataData
                if (other.lastCheckedAt ?? .distantPast) > (keep.lastCheckedAt ?? .distantPast) {
                    keep.updateStatusData = other.updateStatusData
                    keep.lastCheckedAt = other.lastCheckedAt
                }
            }
            consolidate(tags, key: { $0.scopedID }, date: { $0.updatedAt }) { keep, other in
                if (other.lastCheckedAt ?? .distantPast) > (keep.lastCheckedAt ?? .distantPast) {
                    keep.updateStatusData = other.updateStatusData
                    keep.lastCheckedAt = other.lastCheckedAt
                }
            }
            consolidate(volumes, key: { $0.scopedID }, date: { $0.updatedAt }) { keep, other in
                keep.personalizationData = keep.personalizationData ?? other.personalizationData
            }
            try consolidate(networks, key: { $0.scopedID }, date: { $0.updatedAt })
            try consolidate(styles, key: { $0.scopeRaw + "\u{1F}" + $0.key }, date: { $0.updatedAt })
            try consolidate(checks, key: { $0.containerScopedID }, date: { $0.updatedAt })
            consolidate(recipes, key: { $0.id }, date: { $0.updatedAt }) { keep, other in
                keep.personalizationData = keep.personalizationData ?? other.personalizationData
                keep.healthCheckData = keep.healthCheckData ?? other.healthCheckData
            }
            save()
        }
    }

    private func consolidate<T: PersistentModel>(_ records: [T],
                                                 key: (T) -> String,
                                                 date: (T) -> Date,
                                                 merge: (T, T) throws -> Void = { _, _ in }) rethrows {
        for group in Dictionary(grouping: records, by: key).values where group.count > 1 {
            let ordered = group.sorted {
                if date($0) != date($1) { return date($0) > date($1) }
                return String(describing: $0.persistentModelID) < String(describing: $1.persistentModelID)
            }
            let keep = ordered[0]
            for duplicate in ordered.dropFirst() {
                try merge(keep, duplicate)
                context.delete(duplicate)
            }
        }
    }
}

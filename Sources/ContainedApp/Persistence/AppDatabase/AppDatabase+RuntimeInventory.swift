import Foundation
import ContainedCore

struct InventoryPersistenceResult: Equatable, Sendable {
    var inserted = 0
    var updated = 0
    var missing = 0
    var encoded = 0
    var unchanged = 0
    var succeeded = true

    var persisted: Int { inserted + updated + missing }
}

extension AppDatabase {
    func upsertContainers(_ snapshots: [Core.Container.Snapshot],
                          observedAt: Date = Date()) async -> InventoryPersistenceResult {
        let interval = PerformanceSignposts.inventory.beginInterval("InventoryPersistence")
        defer { PerformanceSignposts.inventory.endInterval("InventoryPersistence", interval) }
        containerInventoryPreparationCount &+= 1
        let snapshots = Array(Dictionary(snapshots.map { ($0.scopedID, $0) },
                                         uniquingKeysWith: { _, latest in latest }).values)
        let seen = Set(snapshots.map(\.scopedID))
        guard canPersist else { return InventoryPersistenceResult(succeeded: false) }
        let records: [ContainerRecord]
        let personalizedIDs: Set<String>
        let healthCheckedIDs: Set<String>
        do {
            records = try fetchRequired(ContainerRecord.self)
            personalizedIDs = Set(try fetchRequired(PersonalizationRecord.self).map(\.key))
            healthCheckedIDs = Set(try fetchRequired(HealthCheckRecord.self).map(\.containerScopedID))
        } catch { return InventoryPersistenceResult(succeeded: false) }
        let revision = mutationRevision
        let recordsByID = Dictionary(records.map { ($0.scopedID, $0) }, uniquingKeysWith: { first, _ in first })
        let existing = Dictionary(uniqueKeysWithValues: recordsByID.map { id, record in
            (id, ExistingContainerProjection(record))
        })
        let preparation = await Task.detached(priority: .utility) {
            ContainerInventoryPreparer.prepare(snapshots: snapshots, existing: existing)
        }.value
        guard canPersist, revision == mutationRevision else {
            return InventoryPersistenceResult(succeeded: false)
        }
        var result = preparation.result
        containerInventoryEncodedCount &+= result.encoded
        var changed = false
        for failure in preparation.failures {
            recordFailure(.encodeRecord(type: failure.type, detail: failure.detail))
            result.succeeded = false
        }
        for item in preparation.items {
            let snapshot = item.snapshot
            if let record = recordsByID[snapshot.scopedID] {
                record.runtimeKindRaw = snapshot.runtimeKind.rawValue
                record.runtimeID = snapshot.id
                record.displayName = snapshot.displayName
                record.imageReference = snapshot.image
                record.statusRaw = snapshot.state.rawValue
                // A partially-created replacement/rollback is not the saved original recipe.
                if record.migrationStateRaw != "recreating" && record.migrationStateRaw != "recreateFailed" {
                    if let documentData = item.documentData { record.documentData = documentData }
                    if let snapshotData = item.snapshotData { record.snapshotData = snapshotData }
                }
                record.isMissing = false
                record.missingSince = nil
                record.lastSeenAt = observedAt
                record.updatedAt = observedAt
                changed = true
            } else {
                context.insert(ContainerRecord(scopedID: snapshot.scopedID,
                                               runtimeKindRaw: snapshot.runtimeKind.rawValue,
                                               runtimeID: snapshot.id,
                                               displayName: snapshot.displayName,
                                               imageReference: snapshot.image,
                                               statusRaw: snapshot.state.rawValue,
                                               documentData: item.documentData,
                                               snapshotData: item.snapshotData,
                                               lastSeenAt: observedAt,
                                               updatedAt: observedAt))
                changed = true
            }
        }
        for record in records where !seen.contains(record.scopedID) && !record.isMissing {
            if shouldRetainMissingContainer(record,
                                            personalizedIDs: personalizedIDs,
                                            healthCheckedIDs: healthCheckedIDs) {
                record.isMissing = true
                record.missingSince = observedAt
                record.updatedAt = observedAt
            } else {
                context.delete(record)
            }
            changed = true
            result.missing += 1
        }
        if changed, !save() { result.succeeded = false }
        return result
    }

    func upsertImages(_ images: [Core.Image.Resource], observedAt: Date = Date()) {
        performMutation {
            let groups = Core.Image.LocalTagGroup.groups(for: images)
            let imageRecords = try fetchRequired(ImageRecord.self)
            var tagRecords = try fetchRequired(ImageTagRecord.self)
            var changed = consolidateDuplicateImageTags(&tagRecords)
            let imagesByIdentity = Dictionary(imageRecords.map { ($0.identity, $0) }, uniquingKeysWith: { first, _ in first })
            let tagsByID = Dictionary(tagRecords.map { ($0.scopedID, $0) }, uniquingKeysWith: { first, _ in first })
            let groupIdentityByTagID = Dictionary(uniqueKeysWithValues: groups.flatMap { group in
                group.tags.map { ($0.id, group.id) }
            })
            var seenTags: Set<String> = []
            for group in groups {
                let identity = group.id
                if let record = imagesByIdentity[identity] {
                    guard record.primaryReference != group.primaryReference || record.digest != group.digest else { continue }
                    record.primaryReference = group.primaryReference
                    record.digest = group.digest
                    record.updatedAt = observedAt
                    changed = true
                } else {
                    context.insert(ImageRecord(identity: identity,
                                               primaryReference: group.primaryReference,
                                               digest: group.digest,
                                               updatedAt: observedAt))
                    changed = true
                }
            }
            for image in images {
                let tagID = image.runtimeKind.scopedID(for: Core.Registry.ImageReference.normalizedKey(image.reference))
                let identity = groupIdentityByTagID[tagID]
                    ?? Core.Registry.ImageReference.normalizedRepositoryKey(image.reference)
                guard seenTags.insert(tagID).inserted else { continue }
                let resourceData = encode(image)
                if let tag = tagsByID[tagID] {
                    guard tag.imageIdentity != identity ||
                            tag.reference != image.reference ||
                            tag.runtimeKindRaw != image.runtimeKind.rawValue ||
                            tag.runtimeImageID != image.id ||
                            tag.digest != image.digest ||
                            tag.resourceData != resourceData ||
                            !tag.isLocal || tag.isMissing || tag.missingSince != nil
                    else { continue }
                    tag.imageIdentity = identity
                    tag.reference = image.reference
                    tag.runtimeKindRaw = image.runtimeKind.rawValue
                    tag.runtimeImageID = image.id
                    tag.digest = image.digest
                    tag.resourceData = resourceData
                    tag.isLocal = true
                    tag.isMissing = false
                    tag.missingSince = nil
                    tag.lastSeenAt = observedAt
                    tag.updatedAt = observedAt
                    changed = true
                } else {
                    context.insert(ImageTagRecord(scopedID: tagID,
                                                  imageIdentity: identity,
                                                  reference: image.reference,
                                                  runtimeKindRaw: image.runtimeKind.rawValue,
                                                  runtimeImageID: image.id,
                                                  digest: image.digest,
                                                  resourceData: resourceData,
                                                  lastSeenAt: observedAt,
                                                  updatedAt: observedAt))
                    changed = true
                }
            }
            for tag in tagRecords where !seenTags.contains(tag.scopedID) && !tag.isMissing {
                context.delete(tag)
                changed = true
            }
            if changed { save() }
        }
    }

    func updateImageStatuses(_ statuses: [String: Core.Image.UpdateStatus], observedAt: Date = Date()) {
        performMutation {
            let seen = Set(statuses.keys)
            let imageRecords = try fetchRequired(ImageRecord.self)
            var tagRecords = try fetchRequired(ImageTagRecord.self)
            var changed = consolidateDuplicateImageTags(&tagRecords)
            let imagesByIdentity = Dictionary(imageRecords.map { ($0.identity, $0) }, uniquingKeysWith: { first, _ in first })
            let tagsByID = Dictionary(tagRecords.map { ($0.scopedID, $0) }, uniquingKeysWith: { first, _ in first })
            for (key, status) in statuses {
                guard status.state != .checking else { continue }
                let data = encode(status)
                if let scoped = Core.Runtime.Kind.parseScopedID(key) {
                    if let tag = tagsByID[key] {
                        guard tag.updateStatusData != data else { continue }
                        tag.updateStatusData = data
                        tag.lastCheckedAt = observedAt
                        tag.updatedAt = observedAt
                        changed = true
                    } else {
                        context.insert(ImageTagRecord(scopedID: key,
                                                      imageIdentity: scoped.id,
                                                      reference: scoped.id,
                                                      runtimeKindRaw: scoped.kind.rawValue,
                                                      runtimeImageID: scoped.id,
                                                      updateStatusData: data,
                                                      isLocal: false,
                                                      lastCheckedAt: observedAt,
                                                      updatedAt: observedAt))
                        changed = true
                    }
                } else if let image = imagesByIdentity[key]
                            ?? imageRecords.first(where: { Core.Registry.ImageReference.normalizedKey($0.primaryReference) == key }) {
                    guard image.updateStatusData != data else { continue }
                    image.updateStatusData = data
                    image.lastCheckedAt = observedAt
                    image.updatedAt = observedAt
                    changed = true
                } else {
                    context.insert(ImageRecord(identity: key,
                                               primaryReference: key,
                                               updateStatusData: data,
                                               lastCheckedAt: observedAt,
                                               updatedAt: observedAt))
                    changed = true
                }
            }
            for image in imageRecords where image.updateStatusData != nil && !seen.contains(image.identity) && !seen.contains(Core.Registry.ImageReference.normalizedKey(image.primaryReference)) {
                image.updateStatusData = nil
                image.updatedAt = observedAt
                changed = true
            }
            for tag in tagRecords where tag.updateStatusData != nil && !seen.contains(tag.scopedID) {
                tag.updateStatusData = nil
                tag.updatedAt = observedAt
                changed = true
            }
            if changed { save() }
        }
    }

    func imageStatusesSnapshot() -> [String: Core.Image.UpdateStatus] {
        var snapshot: [String: Core.Image.UpdateStatus] = [:]
        for record in fetch(ImageRecord.self) {
            guard let data = record.updateStatusData else { continue }
            let status: Core.Image.UpdateStatus
            do {
                status = try JSONDecoder().decode(Core.Image.UpdateStatus.self, from: data)
            } catch {
                recordFailure(.decodeRecord(record: "image update status \(record.identity)",
                                            detail: AppDatabase.safeDetail(error)))
                continue
            }
            let value = status.state == .checking ? Core.Image.UpdateStatus() : status
            snapshot[record.identity] = value
            snapshot[Core.Registry.ImageReference.normalizedKey(record.primaryReference)] = value
        }
        var tagRecords = fetch(ImageTagRecord.self)
        if consolidateDuplicateImageTags(&tagRecords) { save() }
        for tag in tagRecords {
            guard let data = tag.updateStatusData else { continue }
            let status: Core.Image.UpdateStatus
            do {
                status = try JSONDecoder().decode(Core.Image.UpdateStatus.self, from: data)
            } catch {
                recordFailure(.decodeRecord(record: "image tag update status \(tag.scopedID)",
                                            detail: AppDatabase.safeDetail(error)))
                continue
            }
            snapshot[tag.scopedID] = status.state == .checking ? Core.Image.UpdateStatus() : status
        }
        return snapshot
    }

    /// Older inventories could insert the same runtime/tag more than once when the runtime returned
    /// repeated entries in a single response. Keep the newest record as the metadata source, carry
    /// over the most recently checked status independently, and remove the redundant rows.
    private func consolidateDuplicateImageTags(_ records: inout [ImageTagRecord]) -> Bool {
        var changed = false
        var consolidated: [ImageTagRecord] = []
        for group in Dictionary(grouping: records, by: \.scopedID).values {
            guard let canonical = group.max(by: { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
                return lhs.runtimeImageID < rhs.runtimeImageID
            }) else { continue }
            if let statusSource = group
                .filter({ $0.updateStatusData != nil })
                .max(by: { lhs, rhs in
                    let left = lhs.lastCheckedAt ?? lhs.updatedAt
                    let right = rhs.lastCheckedAt ?? rhs.updatedAt
                    if left != right { return left < right }
                    return lhs.runtimeImageID < rhs.runtimeImageID
                }), statusSource !== canonical {
                canonical.updateStatusData = statusSource.updateStatusData
                canonical.lastCheckedAt = statusSource.lastCheckedAt
                changed = true
            }
            for duplicate in group where duplicate !== canonical {
                context.delete(duplicate)
                changed = true
            }
            consolidated.append(canonical)
        }
        records = consolidated
        return changed
    }

    func hiddenContainerScopedIDs() -> Set<String> {
        Set(fetch(ContainerRecord.self).filter(\.isHiddenDuringMigration).map(\.scopedID))
    }

    func linkedVolumePaths(for scopedID: String) -> [VolumeLinkedPath] {
        guard let data = fetch(ContainerRecord.self).first(where: { $0.scopedID == scopedID })?.linkedVolumePathsData else {
            return []
        }
        do {
            return try JSONDecoder().decode([VolumeLinkedPath].self, from: data)
        } catch {
            recordFailure(.decodeRecord(record: "linked volume paths \(scopedID)",
                                        detail: AppDatabase.safeDetail(error)))
            return []
        }
    }

    func setLinkedVolumePaths(_ links: [VolumeLinkedPath], for scopedID: String, observedAt: Date = Date()) {
        performMutation {
            guard let record = try fetchRequired(ContainerRecord.self).first(where: { $0.scopedID == scopedID }) else { return }
            let data = links.isEmpty ? nil : encode(links)
            guard record.linkedVolumePathsData != data else { return }
            record.linkedVolumePathsData = data
            record.updatedAt = observedAt
            save()
        }
    }

    func upsertVolumes(_ volumes: [Core.Volume.Resource], observedAt: Date = Date()) {
        performMutation {
            let volumes = Array(Dictionary(volumes.map { ($0.scopedID, $0) },
                                             uniquingKeysWith: { _, latest in latest }).values)
            let seen = Set(volumes.map(\.scopedID))
            let records = try fetchRequired(VolumeRecord.self)
            let recordsByID = Dictionary(records.map { ($0.scopedID, $0) }, uniquingKeysWith: { first, _ in first })
            var changed = false
            for volume in volumes {
                let resourceData = encode(volume)
                if let record = recordsByID[volume.scopedID] {
                    guard record.runtimeKindRaw != volume.runtimeKind.rawValue ||
                            record.name != volume.name || record.resourceData != resourceData ||
                            record.isMissing || record.missingSince != nil
                    else { continue }
                    record.runtimeKindRaw = volume.runtimeKind.rawValue
                    record.name = volume.name
                    record.resourceData = resourceData
                    record.isMissing = false
                    record.missingSince = nil
                    record.lastSeenAt = observedAt
                    record.updatedAt = observedAt
                    changed = true
                } else {
                    context.insert(VolumeRecord(scopedID: volume.scopedID,
                                                runtimeKindRaw: volume.runtimeKind.rawValue,
                                                name: volume.name,
                                                resourceData: resourceData,
                                                lastSeenAt: observedAt,
                                                updatedAt: observedAt))
                    changed = true
                }
            }
            for record in records where !seen.contains(record.scopedID) && !record.isMissing {
                if record.personalizationData != nil {
                    record.isMissing = true
                    record.missingSince = observedAt
                    record.updatedAt = observedAt
                } else {
                    context.delete(record)
                }
                changed = true
            }
            if changed { save() }
        }
    }

    func upsertNetworks(_ networks: [Core.Network.Resource], observedAt: Date = Date()) {
        performMutation {
            let networks = Array(Dictionary(networks.map { ($0.scopedID, $0) },
                                             uniquingKeysWith: { _, latest in latest }).values)
            let seen = Set(networks.map(\.scopedID))
            let records = try fetchRequired(NetworkRecord.self)
            let recordsByID = Dictionary(records.map { ($0.scopedID, $0) }, uniquingKeysWith: { first, _ in first })
            var changed = false
            for network in networks {
                let resourceData = encode(network)
                if let record = recordsByID[network.scopedID] {
                    guard record.runtimeKindRaw != network.runtimeKind.rawValue ||
                            record.name != network.name || record.resourceData != resourceData ||
                            record.isMissing || record.missingSince != nil
                    else { continue }
                    record.runtimeKindRaw = network.runtimeKind.rawValue
                    record.name = network.name
                    record.resourceData = resourceData
                    record.isMissing = false
                    record.missingSince = nil
                    record.lastSeenAt = observedAt
                    record.updatedAt = observedAt
                    changed = true
                } else {
                    context.insert(NetworkRecord(scopedID: network.scopedID,
                                                 runtimeKindRaw: network.runtimeKind.rawValue,
                                                 name: network.name,
                                                 resourceData: resourceData,
                                                 lastSeenAt: observedAt,
                                                 updatedAt: observedAt))
                    changed = true
                }
            }
            for record in records where !seen.contains(record.scopedID) && !record.isMissing {
                context.delete(record)
                changed = true
            }
            if changed { save() }
        }
    }

    func markContainerMigrationStarted(source: Core.Container.Snapshot,
                                       targetRuntimeKind: Core.Runtime.Kind,
                                       sourceDocument: Core.Schema.Document,
                                       observedAt: Date = Date()) {
        performMutation {
            let record: ContainerRecord
            if let existing = try fetchRequired(ContainerRecord.self).first(where: { $0.scopedID == source.scopedID }) {
                record = existing
            } else {
                record = ContainerRecord(scopedID: source.scopedID,
                                         runtimeKindRaw: source.runtimeKind.rawValue,
                                         runtimeID: source.id,
                                         displayName: source.displayName,
                                         imageReference: source.image,
                                         statusRaw: source.state.rawValue)
                context.insert(record)
            }

            var projections = runtimeProjections(from: record)
            projections[source.runtimeKind.rawValue] = sourceDocument
            record.runtimeKindRaw = source.runtimeKind.rawValue
            record.runtimeID = source.id
            record.displayName = source.displayName
            record.imageReference = source.image
            record.statusRaw = source.state.rawValue
            record.documentData = encode(sourceDocument)
            record.snapshotData = encode(source)
            record.runtimeProjectionsData = encode(projections)
            record.isHiddenDuringMigration = true
            record.migrationStateRaw = "migrating:\(source.runtimeKind.rawValue):\(targetRuntimeKind.rawValue)"
            record.isMissing = false
            record.lastSeenAt = observedAt
            record.updatedAt = observedAt
            save()
        }
    }

    /// Saves the live recipe before recreate deletes the runtime object. Reuse the projection
    /// payload so a failed restoration remains recoverable without adding another persistence model.
    @discardableResult
    func markContainerRecreateStarted(source: Core.Container.Snapshot,
                                      sourceDocument: Core.Schema.Document,
                                      observedAt: Date = Date()) -> Bool {
        var saved = false
        performMutation {
            let documentData = try Self.encoded(sourceDocument)
            let snapshotData = try Self.encoded(source)
            let record: ContainerRecord
            if let existing = try fetchRequired(ContainerRecord.self).first(where: { $0.scopedID == source.scopedID }) {
                record = existing
            } else {
                record = ContainerRecord(scopedID: source.scopedID,
                                         runtimeKindRaw: source.runtimeKind.rawValue,
                                         runtimeID: source.id,
                                         displayName: source.displayName,
                                         imageReference: source.image,
                                         statusRaw: source.state.rawValue)
                context.insert(record)
            }

            var projections = runtimeProjections(from: record)
            projections[source.runtimeKind.rawValue] = sourceDocument
            record.documentData = documentData
            record.snapshotData = snapshotData
            record.runtimeProjectionsData = try Self.encoded(projections)
            record.migrationStateRaw = "recreating"
            record.isMissing = false
            record.missingSince = nil
            record.updatedAt = observedAt
            saved = save()
        }
        return saved
    }

    struct ContainerRecreationRecovery: Identifiable {
        var id: String { snapshot.scopedID }
        let snapshot: Core.Container.Snapshot
        let document: Core.Schema.Document
    }

    func containerRecreationRecoveries() -> [ContainerRecreationRecovery] {
        _ = mutationRevision
        return fetch(ContainerRecord.self).filter {
            $0.migrationStateRaw == "recreating" || $0.migrationStateRaw == "recreateFailed"
        }.compactMap { record in
            do {
                guard let data = record.snapshotData else { throw Failure.decodeRecord(record: record.scopedID, detail: "Missing original snapshot") }
                let snapshot = try JSONDecoder().decode(Core.Container.Snapshot.self, from: data)
                return ContainerRecreationRecovery(snapshot: snapshot, document: .containerRecovery(from: snapshot.configuration))
            } catch {
                recordFailure(.decodeRecord(record: "recreation recovery \(record.scopedID)", detail: Self.safeDetail(error)))
                return nil
            }
        }.sorted { $0.id < $1.id }
    }

    @discardableResult
    func completeContainerRecreate(sourceScopedID: String,
                                   replacementScopedID: String,
                                   observedAt: Date = Date()) -> Bool {
        var saved = false
        performMutation {
            guard let source = try fetchRequired(ContainerRecord.self).first(where: { $0.scopedID == sourceScopedID }) else { return }
            if sourceScopedID == replacementScopedID {
                source.migrationStateRaw = "none"
                source.updatedAt = observedAt
            } else {
                context.delete(source)
            }
            saved = save()
        }
        return saved
    }

    func markContainerRecreateFailed(scopedID: String,
                                     observedAt: Date = Date()) {
        performMutation {
            guard let record = try fetchRequired(ContainerRecord.self).first(where: { $0.scopedID == scopedID }) else { return }
            record.migrationStateRaw = "recreateFailed"
            record.updatedAt = observedAt
            save()
        }
    }

    func markContainerMigrationFailed(scopedID: String,
                                      message: String? = nil,
                                      observedAt: Date = Date()) {
        performMutation {
            guard let record = try fetchRequired(ContainerRecord.self).first(where: { $0.scopedID == scopedID }) else { return }
            record.isHiddenDuringMigration = false
            record.migrationStateRaw = message.map { "failed:\($0)" } ?? "failed"
            record.updatedAt = observedAt
            save()
        }
    }

    func completeContainerMigration(sourceScopedID: String,
                                    target: Core.Container.Snapshot,
                                    targetDocument: Core.Schema.Document,
                                    sourceRuntimeKind: Core.Runtime.Kind,
                                    sourceDocument: Core.Schema.Document,
                                    observedAt: Date = Date()) {
        performMutation {
            let record: ContainerRecord
            if let existing = try fetchRequired(ContainerRecord.self).first(where: { $0.scopedID == sourceScopedID }) {
                record = existing
            } else if let existing = try fetchRequired(ContainerRecord.self).first(where: { $0.scopedID == target.scopedID }) {
                record = existing
            } else {
                record = ContainerRecord(scopedID: sourceScopedID,
                                         runtimeKindRaw: sourceRuntimeKind.rawValue,
                                         runtimeID: target.id,
                                         displayName: target.displayName,
                                         imageReference: target.image,
                                         statusRaw: target.state.rawValue)
                context.insert(record)
            }

            for duplicate in try fetchRequired(ContainerRecord.self) where duplicate.scopedID == target.scopedID && duplicate !== record {
                context.delete(duplicate)
            }

            var projections = runtimeProjections(from: record)
            projections[sourceRuntimeKind.rawValue] = sourceDocument
            projections[target.runtimeKind.rawValue] = targetDocument
            record.scopedID = target.scopedID
            record.runtimeKindRaw = target.runtimeKind.rawValue
            record.runtimeID = target.id
            record.displayName = target.displayName
            record.imageReference = target.image
            record.statusRaw = target.state.rawValue
            record.documentData = encode(targetDocument)
            record.snapshotData = encode(target)
            record.runtimeProjectionsData = encode(projections)
            record.isMissing = false
            record.isHiddenDuringMigration = false
            record.migrationStateRaw = "none"
            record.missingSince = nil
            record.lastSeenAt = observedAt
            record.updatedAt = observedAt
            save()
        }
    }

    private func runtimeProjections(from record: ContainerRecord) -> [String: Core.Schema.Document] {
        guard let data = record.runtimeProjectionsData else { return [:] }
        do {
            return try JSONDecoder().decode([String: Core.Schema.Document].self, from: data)
        } catch {
            recordFailure(.decodeRecord(record: "runtime projections \(record.scopedID)",
                                        detail: AppDatabase.safeDetail(error)))
            return [:]
        }
    }

    private func shouldRetainMissingContainer(_ record: ContainerRecord,
                                              personalizedIDs: Set<String>,
                                              healthCheckedIDs: Set<String>) -> Bool {
        record.isHiddenDuringMigration ||
            record.migrationStateRaw != "none" ||
            record.runtimeProjectionsData != nil ||
            record.linkedVolumePathsData != nil ||
            personalizedIDs.contains(record.scopedID) ||
            healthCheckedIDs.contains(record.scopedID)
    }

    private func encode<T: Encodable>(_ value: T) -> Data {
        do {
            return try Self.encoded(value)
        } catch {
            recordFailure(.encodeRecord(type: String(describing: T.self),
                                        detail: AppDatabase.safeDetail(error)))
            return Data()
        }
    }

}

private struct ExistingContainerProjection: Sendable {
    let runtimeKindRaw: String
    let runtimeID: String
    let displayName: String
    let imageReference: String
    let statusRaw: String
    let documentData: Data?
    let snapshotData: Data?
    let isMissing: Bool
    let missingSince: Date?

    init(_ record: ContainerRecord) {
        runtimeKindRaw = record.runtimeKindRaw
        runtimeID = record.runtimeID
        displayName = record.displayName
        imageReference = record.imageReference
        statusRaw = record.statusRaw
        documentData = record.documentData
        snapshotData = record.snapshotData
        isMissing = record.isMissing
        missingSince = record.missingSince
    }
}

private struct PreparedContainerProjection: Sendable {
    let snapshot: Core.Container.Snapshot
    let documentData: Data?
    let snapshotData: Data?
}

private struct ContainerEncodingFailure: Sendable {
    let type: String
    let detail: String
}

private struct ContainerInventoryPreparation: Sendable {
    var items: [PreparedContainerProjection] = []
    var failures: [ContainerEncodingFailure] = []
    var result = InventoryPersistenceResult()
}

private enum ContainerInventoryPreparer {
    static func prepare(snapshots: [Core.Container.Snapshot],
                        existing: [String: ExistingContainerProjection]) -> ContainerInventoryPreparation {
        var output = ContainerInventoryPreparation()
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        for snapshot in snapshots {
            if let record = existing[snapshot.scopedID] {
                let scalarFieldsMatch = record.runtimeKindRaw == snapshot.runtimeKind.rawValue &&
                    record.runtimeID == snapshot.id &&
                    record.displayName == snapshot.displayName &&
                    record.imageReference == snapshot.image &&
                    record.statusRaw == snapshot.state.rawValue
                let snapshotMatches = record.snapshotData.flatMap {
                    try? decoder.decode(Core.Container.Snapshot.self, from: $0)
                } == snapshot

                if scalarFieldsMatch && snapshotMatches && record.documentData != nil {
                    if record.isMissing || record.missingSince != nil {
                        output.items.append(PreparedContainerProjection(snapshot: snapshot,
                                                                         documentData: nil,
                                                                         snapshotData: nil))
                        output.result.updated += 1
                    } else {
                        output.result.unchanged += 1
                    }
                    continue
                }
            }

            do {
                let document = Core.Schema.Document.containerEdit(from: snapshot.configuration)
                let documentData = try encoder.encode(document)
                let snapshotData = try encoder.encode(snapshot)
                output.items.append(PreparedContainerProjection(snapshot: snapshot,
                                                                 documentData: documentData,
                                                                 snapshotData: snapshotData))
                output.result.encoded += 1
                if existing[snapshot.scopedID] == nil {
                    output.result.inserted += 1
                } else {
                    output.result.updated += 1
                }
            } catch {
                output.failures.append(ContainerEncodingFailure(
                    type: "container inventory projection",
                    detail: AppDatabase.safeDetail(error)
                ))
            }
        }
        return output
    }
}

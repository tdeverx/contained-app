import Foundation
import ContainedCore

extension AppDatabase {
    func upsertContainers(_ snapshots: [Core.Container.Snapshot], observedAt: Date = Date()) {
        let seen = Set(snapshots.map(\.scopedID))
        for snapshot in snapshots {
            let document = Core.Schema.Document.containerEdit(from: snapshot.configuration)
            let documentData = Self.encode(document)
            let snapshotData = Self.encode(snapshot)
            if let record = fetch(ContainerRecord.self).first(where: { $0.scopedID == snapshot.scopedID }) {
                record.runtimeKindRaw = snapshot.runtimeKind.rawValue
                record.runtimeID = snapshot.id
                record.displayName = snapshot.displayName
                record.imageReference = snapshot.image
                record.statusRaw = snapshot.state.rawValue
                record.documentData = documentData
                record.snapshotData = snapshotData
                record.isMissing = false
                record.missingSince = nil
                record.lastSeenAt = observedAt
                record.updatedAt = observedAt
            } else {
                context.insert(ContainerRecord(scopedID: snapshot.scopedID,
                                               runtimeKindRaw: snapshot.runtimeKind.rawValue,
                                               runtimeID: snapshot.id,
                                               displayName: snapshot.displayName,
                                               imageReference: snapshot.image,
                                               statusRaw: snapshot.state.rawValue,
                                               documentData: documentData,
                                               snapshotData: snapshotData,
                                               lastSeenAt: observedAt,
                                               updatedAt: observedAt))
            }
        }
        for record in fetch(ContainerRecord.self) where !seen.contains(record.scopedID) && !record.isMissing {
            if shouldRetainMissingContainer(record) {
                record.isMissing = true
                record.missingSince = observedAt
                record.updatedAt = observedAt
            } else {
                context.delete(record)
            }
        }
        save()
    }

    func upsertImages(_ images: [Core.Image.Resource], observedAt: Date = Date()) {
        let groups = Core.Image.LocalTagGroup.groups(for: images)
        var seenTags: Set<String> = []
        for group in groups {
            let identity = group.id
            if let record = fetch(ImageRecord.self).first(where: { $0.identity == identity }) {
                record.primaryReference = group.primaryReference
                record.digest = group.digest
                record.updatedAt = observedAt
            } else {
                context.insert(ImageRecord(identity: identity,
                                           primaryReference: group.primaryReference,
                                           digest: group.digest,
                                           updatedAt: observedAt))
            }
        }
        for image in images {
            let identity = image.digest ?? Core.Registry.ImageReference.normalizedKey(image.reference)
            let tagID = image.runtimeKind.scopedID(for: Core.Registry.ImageReference.normalizedKey(image.reference))
            seenTags.insert(tagID)
            if let tag = fetch(ImageTagRecord.self).first(where: { $0.scopedID == tagID }) {
                tag.imageIdentity = identity
                tag.reference = image.reference
                tag.runtimeKindRaw = image.runtimeKind.rawValue
                tag.runtimeImageID = image.id
                tag.digest = image.digest
                tag.resourceData = Self.encode(image)
                tag.isLocal = true
                tag.isMissing = false
                tag.missingSince = nil
                tag.lastSeenAt = observedAt
                tag.updatedAt = observedAt
            } else {
                context.insert(ImageTagRecord(scopedID: tagID,
                                              imageIdentity: identity,
                                              reference: image.reference,
                                              runtimeKindRaw: image.runtimeKind.rawValue,
                                              runtimeImageID: image.id,
                                              digest: image.digest,
                                              resourceData: Self.encode(image),
                                              lastSeenAt: observedAt,
                                              updatedAt: observedAt))
            }
        }
        for tag in fetch(ImageTagRecord.self) where !seenTags.contains(tag.scopedID) && !tag.isMissing {
            context.delete(tag)
        }
        save()
    }

    func updateImageStatuses(_ statuses: [String: Core.Image.UpdateStatus], observedAt: Date = Date()) {
        let seen = Set(statuses.keys)
        for (key, status) in statuses {
            let data = Self.encode(status)
            if let image = fetch(ImageRecord.self).first(where: { $0.identity == key || Core.Registry.ImageReference.normalizedKey($0.primaryReference) == key }) {
                image.updateStatusData = data
                image.lastCheckedAt = observedAt
                image.updatedAt = observedAt
            } else {
                context.insert(ImageRecord(identity: key,
                                           primaryReference: key,
                                           updateStatusData: data,
                                           lastCheckedAt: observedAt,
                                           updatedAt: observedAt))
            }
        }
        for image in fetch(ImageRecord.self) where !seen.contains(image.identity) && !seen.contains(Core.Registry.ImageReference.normalizedKey(image.primaryReference)) {
            image.updateStatusData = nil
            image.updatedAt = observedAt
        }
        save()
    }

    func imageStatusesSnapshot() -> [String: Core.Image.UpdateStatus] {
        var snapshot: [String: Core.Image.UpdateStatus] = [:]
        for record in fetch(ImageRecord.self) {
            guard let data = record.updateStatusData else { continue }
            let status: Core.Image.UpdateStatus
            do {
                status = try JSONDecoder().decode(Core.Image.UpdateStatus.self, from: data)
            } catch {
                fatalError("Unable to decode image update status for \(record.identity): \(error)")
            }
            let value = status.state == .checking ? Core.Image.UpdateStatus() : status
            snapshot[record.identity] = value
            snapshot[Core.Registry.ImageReference.normalizedKey(record.primaryReference)] = value
        }
        return snapshot
    }

    func hiddenContainerScopedIDs() -> Set<String> {
        Set(fetch(ContainerRecord.self).filter(\.isHiddenDuringMigration).map(\.scopedID))
    }

    func upsertVolumes(_ volumes: [Core.Volume.Resource], observedAt: Date = Date()) {
        let seen = Set(volumes.map(\.scopedID))
        for volume in volumes {
            if let record = fetch(VolumeRecord.self).first(where: { $0.scopedID == volume.scopedID }) {
                record.runtimeKindRaw = volume.runtimeKind.rawValue
                record.name = volume.name
                record.resourceData = Self.encode(volume)
                record.isMissing = false
                record.missingSince = nil
                record.lastSeenAt = observedAt
                record.updatedAt = observedAt
            } else {
                context.insert(VolumeRecord(scopedID: volume.scopedID,
                                            runtimeKindRaw: volume.runtimeKind.rawValue,
                                            name: volume.name,
                                            resourceData: Self.encode(volume),
                                            lastSeenAt: observedAt,
                                            updatedAt: observedAt))
            }
        }
        for record in fetch(VolumeRecord.self) where !seen.contains(record.scopedID) && !record.isMissing {
            if record.personalizationData != nil {
                record.isMissing = true
                record.missingSince = observedAt
                record.updatedAt = observedAt
            } else {
                context.delete(record)
            }
        }
        save()
    }

    func upsertNetworks(_ networks: [Core.Network.Resource], observedAt: Date = Date()) {
        let seen = Set(networks.map(\.scopedID))
        for network in networks {
            if let record = fetch(NetworkRecord.self).first(where: { $0.scopedID == network.scopedID }) {
                record.runtimeKindRaw = network.runtimeKind.rawValue
                record.name = network.name
                record.resourceData = Self.encode(network)
                record.isMissing = false
                record.missingSince = nil
                record.lastSeenAt = observedAt
                record.updatedAt = observedAt
            } else {
                context.insert(NetworkRecord(scopedID: network.scopedID,
                                             runtimeKindRaw: network.runtimeKind.rawValue,
                                             name: network.name,
                                             resourceData: Self.encode(network),
                                             lastSeenAt: observedAt,
                                             updatedAt: observedAt))
            }
        }
        for record in fetch(NetworkRecord.self) where !seen.contains(record.scopedID) && !record.isMissing {
            context.delete(record)
        }
        save()
    }

    func markContainerMigrationStarted(source: Core.Container.Snapshot,
                                       targetRuntimeKind: Core.Runtime.Kind,
                                       sourceDocument: Core.Schema.Document,
                                       observedAt: Date = Date()) {
        let record: ContainerRecord
        if let existing = fetch(ContainerRecord.self).first(where: { $0.scopedID == source.scopedID }) {
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
        record.documentData = Self.encode(sourceDocument)
        record.snapshotData = Self.encode(source)
        record.runtimeProjectionsData = Self.encode(projections)
        record.isHiddenDuringMigration = true
        record.migrationStateRaw = "migrating:\(source.runtimeKind.rawValue):\(targetRuntimeKind.rawValue)"
        record.isMissing = false
        record.lastSeenAt = observedAt
        record.updatedAt = observedAt
        save()
    }

    func markContainerMigrationFailed(scopedID: String,
                                      message: String? = nil,
                                      observedAt: Date = Date()) {
        guard let record = fetch(ContainerRecord.self).first(where: { $0.scopedID == scopedID }) else { return }
        record.isHiddenDuringMigration = false
        record.migrationStateRaw = message.map { "failed:\($0)" } ?? "failed"
        record.updatedAt = observedAt
        save()
    }

    func completeContainerMigration(sourceScopedID: String,
                                    target: Core.Container.Snapshot,
                                    targetDocument: Core.Schema.Document,
                                    sourceRuntimeKind: Core.Runtime.Kind,
                                    sourceDocument: Core.Schema.Document,
                                    observedAt: Date = Date()) {
        let record: ContainerRecord
        if let existing = fetch(ContainerRecord.self).first(where: { $0.scopedID == sourceScopedID }) {
            record = existing
        } else if let existing = fetch(ContainerRecord.self).first(where: { $0.scopedID == target.scopedID }) {
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

        for duplicate in fetch(ContainerRecord.self) where duplicate.scopedID == target.scopedID && duplicate !== record {
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
        record.documentData = Self.encode(targetDocument)
        record.snapshotData = Self.encode(target)
        record.runtimeProjectionsData = Self.encode(projections)
        record.isMissing = false
        record.isHiddenDuringMigration = false
        record.migrationStateRaw = "none"
        record.missingSince = nil
        record.lastSeenAt = observedAt
        record.updatedAt = observedAt
        save()
    }

    private func runtimeProjections(from record: ContainerRecord) -> [String: Core.Schema.Document] {
        guard let data = record.runtimeProjectionsData else { return [:] }
        do {
            return try JSONDecoder().decode([String: Core.Schema.Document].self, from: data)
        } catch {
            fatalError("Unable to decode runtime projections for \(record.scopedID): \(error)")
        }
    }

    private func shouldRetainMissingContainer(_ record: ContainerRecord) -> Bool {
        record.isHiddenDuringMigration ||
            record.migrationStateRaw != "none" ||
            record.runtimeProjectionsData != nil ||
            fetch(PersonalizationRecord.self).contains { $0.key == record.scopedID } ||
            fetch(HealthCheckRecord.self).contains { $0.containerScopedID == record.scopedID }
    }

    private static func encode<T: Encodable>(_ value: T) -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            fatalError("Unable to encode app database value \(T.self): \(error)")
        }
    }
}

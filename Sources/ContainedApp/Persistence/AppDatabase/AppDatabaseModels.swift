import Foundation
import SwiftData

@Model
final class AppSettingRecord {
    var key: String
    var valueData: Data
    var updatedAt: Date

    init(key: String, valueData: Data, updatedAt: Date = Date()) {
        self.key = key
        self.valueData = valueData
        self.updatedAt = updatedAt
    }
}

@Model
final class RuntimeRecord {
    var runtimeKindRaw: String
    var cliPathOverride: String
    var isAvailable: Bool
    var readinessRaw: String
    var lastCheckedAt: Date?
    var lastError: String?

    init(runtimeKindRaw: String,
         cliPathOverride: String = "",
         isAvailable: Bool = false,
         readinessRaw: String = "unknown",
         lastCheckedAt: Date? = nil,
         lastError: String? = nil) {
        self.runtimeKindRaw = runtimeKindRaw
        self.cliPathOverride = cliPathOverride
        self.isAvailable = isAvailable
        self.readinessRaw = readinessRaw
        self.lastCheckedAt = lastCheckedAt
        self.lastError = lastError
    }
}

@Model
final class ContainerRecord {
    var scopedID: String
    var runtimeKindRaw: String
    var runtimeID: String
    var displayName: String
    var imageReference: String
    var statusRaw: String
    var documentData: Data?
    var snapshotData: Data?
    var runtimeProjectionsData: Data?
    var isMissing: Bool
    var isHiddenDuringMigration: Bool
    var migrationStateRaw: String
    var lastSeenAt: Date?
    var missingSince: Date?
    var updatedAt: Date

    init(scopedID: String,
         runtimeKindRaw: String,
         runtimeID: String,
         displayName: String,
         imageReference: String,
         statusRaw: String,
         documentData: Data? = nil,
         snapshotData: Data? = nil,
         runtimeProjectionsData: Data? = nil,
         isMissing: Bool = false,
         isHiddenDuringMigration: Bool = false,
         migrationStateRaw: String = "none",
         lastSeenAt: Date? = nil,
         missingSince: Date? = nil,
         updatedAt: Date = Date()) {
        self.scopedID = scopedID
        self.runtimeKindRaw = runtimeKindRaw
        self.runtimeID = runtimeID
        self.displayName = displayName
        self.imageReference = imageReference
        self.statusRaw = statusRaw
        self.documentData = documentData
        self.snapshotData = snapshotData
        self.runtimeProjectionsData = runtimeProjectionsData
        self.isMissing = isMissing
        self.isHiddenDuringMigration = isHiddenDuringMigration
        self.migrationStateRaw = migrationStateRaw
        self.lastSeenAt = lastSeenAt
        self.missingSince = missingSince
        self.updatedAt = updatedAt
    }
}

@Model
final class RecipeRecord {
    var id: String
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var documentData: Data
    var personalizationData: Data?
    var healthCheckData: Data?
    var sourceRaw: String

    init(id: String = UUID().uuidString,
         name: String,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         documentData: Data,
         personalizationData: Data? = nil,
         healthCheckData: Data? = nil,
         sourceRaw: String = "template") {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.documentData = documentData
        self.personalizationData = personalizationData
        self.healthCheckData = healthCheckData
        self.sourceRaw = sourceRaw
    }
}

@Model
final class ImageRecord {
    var identity: String
    var primaryReference: String
    var digest: String?
    var updateStatusData: Data?
    var registryMetadataData: Data?
    var personalizationData: Data?
    var lastCheckedAt: Date?
    var updatedAt: Date

    init(identity: String,
         primaryReference: String,
         digest: String? = nil,
         updateStatusData: Data? = nil,
         registryMetadataData: Data? = nil,
         personalizationData: Data? = nil,
         lastCheckedAt: Date? = nil,
         updatedAt: Date = Date()) {
        self.identity = identity
        self.primaryReference = primaryReference
        self.digest = digest
        self.updateStatusData = updateStatusData
        self.registryMetadataData = registryMetadataData
        self.personalizationData = personalizationData
        self.lastCheckedAt = lastCheckedAt
        self.updatedAt = updatedAt
    }
}

@Model
final class ImageTagRecord {
    var scopedID: String
    var imageIdentity: String
    var reference: String
    var runtimeKindRaw: String
    var runtimeImageID: String
    var digest: String?
    var resourceData: Data?
    var isLocal: Bool
    var isMissing: Bool
    var lastSeenAt: Date?
    var missingSince: Date?
    var updatedAt: Date

    init(scopedID: String,
         imageIdentity: String,
         reference: String,
         runtimeKindRaw: String,
         runtimeImageID: String,
         digest: String? = nil,
         resourceData: Data? = nil,
         isLocal: Bool = true,
         isMissing: Bool = false,
         lastSeenAt: Date? = nil,
         missingSince: Date? = nil,
         updatedAt: Date = Date()) {
        self.scopedID = scopedID
        self.imageIdentity = imageIdentity
        self.reference = reference
        self.runtimeKindRaw = runtimeKindRaw
        self.runtimeImageID = runtimeImageID
        self.digest = digest
        self.resourceData = resourceData
        self.isLocal = isLocal
        self.isMissing = isMissing
        self.lastSeenAt = lastSeenAt
        self.missingSince = missingSince
        self.updatedAt = updatedAt
    }
}

@Model
final class VolumeRecord {
    var scopedID: String
    var runtimeKindRaw: String
    var name: String
    var resourceData: Data?
    var personalizationData: Data?
    var isMissing: Bool
    var lastSeenAt: Date?
    var missingSince: Date?
    var updatedAt: Date

    init(scopedID: String,
         runtimeKindRaw: String,
         name: String,
         resourceData: Data? = nil,
         personalizationData: Data? = nil,
         isMissing: Bool = false,
         lastSeenAt: Date? = nil,
         missingSince: Date? = nil,
         updatedAt: Date = Date()) {
        self.scopedID = scopedID
        self.runtimeKindRaw = runtimeKindRaw
        self.name = name
        self.resourceData = resourceData
        self.personalizationData = personalizationData
        self.isMissing = isMissing
        self.lastSeenAt = lastSeenAt
        self.missingSince = missingSince
        self.updatedAt = updatedAt
    }
}

@Model
final class NetworkRecord {
    var scopedID: String
    var runtimeKindRaw: String
    var name: String
    var resourceData: Data?
    var isMissing: Bool
    var lastSeenAt: Date?
    var missingSince: Date?
    var updatedAt: Date

    init(scopedID: String,
         runtimeKindRaw: String,
         name: String,
         resourceData: Data? = nil,
         isMissing: Bool = false,
         lastSeenAt: Date? = nil,
         missingSince: Date? = nil,
         updatedAt: Date = Date()) {
        self.scopedID = scopedID
        self.runtimeKindRaw = runtimeKindRaw
        self.name = name
        self.resourceData = resourceData
        self.isMissing = isMissing
        self.lastSeenAt = lastSeenAt
        self.missingSince = missingSince
        self.updatedAt = updatedAt
    }
}

@Model
final class PersonalizationRecord {
    var key: String
    var scopeRaw: String
    var valueData: Data
    var updatedAt: Date

    init(key: String, scopeRaw: String, valueData: Data, updatedAt: Date = Date()) {
        self.key = key
        self.scopeRaw = scopeRaw
        self.valueData = valueData
        self.updatedAt = updatedAt
    }
}

@Model
final class HealthCheckRecord {
    var containerScopedID: String
    var valueData: Data
    var updatedAt: Date

    init(containerScopedID: String, valueData: Data, updatedAt: Date = Date()) {
        self.containerScopedID = containerScopedID
        self.valueData = valueData
        self.updatedAt = updatedAt
    }
}

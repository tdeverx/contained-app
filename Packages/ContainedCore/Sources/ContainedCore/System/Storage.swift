import Foundation

public extension Core.System {
    enum StorageCategory: String, CaseIterable, Sendable, Identifiable {
        case containers, imageSnapshots, imageContent, volumes, builder, ingest, other
        public var id: String { rawValue }
    }

    struct StorageCapacity: Sendable, Equatable {
        public let availableBytes: Int64
        public let totalBytes: Int64
        public var isCritical: Bool { availableBytes < 1_073_741_824 }
        public var isLow: Bool { availableBytes < 5_368_709_120 }
    }

    struct StorageAnalysis: Sendable, Equatable {
        public let runtimeKind: Core.Runtime.Kind
        public let measuredAt: Date
        public let allocatedBytes: [StorageCategory: UInt64]
        public let resourceAllocatedBytes: [String: UInt64]
        public let capacity: StorageCapacity?
        public let runtimeReported: DiskUsage?
        public let isComplete: Bool
        public let unsupportedEntries: [String]
        public let longRunningBindContainerIDs: [String]
        public var totalAllocatedBytes: UInt64 { allocatedBytes.values.reduce(0, +) }
    }

    enum CleanupAction: String, CaseIterable, Sendable, Identifiable, Codable {
        case compactRunningContainers, compactRunningBuilder, resetBuilderCache
        case danglingImages, unusedImages, unusedVolumes, unusedNetworks, stoppedContainers
        public var id: String { rawValue }
        public var risk: CleanupRisk {
            switch self {
            case .compactRunningContainers, .compactRunningBuilder: return .compaction
            case .resetBuilderCache: return .cacheDiscard
            case .danglingImages, .unusedImages, .unusedNetworks: return .unreferencedResources
            case .unusedVolumes, .stoppedContainers: return .dataDeletion
            }
        }
        public var automaticAllowed: Bool { risk == .compaction }
    }

    enum CleanupRisk: String, Sendable { case compaction, cacheDiscard, unreferencedResources, dataDeletion }

    struct CleanupPlan: Sendable, Identifiable {
        public let id: UUID
        public let runtimeKind: Core.Runtime.Kind
        public let action: CleanupAction
        public let resourceIDs: [String]
        public let commands: [[String]]
        /// Allocated space occupied by candidates, not a promise that it can all be reclaimed.
        public let candidateAllocatedBytes: UInt64?
        public let createdAt: Date
        internal let validationToken: Data
        internal let resourceLimit: Int?
    }

    struct CleanupResult: Sendable {
        public let action: CleanupAction
        public let completedCount: Int
        public let failureCodes: [String]
        public let before: StorageAnalysis?
        public let after: StorageAnalysis?
        public var reclaimedHostBytes: UInt64? {
            guard let before, let after, before.isComplete, after.isComplete else { return nil }
            return before.totalAllocatedBytes > after.totalAllocatedBytes
                ? before.totalAllocatedBytes - after.totalAllocatedBytes : 0
        }
    }

    enum StorageError: Core.Error.PackageError {
        case unavailable, inventoryChanged, stalePlan, invalidRoot, unsupportedAutomation
        public var packageName: String { "ContainedCore" }
        public var packageErrorCode: String {
            switch self {
            case .unavailable: return "storageUnavailable"
            case .inventoryChanged: return "storageInventoryChanged"
            case .stalePlan: return "storagePlanExpired"
            case .invalidRoot: return "storageInvalidRoot"
            case .unsupportedAutomation: return "storageAutomationNotAllowed"
            }
        }
    }

    struct StorageCleanupPolicy: Codable, Sendable, Equatable {
        public var enabled = false
        public var compactContainers = true
        public var compactBuilder = false
        public var intervalHours = 6
        public var minimumFreeGiB = 10
        public var maximumAllocatedGiB = 100
        public init() {}
        public func shouldRun(analysis: StorageAnalysis, lastRun: Date?, now: Date = Date()) -> Bool {
            guard enabled, compactContainers || compactBuilder, analysis.isComplete,
                  lastRun.map({ now.timeIntervalSince($0) >= Double(max(1, intervalHours)) * 3600 }) ?? true else { return false }
            let lowSpace = analysis.capacity.map { $0.availableBytes < Int64(max(1, minimumFreeGiB)) * 1_073_741_824 } ?? false
            return lowSpace || analysis.totalAllocatedBytes >= UInt64(max(1, maximumAllocatedGiB)) * 1_073_741_824
        }
    }
}

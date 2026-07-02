import Foundation

/// `container system df --format json`.
public struct DiskUsage: Codable, Sendable, Hashable {
    public let containers: Category
    public let images: Category
    public let volumes: Category

    public struct Category: Codable, Sendable, Hashable {
        public let active: Int
        public let total: Int
        public let sizeInBytes: UInt64
        public let reclaimable: UInt64
    }

    public var totalSizeInBytes: UInt64 { containers.sizeInBytes + images.sizeInBytes + volumes.sizeInBytes }
    public var totalReclaimableBytes: UInt64 { containers.reclaimable + images.reclaimable + volumes.reclaimable }
}

/// `container system status --format json`.
public struct SystemStatus: Codable, Sendable, Hashable {
    public let status: String
    public let appRoot: String?
    public let installRoot: String?
    public let apiServerVersion: String?
    public let apiServerCommit: String?
    public let apiServerBuild: String?
    public let apiServerAppName: String?

    public var isRunning: Bool { status.lowercased() == "running" }
}

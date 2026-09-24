import Foundation

/// `container system df --format json`.
public extension Core.System {
struct DiskUsage: Codable, Sendable, Hashable {
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
struct Status: Codable, Sendable, Hashable {
    public let status: String
    public let client: Component?
    public let server: Component?
    public let host: Host?
    public let paths: Paths?
    public let resources: Resources?

    public struct Component: Codable, Sendable, Hashable {
        public let version: String
        public let build: String
        public let commit: String
        public let appName: String
    }

    public struct Host: Codable, Sendable, Hashable {
        public let architecture: String
        public let operatingSystem: String
        public let cpus: Int
    }

    public struct Paths: Codable, Sendable, Hashable {
        public let appRoot: String
        public let installRoot: String
        public let logRoot: String?
    }

    public struct Resources: Codable, Sendable, Hashable {
        public let containersTotal: Int
        public let containersRunning: Int
        public let images: Int?
    }

    public var appRoot: String? { paths?.appRoot }
    public var installRoot: String? { paths?.installRoot }
    public var apiServerVersion: String? { server?.version }
    public var apiServerCommit: String? { server?.commit }
    public var apiServerBuild: String? { server?.build }
    public var apiServerAppName: String? { server?.appName }

    public var isRunning: Bool { status.lowercased() == "running" }

    private enum CodingKeys: String, CodingKey {
        case status, client, server, host, paths, resources
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case appRoot, installRoot, apiServerVersion, apiServerCommit, apiServerBuild, apiServerAppName
    }

    public init(status: String,
                client: Component? = nil,
                server: Component? = nil,
                host: Host? = nil,
                paths: Paths? = nil,
                resources: Resources? = nil) {
        self.status = status
        self.client = client
        self.server = server
        self.host = host
        self.paths = paths
        self.resources = resources
    }

    public init(status: String,
                appRoot: String?,
                installRoot: String?,
                apiServerVersion: String?,
                apiServerCommit: String?,
                apiServerBuild: String?,
                apiServerAppName: String?) {
        self.status = status
        client = nil
        host = nil
        resources = nil
        if let appRoot, let installRoot {
            paths = Paths(appRoot: appRoot, installRoot: installRoot, logRoot: nil)
        } else {
            paths = nil
        }
        if let version = apiServerVersion {
            server = Component(version: version,
                               build: apiServerBuild ?? "",
                               commit: apiServerCommit ?? "",
                               appName: apiServerAppName ?? "")
        } else {
            server = nil
        }
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
        status = try values.decode(String.self, forKey: .status)
        client = try values.decodeIfPresent(Component.self, forKey: .client)
        host = try values.decodeIfPresent(Host.self, forKey: .host)
        resources = try values.decodeIfPresent(Resources.self, forKey: .resources)

        if let nested = try values.decodeIfPresent(Paths.self, forKey: .paths) {
            paths = nested
        } else if let appRoot = try legacy.decodeIfPresent(String.self, forKey: .appRoot),
                  let installRoot = try legacy.decodeIfPresent(String.self, forKey: .installRoot) {
            paths = Paths(appRoot: appRoot, installRoot: installRoot, logRoot: nil)
        } else {
            paths = nil
        }

        if let nested = try values.decodeIfPresent(Component.self, forKey: .server) {
            server = nested
        } else if let version = try legacy.decodeIfPresent(String.self, forKey: .apiServerVersion) {
            server = Component(
                version: version,
                build: try legacy.decodeIfPresent(String.self, forKey: .apiServerBuild) ?? "",
                commit: try legacy.decodeIfPresent(String.self, forKey: .apiServerCommit) ?? "",
                appName: try legacy.decodeIfPresent(String.self, forKey: .apiServerAppName) ?? ""
            )
        } else {
            server = nil
        }
    }
}

}

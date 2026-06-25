import Foundation

/// One element of `container list --format json` / `container inspect`.
///
/// Shape verified against captured fixtures: a top-level object with `configuration`, a duplicated
/// `id`, and a `status` object that nests `state`, `networks`, and `startedDate`.
public struct ContainerSnapshot: Codable, Sendable, Identifiable, Hashable {
    public let configuration: ContainerConfiguration
    public let id: String
    public let status: ContainerRuntimeState

    public var state: RuntimeStatus { status.state }
    public var image: String { configuration.image.reference }
    public var startedDate: Date? { status.startedDate }

    /// Personalization is stored as namespaced container labels so it round-trips through the CLI.
    public var tintLabel: String? { configuration.labels["contained.tint"] }
    public var iconLabel: String? { configuration.labels["contained.icon"] }
    public var nicknameLabel: String? { configuration.labels["contained.nickname"] }
    public var restartLabel: String? { configuration.labels["contained.restart"] }

    /// Name shown in the UI: nickname label if present, otherwise the container id.
    public var displayName: String { nicknameLabel ?? id }
}

/// The `status` object inside a snapshot.
public struct ContainerRuntimeState: Codable, Sendable, Hashable {
    public let state: RuntimeStatus
    public let networks: [NetworkInterfaceStatus]
    public let startedDate: Date?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.state = try c.decodeIfPresent(RuntimeStatus.self, forKey: .state) ?? .unknown
        self.networks = try c.decodeIfPresent([NetworkInterfaceStatus].self, forKey: .networks) ?? []
        self.startedDate = try c.decodeIfPresent(Date.self, forKey: .startedDate)
    }
}

/// Runtime networking info (`status.networks[]`).
public struct NetworkInterfaceStatus: Codable, Sendable, Hashable {
    public let network: String
    public let hostname: String?
    public let ipv4Address: String?
    public let ipv4Gateway: String?
    public let ipv6Address: String?
    public let macAddress: String?
    public let mtu: Int?
}

/// The persistent `configuration` of a container.
public struct ContainerConfiguration: Codable, Sendable, Hashable {
    public let id: String
    public let image: ImageReference
    public let initProcess: ProcessConfiguration
    public let resources: ResourceConfiguration
    public let platform: Platform
    public let labels: [String: String]
    public let mounts: [Mount]
    public let networks: [NetworkAttachment]
    public let publishedPorts: [PublishedPort]
    public let publishedSockets: [PublishedSocket]
    public let dns: DNSConfiguration?
    public let sysctls: [String: String]
    public let capAdd: [String]
    public let capDrop: [String]
    public let rosetta: Bool
    public let runtimeHandler: String?
    public let ssh: Bool
    public let readOnly: Bool
    public let useInit: Bool
    public let virtualization: Bool
    public let shmSize: UInt64?
    public let stopSignal: String?
    public let creationDate: Date?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        image = try c.decode(ImageReference.self, forKey: .image)
        initProcess = try c.decode(ProcessConfiguration.self, forKey: .initProcess)
        resources = try c.decodeIfPresent(ResourceConfiguration.self, forKey: .resources) ?? .default
        platform = try c.decodeIfPresent(Platform.self, forKey: .platform) ?? .init(architecture: "arm64", os: "linux", variant: nil)
        labels = try c.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
        mounts = try c.decodeIfPresent([Mount].self, forKey: .mounts) ?? []
        networks = try c.decodeIfPresent([NetworkAttachment].self, forKey: .networks) ?? []
        publishedPorts = try c.decodeIfPresent([PublishedPort].self, forKey: .publishedPorts) ?? []
        publishedSockets = try c.decodeIfPresent([PublishedSocket].self, forKey: .publishedSockets) ?? []
        dns = try c.decodeIfPresent(DNSConfiguration.self, forKey: .dns)
        sysctls = try c.decodeIfPresent([String: String].self, forKey: .sysctls) ?? [:]
        capAdd = try c.decodeIfPresent([String].self, forKey: .capAdd) ?? []
        capDrop = try c.decodeIfPresent([String].self, forKey: .capDrop) ?? []
        rosetta = try c.decodeIfPresent(Bool.self, forKey: .rosetta) ?? false
        runtimeHandler = try c.decodeIfPresent(String.self, forKey: .runtimeHandler)
        ssh = try c.decodeIfPresent(Bool.self, forKey: .ssh) ?? false
        readOnly = try c.decodeIfPresent(Bool.self, forKey: .readOnly) ?? false
        useInit = try c.decodeIfPresent(Bool.self, forKey: .useInit) ?? false
        virtualization = try c.decodeIfPresent(Bool.self, forKey: .virtualization) ?? false
        shmSize = try c.decodeIfPresent(UInt64.self, forKey: .shmSize)
        stopSignal = try c.decodeIfPresent(String.self, forKey: .stopSignal)
        creationDate = try c.decodeIfPresent(Date.self, forKey: .creationDate)
    }
}

public struct ImageReference: Codable, Sendable, Hashable {
    public let reference: String
    public let descriptor: Descriptor?
}

public struct Descriptor: Codable, Sendable, Hashable {
    public let digest: String
    public let mediaType: String?
    public let size: Int?
}

public struct ProcessConfiguration: Codable, Sendable, Hashable {
    public let executable: String?
    public let arguments: [String]
    public let environment: [String]
    public let workingDirectory: String?
    public let terminal: Bool

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        executable = try c.decodeIfPresent(String.self, forKey: .executable)
        arguments = try c.decodeIfPresent([String].self, forKey: .arguments) ?? []
        environment = try c.decodeIfPresent([String].self, forKey: .environment) ?? []
        workingDirectory = try c.decodeIfPresent(String.self, forKey: .workingDirectory)
        terminal = try c.decodeIfPresent(Bool.self, forKey: .terminal) ?? false
    }
}

public struct ResourceConfiguration: Codable, Sendable, Hashable {
    public let cpus: Int
    public let memoryInBytes: UInt64
    public let cpuOverhead: Int?
    public let storage: UInt64?

    public static let `default` = ResourceConfiguration(cpus: 4, memoryInBytes: 1_073_741_824, cpuOverhead: 1, storage: nil)
}

public struct Platform: Codable, Sendable, Hashable {
    public let architecture: String
    public let os: String
    public let variant: String?

    public var display: String {
        var s = "\(os)/\(architecture)"
        if let variant, !variant.isEmpty { s += "/\(variant)" }
        return s
    }
}

public struct PublishedPort: Codable, Sendable, Hashable {
    public let containerPort: Int
    public let hostPort: Int
    public let hostAddress: String?
    public let proto: String?
    public let count: Int?

    public var display: String { "\(hostPort)→\(containerPort)" }
}

public struct PublishedSocket: Codable, Sendable, Hashable {
    public let hostPath: String?
    public let containerPath: String?
}

/// `configuration.networks[]` — the requested attachment (distinct from the runtime status network).
public struct NetworkAttachment: Codable, Sendable, Hashable {
    public let network: String
    public let options: Options?

    public struct Options: Codable, Sendable, Hashable {
        public let hostname: String?
        public let mtu: Int?
    }
}

public struct DNSConfiguration: Codable, Sendable, Hashable {
    public let nameservers: [String]
    public let searchDomains: [String]
    public let options: [String]
    public let domain: String?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nameservers = try c.decodeIfPresent([String].self, forKey: .nameservers) ?? []
        searchDomains = try c.decodeIfPresent([String].self, forKey: .searchDomains) ?? []
        options = try c.decodeIfPresent([String].self, forKey: .options) ?? []
        domain = try c.decodeIfPresent(String.self, forKey: .domain)
    }
}

public struct Mount: Codable, Sendable, Hashable {
    public let type: String?
    public let source: String?
    public let destination: String?
    public let target: String?
    public let readonly: Bool?

    public var effectiveDestination: String? { destination ?? target }

    enum CodingKeys: String, CodingKey { case type, source, destination, target, readonly }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        destination = try c.decodeIfPresent(String.self, forKey: .destination)
        target = try c.decodeIfPresent(String.self, forKey: .target)
        readonly = try c.decodeIfPresent(Bool.self, forKey: .readonly)
        // `type` may be a plain string ("bind") or a single-key enum object
        // (e.g. {"virtiofs":{}}); normalize both to the case name.
        if let s = try? c.decode(String.self, forKey: .type) {
            type = s
        } else if let nested = try? c.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .type) {
            type = nested.allKeys.first?.stringValue
        } else {
            type = nil
        }
    }
}

/// A CodingKey usable for arbitrary/dynamic JSON object keys.
struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.intValue = intValue; self.stringValue = String(intValue) }
}

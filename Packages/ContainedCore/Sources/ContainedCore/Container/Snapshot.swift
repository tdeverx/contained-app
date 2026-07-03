import Foundation

/// One element of `container list --format json` / `container inspect`.
///
/// Shape verified against captured fixtures: a top-level object with `configuration`, a duplicated
/// `id`, and a `status` object that nests `state`, `networks`, and `startedDate`.
public extension Core.Container {
struct Snapshot: Codable, Sendable, Identifiable, Hashable {
    public let configuration: Core.Container.Configuration
    public let id: String
    public let status: Core.Container.RuntimeState
    public let runtimeKind: Core.Runtime.Kind

    public var state: Core.Runtime.Status { status.state }
    public var rawState: String { status.rawState }
    public var image: String { configuration.image.reference }
    public var startedDate: Date? { status.startedDate }
    public var scopedID: String { runtimeKind.scopedID(for: id) }

    /// Functional restart policy label consumed by the app-managed watchdog.
    public var restartLabel: String? { configuration.labels["contained.restart"] }

    public var displayName: String { id }

    public init(configuration: Core.Container.Configuration,
                id: String,
                status: Core.Container.RuntimeState,
                runtimeKind: Core.Runtime.Kind) {
        self.configuration = configuration
        self.id = id
        self.status = status
        self.runtimeKind = runtimeKind
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        configuration = try c.decode(Core.Container.Configuration.self, forKey: .configuration)
        id = try c.decode(String.self, forKey: .id)
        status = try c.decode(Core.Container.RuntimeState.self, forKey: .status)
        runtimeKind = try c.decodeIfPresent(Core.Runtime.Kind.self, forKey: .runtimeKind) ?? configuration.runtimeKind
    }

    public func scoped(to runtimeKind: Core.Runtime.Kind) -> Core.Container.Snapshot {
        Core.Container.Snapshot(configuration: configuration.scoped(to: runtimeKind),
                                id: id,
                                status: status,
                                runtimeKind: runtimeKind)
    }

    /// A synthetic snapshot for previews and image-level customization (styling an image's default
    /// before any container from it exists). Encodes a minimal payload first so unusual image or
    /// volume names are escaped safely before decoding through the same defaults as real snapshots.
    public static func placeholder(id: String, image: String,
                                   state: Core.Runtime.Status = .running,
                                   runtimeKind: Core.Runtime.Kind) -> Core.Container.Snapshot {
        let payload = PlaceholderSnapshotPayload(
            id: id,
            status: .init(state: state.rawValue),
            configuration: .init(id: id, image: .init(reference: image), initProcess: .init())
        )
        do {
            let data = try JSONEncoder().encode(payload)
            return try Core.Container.JSON.decode(Core.Container.Snapshot.self,
                                                 from: data,
                                                 runtimeKind: runtimeKind)
        } catch {
            preconditionFailure("Invalid placeholder snapshot: \(error)")
        }
    }
}

private struct PlaceholderSnapshotPayload: Encodable {
    let id: String
    let status: Status
    let configuration: Configuration

    struct Status: Encodable {
        let state: String
    }

    struct Configuration: Encodable {
        let id: String
        let image: Image
        let initProcess: InitProcess
    }

    struct Image: Encodable {
        let reference: String
    }

    struct InitProcess: Encodable {}
}

/// The `status` object inside a snapshot.
struct RuntimeState: Codable, Sendable, Hashable {
    public let state: Core.Runtime.Status
    public let rawState: String
    public let networks: [NetworkInterfaceStatus]
    public let startedDate: Date?

    enum CodingKeys: String, CodingKey {
        case state
        case networks
        case startedDate
    }

    public init(state: Core.Runtime.Status,
                rawState: String? = nil,
                networks: [NetworkInterfaceStatus] = [],
                startedDate: Date? = nil) {
        self.state = state
        self.rawState = rawState ?? state.rawValue
        self.networks = networks
        self.startedDate = startedDate
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawState = try c.decodeIfPresent(String.self, forKey: .state) ?? Core.Runtime.Status.unknown.rawValue
        self.rawState = rawState
        self.state = Core.Runtime.Status(rawValue: rawState) ?? .unknown
        self.networks = try c.decodeIfPresent([NetworkInterfaceStatus].self, forKey: .networks) ?? []
        self.startedDate = try c.decodeIfPresent(Date.self, forKey: .startedDate)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(rawState, forKey: .state)
        try c.encode(networks, forKey: .networks)
        try c.encodeIfPresent(startedDate, forKey: .startedDate)
    }
}

/// Runtime networking info (`status.networks[]`).
struct NetworkInterfaceStatus: Codable, Sendable, Hashable {
    public let network: String
    public let hostname: String?
    public let ipv4Address: String?
    public let ipv4Gateway: String?
    public let ipv6Address: String?
    public let macAddress: String?
    public let mtu: Int?
}

/// The persistent `configuration` of a container.
struct Configuration: Codable, Sendable, Hashable {
    public let runtimeKind: Core.Runtime.Kind
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
        if let decodedRuntimeKind = try c.decodeIfPresent(Core.Runtime.Kind.self, forKey: .runtimeKind) {
            runtimeKind = decodedRuntimeKind
        } else if let contextRuntimeKind = decoder.coreRuntimeKindContext {
            runtimeKind = contextRuntimeKind
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.runtimeKind,
                DecodingError.Context(codingPath: decoder.codingPath,
                                      debugDescription: "Missing runtimeKind and no runtime decoding context was provided.")
            )
        }
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

    public init(runtimeKind: Core.Runtime.Kind,
                id: String,
                image: ImageReference,
                initProcess: ProcessConfiguration,
                resources: ResourceConfiguration = .default,
                platform: Platform = .init(architecture: "arm64", os: "linux", variant: nil),
                labels: [String: String] = [:],
                mounts: [Mount] = [],
                networks: [NetworkAttachment] = [],
                publishedPorts: [PublishedPort] = [],
                publishedSockets: [PublishedSocket] = [],
                dns: DNSConfiguration? = nil,
                sysctls: [String: String] = [:],
                capAdd: [String] = [],
                capDrop: [String] = [],
                rosetta: Bool = false,
                runtimeHandler: String? = nil,
                ssh: Bool = false,
                readOnly: Bool = false,
                useInit: Bool = false,
                virtualization: Bool = false,
                shmSize: UInt64? = nil,
                stopSignal: String? = nil,
                creationDate: Date? = nil) {
        self.runtimeKind = runtimeKind
        self.id = id
        self.image = image
        self.initProcess = initProcess
        self.resources = resources
        self.platform = platform
        self.labels = labels
        self.mounts = mounts
        self.networks = networks
        self.publishedPorts = publishedPorts
        self.publishedSockets = publishedSockets
        self.dns = dns
        self.sysctls = sysctls
        self.capAdd = capAdd
        self.capDrop = capDrop
        self.rosetta = rosetta
        self.runtimeHandler = runtimeHandler
        self.ssh = ssh
        self.readOnly = readOnly
        self.useInit = useInit
        self.virtualization = virtualization
        self.shmSize = shmSize
        self.stopSignal = stopSignal
        self.creationDate = creationDate
    }

    public func scoped(to runtimeKind: Core.Runtime.Kind) -> Core.Container.Configuration {
        Core.Container.Configuration(runtimeKind: runtimeKind,
                                     id: id,
                                     image: image,
                                     initProcess: initProcess,
                                     resources: resources,
                                     platform: platform,
                                     labels: labels,
                                     mounts: mounts,
                                     networks: networks,
                                     publishedPorts: publishedPorts,
                                     publishedSockets: publishedSockets,
                                     dns: dns,
                                     sysctls: sysctls,
                                     capAdd: capAdd,
                                     capDrop: capDrop,
                                     rosetta: rosetta,
                                     runtimeHandler: runtimeHandler,
                                     ssh: ssh,
                                     readOnly: readOnly,
                                     useInit: useInit,
                                     virtualization: virtualization,
                                     shmSize: shmSize,
                                     stopSignal: stopSignal,
                                     creationDate: creationDate)
    }
}

struct ImageReference: Codable, Sendable, Hashable {
    public let reference: String
    public let descriptor: Descriptor?
}

struct Descriptor: Codable, Sendable, Hashable {
    public let digest: String
    public let mediaType: String?
    public let size: Int?
}

struct ProcessConfiguration: Codable, Sendable, Hashable {
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

struct ResourceConfiguration: Codable, Sendable, Hashable {
    public let cpus: Int
    public let memoryInBytes: UInt64
    public let cpuOverhead: Int?
    public let storage: UInt64?

    public static let `default` = ResourceConfiguration(cpus: 4, memoryInBytes: 1_073_741_824, cpuOverhead: 1, storage: nil)
}

struct Platform: Codable, Sendable, Hashable {
    public let architecture: String
    public let os: String
    public let variant: String?

    public init(architecture: String, os: String, variant: String? = nil) {
        self.architecture = architecture
        self.os = os
        self.variant = variant
    }

    public var display: String {
        var s = "\(os)/\(architecture)"
        if let variant, !variant.isEmpty { s += "/\(variant)" }
        return s
    }
}

struct PublishedPort: Codable, Sendable, Hashable {
    public let containerPort: Int
    public let hostPort: Int
    public let hostAddress: String?
    public let proto: String?
    public let count: Int?

    public var display: String { "\(hostPort)→\(containerPort)" }
}

struct PublishedSocket: Codable, Sendable, Hashable {
    public let hostPath: String?
    public let containerPath: String?
}

/// `configuration.networks[]` — the requested attachment (distinct from the runtime status network).
struct NetworkAttachment: Codable, Sendable, Hashable {
    public let network: String
    public let options: Options?

    public struct Options: Codable, Sendable, Hashable {
        public let hostname: String?
        public let mtu: Int?
    }
}

struct DNSConfiguration: Codable, Sendable, Hashable {
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

struct Mount: Codable, Sendable, Hashable {
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
}

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.intValue = intValue; self.stringValue = String(intValue) }
}

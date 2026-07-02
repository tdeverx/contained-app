import Foundation

public enum RuntimeKind: String, Codable, Equatable, Sendable {
    case appleContainer
    case dockerCompatible
}

public struct RuntimeCapability: OptionSet, Equatable, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public static let containers = RuntimeCapability(rawValue: 1 << 0)
    public static let images = RuntimeCapability(rawValue: 1 << 1)
    public static let imageBuild = RuntimeCapability(rawValue: 1 << 2)
    public static let imagePush = RuntimeCapability(rawValue: 1 << 3)
    public static let imageArchive = RuntimeCapability(rawValue: 1 << 4)
    public static let registries = RuntimeCapability(rawValue: 1 << 5)
    public static let networks = RuntimeCapability(rawValue: 1 << 6)
    public static let volumes = RuntimeCapability(rawValue: 1 << 7)
    public static let systemStatus = RuntimeCapability(rawValue: 1 << 8)
    public static let systemLogs = RuntimeCapability(rawValue: 1 << 9)
    public static let systemProperties = RuntimeCapability(rawValue: 1 << 10)
    public static let dnsManagement = RuntimeCapability(rawValue: 1 << 11)
    public static let kernelManagement = RuntimeCapability(rawValue: 1 << 12)
    public static let exec = RuntimeCapability(rawValue: 1 << 13)
    public static let copy = RuntimeCapability(rawValue: 1 << 14)
    public static let containerExport = RuntimeCapability(rawValue: 1 << 15)

    public static let appleContainer: RuntimeCapability = [
        .containers,
        .images,
        .imageBuild,
        .imagePush,
        .imageArchive,
        .registries,
        .networks,
        .volumes,
        .systemStatus,
        .systemLogs,
        .systemProperties,
        .dnsManagement,
        .kernelManagement,
        .exec,
        .copy,
        .containerExport,
    ]
}

public struct RuntimeDescriptor: Equatable, Sendable {
    public var kind: RuntimeKind
    public var displayName: String
    public var executableName: String
    public var capabilities: RuntimeCapability

    public init(kind: RuntimeKind,
                displayName: String,
                executableName: String,
                capabilities: RuntimeCapability) {
        self.kind = kind
        self.displayName = displayName
        self.executableName = executableName
        self.capabilities = capabilities
    }

    public func supports(_ capability: RuntimeCapability) -> Bool {
        capabilities.isSuperset(of: capability)
    }

    public func require(_ capability: RuntimeCapability) throws {
        guard supports(capability) else {
            throw UnsupportedRuntimeCapability(kind: kind, capability: capability)
        }
    }

    public static let appleContainer = RuntimeDescriptor(
        kind: .appleContainer,
        displayName: "Apple container",
        executableName: "container",
        capabilities: .appleContainer
    )
}

public struct UnsupportedRuntimeCapability: Error, Equatable, Sendable {
    public var kind: RuntimeKind
    public var capability: RuntimeCapability

    public init(kind: RuntimeKind, capability: RuntimeCapability) {
        self.kind = kind
        self.capability = capability
    }
}

extension UnsupportedRuntimeCapability: LocalizedError {
    public var errorDescription: String? {
        "The selected runtime does not support this operation."
    }
}

public protocol ContainerRuntimeClient: Sendable {
    var descriptor: RuntimeDescriptor { get }

    func listContainers(all: Bool) async throws -> [ContainerSnapshot]
    func stats(ids: [String]) async throws -> [ContainerStats]
    func diskUsage() async throws -> DiskUsage
    func systemProperties() async throws -> SystemProperties
    func dnsDomains() async throws -> [String]
    func createDNSDomain(_ domain: String) async throws -> Data
    func deleteDNSDomain(_ domain: String) async throws -> Data
    func setRecommendedKernel() async throws -> Data
    func execCapture(_ id: String, _ command: [String]) async throws -> String
    func copy(source: String, destination: String) async throws -> Data
    func streamSystemLogs(follow: Bool, last: Int?) -> AsyncThrowingStream<String, Error>
    func systemStatus() async throws -> SystemStatus
    func networks() async throws -> [NetworkResource]
    func volumes() async throws -> [VolumeResource]
    func images() async throws -> [ImageResource]
    func inspectImage(_ ref: String) async throws -> [ImageResource]
    func streamLogs(id: String, follow: Bool, tail: Int?, boot: Bool) -> AsyncThrowingStream<String, Error>
    func streamPull(_ ref: String, platform: String?) -> AsyncThrowingStream<String, Error>
    func streamBuild(context: String, tag: String?, dockerfile: String?,
                     buildArgs: [String: String], noCache: Bool,
                     platform: String?) -> AsyncThrowingStream<String, Error>
    func streamPush(_ ref: String, platform: String?) -> AsyncThrowingStream<String, Error>
    func registries() async throws -> [RegistryLogin]
    func registryLogin(server: String, username: String, password: String) async throws -> Data
    func registryLogout(server: String) async throws -> Data
    func deleteImages(_ refs: [String]) async throws -> Data
    func tagImage(source: String, target: String) async throws -> Data
    func saveImages(_ refs: [String], to output: String) async throws -> Data
    func loadImages(from input: String) async throws -> Data
    func exportContainer(_ id: String, to output: String) async throws -> Data
    func pruneImages(all: Bool) async throws -> Data
    func start(_ ids: [String]) async throws -> Data
    func stop(_ ids: [String]) async throws -> Data
    func deleteContainers(_ ids: [String], force: Bool) async throws -> Data
    func pruneContainers() async throws -> Data
    func pruneVolumes() async throws -> Data
    func pruneNetworks() async throws -> Data
    func createVolume(name: String, size: String?, labels: [String: String]) async throws -> Data
    func deleteVolumes(_ names: [String]) async throws -> Data
    func createNetwork(name: String, subnet: String?, internalOnly: Bool,
                       labels: [String: String]) async throws -> Data
    func deleteNetworks(_ names: [String]) async throws -> Data
}

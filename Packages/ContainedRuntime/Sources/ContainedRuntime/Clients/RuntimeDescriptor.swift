import Foundation
import ContainedCore

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
    public static let composeImport = RuntimeCapability(rawValue: 1 << 16)
    public static let coreMigration = RuntimeCapability(rawValue: 1 << 17)

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
        .composeImport,
    ]
}

public struct RuntimeDescriptor: Equatable, Sendable {
    public var kind: RuntimeKind
    public var displayName: String
    public var executableName: String?
    public var capabilities: RuntimeCapability

    public init(kind: RuntimeKind,
                displayName: String,
                executableName: String? = nil,
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

extension UnsupportedRuntimeCapability: ContainedPackageError {
    public var packageName: String { "ContainedRuntime" }
    public var packageErrorCode: String { "unsupportedRuntimeCapability" }
    public var packageErrorContext: [String: String] {
        [
            "kind": kind.rawValue,
            "capability": String(capability.rawValue),
        ]
    }
}

public protocol ContainerRuntimeClient: Sendable {
    var descriptor: RuntimeDescriptor { get }

    func listContainers(all: Bool) async throws -> [ContainerSnapshot]
    func stats(ids: [String]) async throws -> [ContainerStats]
    func streamStats(ids: [String]) -> AsyncThrowingStream<[RuntimeStatsSnapshot], Error>
    func diskUsage() async throws -> DiskUsage
    func systemProperties() async throws -> SystemProperties
    func dnsDomains() async throws -> [String]
    @discardableResult func createDNSDomain(_ domain: String) async throws -> Data
    @discardableResult func deleteDNSDomain(_ domain: String) async throws -> Data
    @discardableResult func setRecommendedKernel() async throws -> Data
    func execCapture(_ id: String, _ command: [String]) async throws -> String
    @discardableResult func copy(source: String, destination: String) async throws -> Data
    func streamSystemLogs(follow: Bool, last: Int?) -> AsyncThrowingStream<String, Error>
    func previewCreateCommand(for request: ContainerCreateRequest) throws -> RuntimeCommandPreview
    @discardableResult func createContainer(_ request: ContainerCreateRequest) async throws -> ContainerCreateResult
    func translateCompose(_ project: ComposeProject, baseDirectory: URL?) throws -> RuntimeComposeImportPlan
    func imageDefaults(for request: ContainerCreateRequest, in images: [ImageResource]) throws -> ContainerImageDefaults?
    func coreSwitchPlan(for containerID: String, to target: RuntimeDescriptor?) throws -> RuntimeCoreSwitchPlan
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
    @discardableResult func runContainer(arguments: [String]) async throws -> Data
    @discardableResult func performSystemAction(_ action: String) async throws -> Data
    func registries() async throws -> [RegistryLogin]
    @discardableResult func registryLogin(server: String, username: String, password: String) async throws -> Data
    @discardableResult func registryLogout(server: String) async throws -> Data
    @discardableResult func deleteImages(_ refs: [String]) async throws -> Data
    @discardableResult func tagImage(source: String, target: String) async throws -> Data
    @discardableResult func saveImages(_ refs: [String], to output: String) async throws -> Data
    @discardableResult func loadImages(from input: String) async throws -> Data
    @discardableResult func exportContainer(_ id: String, to output: String) async throws -> Data
    @discardableResult func pruneImages(all: Bool) async throws -> Data
    @discardableResult func start(_ ids: [String]) async throws -> Data
    @discardableResult func stop(_ ids: [String]) async throws -> Data
    @discardableResult func deleteContainers(_ ids: [String], force: Bool) async throws -> Data
    @discardableResult func pruneContainers() async throws -> Data
    @discardableResult func pruneVolumes() async throws -> Data
    @discardableResult func pruneNetworks() async throws -> Data
    @discardableResult func createVolume(name: String, size: String?, labels: [String: String]) async throws -> Data
    @discardableResult func deleteVolumes(_ names: [String]) async throws -> Data
    @discardableResult func createNetwork(name: String, subnet: String?, internalOnly: Bool,
                       labels: [String: String]) async throws -> Data
    @discardableResult func deleteNetworks(_ names: [String]) async throws -> Data
}

public extension ContainerRuntimeClient {
    func listContainers() async throws -> [ContainerSnapshot] {
        try await listContainers(all: true)
    }

    func stats() async throws -> [ContainerStats] {
        try await stats(ids: [])
    }

    func streamStats() -> AsyncThrowingStream<[RuntimeStatsSnapshot], Error> {
        streamStats(ids: [])
    }

    func streamLogs(id: String, follow: Bool, tail: Int?) -> AsyncThrowingStream<String, Error> {
        streamLogs(id: id, follow: follow, tail: tail, boot: false)
    }

    func streamLogs(id: String) -> AsyncThrowingStream<String, Error> {
        streamLogs(id: id, follow: true, tail: 200, boot: false)
    }

    func streamPull(_ ref: String) -> AsyncThrowingStream<String, Error> {
        streamPull(ref, platform: nil)
    }

    func streamPush(_ ref: String) -> AsyncThrowingStream<String, Error> {
        streamPush(ref, platform: nil)
    }

    func previewCreateCommand(for request: ContainerCreateRequest) throws -> RuntimeCommandPreview {
        throw UnsupportedRuntimeCapability(kind: descriptor.kind, capability: .containers)
    }

    @discardableResult func createContainer(_ request: ContainerCreateRequest) async throws -> ContainerCreateResult {
        throw UnsupportedRuntimeCapability(kind: descriptor.kind, capability: .containers)
    }

    @discardableResult func recreateContainer(originalID: String,
                                             request: ContainerCreateRequest) async throws -> ContainerCreateResult {
        _ = try? await stop([originalID])
        _ = try await deleteContainers([originalID], force: true)
        return try await createContainer(request)
    }

    func translateCompose(_ project: ComposeProject, baseDirectory: URL? = nil) throws -> RuntimeComposeImportPlan {
        throw UnsupportedRuntimeCapability(kind: descriptor.kind, capability: .composeImport)
    }

    func imageDefaults(for request: ContainerCreateRequest, in images: [ImageResource]) throws -> ContainerImageDefaults? {
        nil
    }

    func coreSwitchPlan(for containerID: String, to target: RuntimeDescriptor?) throws -> RuntimeCoreSwitchPlan {
        RuntimeCoreSwitchPlan(
            isAvailable: false,
            unavailableReason: .exportImportUnsupported,
            context: [
                "source": descriptor.kind.rawValue,
                "target": target?.kind.rawValue ?? "",
            ],
            source: descriptor.kind,
            target: target?.kind
        )
    }

    @discardableResult func createVolume(name: String, size: String?) async throws -> Data {
        try await createVolume(name: name, size: size, labels: [:])
    }

    @discardableResult func createVolume(name: String) async throws -> Data {
        try await createVolume(name: name, size: nil, labels: [:])
    }

    @discardableResult func createNetwork(name: String, subnet: String?, internalOnly: Bool) async throws -> Data {
        try await createNetwork(name: name, subnet: subnet, internalOnly: internalOnly, labels: [:])
    }

    @discardableResult func createNetwork(name: String) async throws -> Data {
        try await createNetwork(name: name, subnet: nil, internalOnly: false, labels: [:])
    }
}

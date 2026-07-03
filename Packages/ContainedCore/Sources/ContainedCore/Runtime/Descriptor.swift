import Foundation

public extension Core.Runtime {
struct Capability: OptionSet, Equatable, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public static let containers = Core.Runtime.Capability(rawValue: 1 << 0)
    public static let images = Core.Runtime.Capability(rawValue: 1 << 1)
    public static let imageBuild = Core.Runtime.Capability(rawValue: 1 << 2)
    public static let imagePush = Core.Runtime.Capability(rawValue: 1 << 3)
    public static let imageArchive = Core.Runtime.Capability(rawValue: 1 << 4)
    public static let registries = Core.Runtime.Capability(rawValue: 1 << 5)
    public static let networks = Core.Runtime.Capability(rawValue: 1 << 6)
    public static let volumes = Core.Runtime.Capability(rawValue: 1 << 7)
    public static let systemStatus = Core.Runtime.Capability(rawValue: 1 << 8)
    public static let systemLogs = Core.Runtime.Capability(rawValue: 1 << 9)
    public static let systemProperties = Core.Runtime.Capability(rawValue: 1 << 10)
    public static let dnsManagement = Core.Runtime.Capability(rawValue: 1 << 11)
    public static let kernelManagement = Core.Runtime.Capability(rawValue: 1 << 12)
    public static let exec = Core.Runtime.Capability(rawValue: 1 << 13)
    public static let copy = Core.Runtime.Capability(rawValue: 1 << 14)
    public static let containerExport = Core.Runtime.Capability(rawValue: 1 << 15)
    public static let composeImport = Core.Runtime.Capability(rawValue: 1 << 16)
    public static let coreMigration = Core.Runtime.Capability(rawValue: 1 << 17)

    public static let appleContainer: Core.Runtime.Capability = [
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

struct Descriptor: Equatable, Sendable {
    public var kind: Core.Runtime.Kind
    public var displayName: String
    public var executableName: String?
    public var capabilities: Core.Runtime.Capability

    public init(kind: Core.Runtime.Kind,
                displayName: String,
                executableName: String? = nil,
                capabilities: Core.Runtime.Capability) {
        self.kind = kind
        self.displayName = displayName
        self.executableName = executableName
        self.capabilities = capabilities
    }

    public func supports(_ capability: Core.Runtime.Capability) -> Bool {
        capabilities.isSuperset(of: capability)
    }

    public func require(_ capability: Core.Runtime.Capability) throws {
        guard supports(capability) else {
            throw Core.Runtime.UnsupportedCapability(kind: kind, capability: capability)
        }
    }

    public static let appleContainer = Core.Runtime.Descriptor(
        kind: .appleContainer,
        displayName: "Apple container",
        executableName: "container",
        capabilities: .appleContainer
    )
}

struct UnsupportedCapability: Error, Equatable, Sendable {
    public var kind: Core.Runtime.Kind
    public var capability: Core.Runtime.Capability

    public init(kind: Core.Runtime.Kind, capability: Core.Runtime.Capability) {
        self.kind = kind
        self.capability = capability
    }
}

}

extension Core.Runtime.UnsupportedCapability: Core.Error.PackageError {
    public var packageName: String { "ContainedCore" }
    public var packageErrorCode: String { "unsupportedRuntimeCapability" }
    public var packageErrorContext: [String: String] {
        [
            "kind": kind.rawValue,
            "capability": String(capability.rawValue),
        ]
    }
}

public extension Core.Runtime {
enum SystemAction: String, CaseIterable, Sendable {
    case start
    case stop
}
}

protocol ContainerRuntimeClient: Sendable {
    var descriptor: Core.Runtime.Descriptor { get }

    func listContainers(all: Bool) async throws -> [Core.Container.Snapshot]
    func stats(ids: [String]) async throws -> [Core.Metrics.ContainerStats]
    func streamStats(ids: [String]) -> AsyncThrowingStream<[Core.Metrics.RuntimeStatsSnapshot], Error>
    func diskUsage() async throws -> Core.System.DiskUsage
    func systemProperties() async throws -> Core.System.Properties
    func dnsDomains() async throws -> [String]
    @discardableResult func createDNSDomain(_ domain: String) async throws -> Data
    @discardableResult func deleteDNSDomain(_ domain: String) async throws -> Data
    @discardableResult func setRecommendedKernel() async throws -> Data
    func execCapture(_ id: String, _ command: [String]) async throws -> String
    @discardableResult func copy(source: String, destination: String) async throws -> Data
    func streamSystemLogs(follow: Bool, last: Int?) -> AsyncThrowingStream<String, Error>
    func previewCreateCommand(for request: Core.Container.CreateRequest) throws -> Core.Command.Preview
    @discardableResult func createContainer(_ request: Core.Container.CreateRequest) async throws -> Core.Container.CreateResult
    func translateCompose(_ project: Core.Compose.Project, baseDirectory: URL?) throws -> Core.Compose.ImportPlan
    func imageDefaults(for request: Core.Container.CreateRequest, in images: [Core.Image.Resource]) throws -> Core.Container.ImageDefaults?
    func coreSwitchPlan(for containerID: String, to target: Core.Runtime.Descriptor?) throws -> Core.Migration.Plan
    func systemStatus() async throws -> Core.System.Status
    func networks() async throws -> [Core.Network.Resource]
    func volumes() async throws -> [Core.Volume.Resource]
    func images() async throws -> [Core.Image.Resource]
    func inspectImage(_ ref: String) async throws -> [Core.Image.Resource]
    func streamLogs(id: String, follow: Bool, tail: Int?, boot: Bool) -> AsyncThrowingStream<String, Error>
    func streamPull(_ ref: String, platform: String?) -> AsyncThrowingStream<String, Error>
    func streamBuild(context: String, tag: String?, dockerfile: String?,
                     buildArgs: [String: String], noCache: Bool,
                     platform: String?) -> AsyncThrowingStream<String, Error>
    func streamPush(_ ref: String, platform: String?) -> AsyncThrowingStream<String, Error>
    @discardableResult func runContainer(arguments: [String]) async throws -> Data
    @discardableResult func performSystemAction(_ action: Core.Runtime.SystemAction) async throws -> Data
    func registries() async throws -> [Core.Registry.Login]
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

extension ContainerRuntimeClient {
    func listContainers() async throws -> [Core.Container.Snapshot] {
        try await listContainers(all: true)
    }

    func stats() async throws -> [Core.Metrics.ContainerStats] {
        try await stats(ids: [])
    }

    func streamStats() -> AsyncThrowingStream<[Core.Metrics.RuntimeStatsSnapshot], Error> {
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

    func previewCreateCommand(for request: Core.Container.CreateRequest) throws -> Core.Command.Preview {
        throw Core.Runtime.UnsupportedCapability(kind: descriptor.kind, capability: .containers)
    }

    @discardableResult func createContainer(_ request: Core.Container.CreateRequest) async throws -> Core.Container.CreateResult {
        throw Core.Runtime.UnsupportedCapability(kind: descriptor.kind, capability: .containers)
    }

    @discardableResult func recreateContainer(originalID: String,
                                             request: Core.Container.CreateRequest) async throws -> Core.Container.CreateResult {
        _ = try? await stop([originalID])
        _ = try await deleteContainers([originalID], force: true)
        return try await createContainer(request)
    }

    func translateCompose(_ project: Core.Compose.Project, baseDirectory: URL? = nil) throws -> Core.Compose.ImportPlan {
        throw Core.Runtime.UnsupportedCapability(kind: descriptor.kind, capability: .composeImport)
    }

    func imageDefaults(for request: Core.Container.CreateRequest, in images: [Core.Image.Resource]) throws -> Core.Container.ImageDefaults? {
        nil
    }

    func coreSwitchPlan(for containerID: String, to target: Core.Runtime.Descriptor?) throws -> Core.Migration.Plan {
        Core.Migration.Plan(
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

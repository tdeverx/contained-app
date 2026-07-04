import Foundation

protocol RuntimeDescribing: Sendable {
    var descriptor: Core.Runtime.Descriptor { get }
}

protocol RuntimeContainerClient: RuntimeDescribing {
    func listContainers(all: Bool) async throws -> [Core.Container.Snapshot]
    func stats(ids: [String]) async throws -> [Core.Metrics.ContainerStats]
    func streamStats(ids: [String]) -> AsyncThrowingStream<[Core.Metrics.RuntimeStatsSnapshot], Error>
    func streamLogs(id: String, follow: Bool, tail: Int?, boot: Bool) -> AsyncThrowingStream<String, Error>
    func previewCreateCommand(for request: Core.Container.CreateRequest) throws -> Core.Command.Preview
    @discardableResult func createContainer(_ request: Core.Container.CreateRequest) async throws -> Core.Container.CreateResult
    @discardableResult func runContainer(arguments: [String]) async throws -> Data
    @discardableResult func start(_ ids: [String]) async throws -> Data
    @discardableResult func stop(_ ids: [String]) async throws -> Data
    @discardableResult func deleteContainers(_ ids: [String], force: Bool) async throws -> Data
    @discardableResult func pruneContainers() async throws -> Data
}

protocol RuntimeSystemStatusClient: RuntimeDescribing {
    func diskUsage() async throws -> Core.System.DiskUsage
    func systemProperties() async throws -> Core.System.Properties
    func systemStatus() async throws -> Core.System.Status
}

protocol RuntimeDNSClient: RuntimeDescribing {
    func dnsDomains() async throws -> [String]
    @discardableResult func createDNSDomain(_ domain: String) async throws -> Data
    @discardableResult func deleteDNSDomain(_ domain: String) async throws -> Data
}

protocol RuntimeKernelClient: RuntimeDescribing {
    @discardableResult func setRecommendedKernel() async throws -> Data
}

protocol RuntimeExecClient: RuntimeDescribing {
    func execCapture(_ id: String, _ command: [String]) async throws -> String
    @discardableResult func copy(source: String, destination: String) async throws -> Data
}

protocol RuntimeSystemLogsClient: RuntimeDescribing {
    func streamSystemLogs(follow: Bool, last: Int?) -> AsyncThrowingStream<String, Error>
}

protocol RuntimeComposeClient: RuntimeDescribing {
    func translateCompose(_ project: Core.Compose.Project, baseDirectory: URL?) throws -> Core.Compose.ImportPlan
    func imageDefaults(for request: Core.Container.CreateRequest, in images: [Core.Image.Resource]) throws -> Core.Container.ImageDefaults?
    func coreSwitchPlan(for containerID: String, to target: Core.Runtime.Descriptor?) throws -> Core.Migration.Plan
}

protocol RuntimeNetworkClient: RuntimeDescribing {
    func networks() async throws -> [Core.Network.Resource]
    @discardableResult func pruneNetworks() async throws -> Data
    @discardableResult func createNetwork(name: String, subnet: String?, internalOnly: Bool,
                       labels: [String: String]) async throws -> Data
    @discardableResult func deleteNetworks(_ names: [String]) async throws -> Data
}

protocol RuntimeVolumeClient: RuntimeDescribing {
    func volumes() async throws -> [Core.Volume.Resource]
    @discardableResult func pruneVolumes() async throws -> Data
    @discardableResult func createVolume(name: String, size: String?, labels: [String: String]) async throws -> Data
    @discardableResult func deleteVolumes(_ names: [String]) async throws -> Data
}

protocol RuntimeImageClient: RuntimeDescribing {
    func images() async throws -> [Core.Image.Resource]
    func inspectImage(_ ref: String) async throws -> [Core.Image.Resource]
    func streamPull(_ ref: String, platform: String?) -> AsyncThrowingStream<String, Error>
    func streamBuild(context: String, tag: String?, dockerfile: String?,
                     buildArgs: [String: String], noCache: Bool,
                     platform: String?) -> AsyncThrowingStream<String, Error>
    func streamPush(_ ref: String, platform: String?) -> AsyncThrowingStream<String, Error>
    @discardableResult func deleteImages(_ refs: [String]) async throws -> Data
    @discardableResult func tagImage(source: String, target: String) async throws -> Data
    @discardableResult func saveImages(_ refs: [String], to output: String) async throws -> Data
    @discardableResult func loadImages(from input: String) async throws -> Data
    @discardableResult func exportContainer(_ id: String, to output: String) async throws -> Data
    @discardableResult func pruneImages(all: Bool) async throws -> Data
}

protocol RuntimeRegistryClient: RuntimeDescribing {
    func registries() async throws -> [Core.Registry.Login]
    @discardableResult func registryLogin(server: String, username: String, password: String) async throws -> Data
    @discardableResult func registryLogout(server: String) async throws -> Data
}

protocol RuntimeServiceControlClient: RuntimeDescribing {
    @discardableResult func performSystemAction(_ action: Core.Runtime.SystemAction) async throws -> Data
}

protocol RuntimeClient: RuntimeDescribing {}

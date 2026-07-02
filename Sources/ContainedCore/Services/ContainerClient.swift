import Foundation

/// Typed facade over a `CommandRunning`. Returns decoded models; maps decode failures to
/// `CommandError.decodingFailed` so callers handle one error type.
public struct ContainerClient: Sendable {
    public let runner: any CommandRunning
    public var descriptor: RuntimeDescriptor { .appleContainer }

    public init(runner: any CommandRunning) {
        self.runner = runner
    }

    // MARK: Reads

    public func listContainers(all: Bool = true) async throws -> [ContainerSnapshot] {
        try await decode([ContainerSnapshot].self, ContainerCommands.list(all: all), "list")
    }

    public func stats(ids: [String] = []) async throws -> [ContainerStats] {
        try await decode([ContainerStats].self,
                         ContainerCommands.stats(ids: ids),
                         "stats",
                         priority: .utility)
    }

    public func streamStatsTable(ids: [String] = []) -> AsyncThrowingStream<String, Error> {
        runner.stream(ContainerCommands.statsTableStream(ids: ids), priority: .utility)
    }

    public func diskUsage() async throws -> DiskUsage {
        try await decode(DiskUsage.self, ContainerCommands.systemDF, "system df")
    }

    public func systemProperties() async throws -> SystemProperties {
        try await decode(SystemProperties.self, ContainerCommands.systemPropertyList, "system property list")
    }

    /// List local DNS domains (`system dns list`). Returns domain names.
    public func dnsDomains() async throws -> [String] {
        try await decode([String].self, ContainerCommands.systemDNSList, "system dns list")
    }
    @discardableResult public func createDNSDomain(_ domain: String) async throws -> Data {
        try await runner.run(ContainerCommands.systemDNSCreate(domain))
    }
    @discardableResult public func deleteDNSDomain(_ domain: String) async throws -> Data {
        try await runner.run(ContainerCommands.systemDNSDelete(domain))
    }
    /// Install the recommended kernel (`system kernel set --recommended`).
    @discardableResult public func setRecommendedKernel() async throws -> Data {
        try await runner.run(ContainerCommands.systemKernelSetRecommended)
    }

    /// Capture the output of a one-shot `exec` (no TTY) — e.g. `ps`, `ls -la`.
    public func execCapture(_ id: String, _ command: [String]) async throws -> String {
        let data = try await runner.run(ContainerCommands.exec(id, command))
        return String(decoding: data, as: UTF8.self)
    }

    /// Copy between host and container. Paths are `container-id:path` or local.
    @discardableResult public func copy(source: String, destination: String) async throws -> Data {
        try await runner.run(ContainerCommands.copy(source: source, destination: destination))
    }

    /// Stream `system logs` (service logs). With `follow`, runs until cancelled.
    public func streamSystemLogs(follow: Bool, last: Int? = 500) -> AsyncThrowingStream<String, Error> {
        runner.stream(ContainerCommands.systemLogs(follow: follow, last: last))
    }

    public func systemStatus() async throws -> SystemStatus {
        try await decode(SystemStatus.self, ContainerCommands.systemStatus, "system status")
    }

    public func networks() async throws -> [NetworkResource] {
        try await decode([NetworkResource].self, ContainerCommands.networkList(), "network list")
    }

    public func volumes() async throws -> [VolumeResource] {
        try await decode([VolumeResource].self, ContainerCommands.volumeList(), "volume list")
    }

    public func images() async throws -> [ImageResource] {
        try await decode([ImageResource].self, ContainerCommands.imageList(), "image list")
    }

    public func inspectImage(_ ref: String) async throws -> [ImageResource] {
        try await decode([ImageResource].self, ContainerCommands.imageInspect([ref]), "image inspect")
    }

    // MARK: Streaming

    /// Stream a container's logs. The CLI emits merged stdout/stderr; lines arrive as they're produced.
    /// Cancelling the consuming task terminates the child process (no leaked `logs -f`).
    public func streamLogs(id: String, follow: Bool = true, tail: Int? = 200, boot: Bool = false)
        -> AsyncThrowingStream<String, Error> {
        runner.stream(ContainerCommands.logs(id, follow: follow, tail: tail, boot: boot))
    }

    /// Stream `image pull --progress plain` output as it downloads.
    public func streamPull(_ ref: String, platform: String? = nil) -> AsyncThrowingStream<String, Error> {
        runner.stream(ContainerCommands.imagePull(ref, platform: platform))
    }

    /// Stream `container build --progress plain` (BuildKit log).
    public func streamBuild(context: String, tag: String? = nil, dockerfile: String? = nil,
                            buildArgs: [String: String] = [:], noCache: Bool = false,
                            platform: String? = nil) -> AsyncThrowingStream<String, Error> {
        runner.stream(ContainerCommands.build(context: context, tag: tag, dockerfile: dockerfile,
                                              buildArgs: buildArgs, noCache: noCache, platform: platform))
    }

    /// Stream `image push --progress plain` to a logged-in registry.
    public func streamPush(_ ref: String, platform: String? = nil) -> AsyncThrowingStream<String, Error> {
        runner.stream(ContainerCommands.imagePush(ref, platform: platform))
    }

    // MARK: Registries

    public func registries() async throws -> [RegistryLogin] {
        try await decode([RegistryLogin].self, ContainerCommands.registryList(), "registry list")
    }

    /// Log in to `server` as `username`, piping `password` via stdin (never in argv).
    @discardableResult public func registryLogin(server: String, username: String, password: String) async throws -> Data {
        try await runner.run(ContainerCommands.registryLogin(server: server, username: username),
                             stdin: Data(password.utf8))
    }
    @discardableResult public func registryLogout(server: String) async throws -> Data {
        try await runner.run(ContainerCommands.registryLogout(server: server))
    }

    // MARK: Image writes

    @discardableResult public func deleteImages(_ refs: [String]) async throws -> Data {
        try await runner.run(ContainerCommands.imageDelete(refs))
    }
    @discardableResult public func tagImage(source: String, target: String) async throws -> Data {
        try await runner.run(ContainerCommands.imageTag(source: source, target: target))
    }
    @discardableResult public func saveImages(_ refs: [String], to output: String) async throws -> Data {
        try await runner.run(ContainerCommands.imageSave(refs: refs, output: output))
    }
    @discardableResult public func loadImages(from input: String) async throws -> Data {
        try await runner.run(ContainerCommands.imageLoad(input: input))
    }
    /// Export a container's filesystem as a tar archive (not an OCI image).
    @discardableResult public func exportContainer(_ id: String, to output: String) async throws -> Data {
        try await runner.run(ContainerCommands.containerExport(id, output: output))
    }
    @discardableResult public func pruneImages(all: Bool = false) async throws -> Data {
        try await runner.run(ContainerCommands.imagePrune(all: all))
    }

    // MARK: Lifecycle (fire-and-forget; throw on failure)

    @discardableResult public func start(_ ids: [String]) async throws -> Data {
        try await runner.run(ContainerCommands.start(ids))
    }
    @discardableResult public func stop(_ ids: [String]) async throws -> Data {
        try await runner.run(ContainerCommands.stop(ids))
    }
    @discardableResult public func deleteContainers(_ ids: [String], force: Bool) async throws -> Data {
        try await runner.run(ContainerCommands.deleteContainers(ids, force: force))
    }
    @discardableResult public func pruneContainers() async throws -> Data {
        try await runner.run(ContainerCommands.containerPrune())
    }
    @discardableResult public func pruneVolumes() async throws -> Data {
        try await runner.run(ContainerCommands.volumePrune())
    }
    @discardableResult public func pruneNetworks() async throws -> Data {
        try await runner.run(ContainerCommands.networkPrune())
    }

    // MARK: Infra writes

    @discardableResult public func createVolume(name: String, size: String? = nil,
                                                labels: [String: String] = [:]) async throws -> Data {
        try await runner.run(ContainerCommands.volumeCreate(name: name, size: size, labels: labels))
    }
    @discardableResult public func deleteVolumes(_ names: [String]) async throws -> Data {
        try await runner.run(ContainerCommands.volumeDelete(names))
    }
    @discardableResult public func createNetwork(name: String, subnet: String? = nil, internalOnly: Bool = false,
                                                 labels: [String: String] = [:]) async throws -> Data {
        try await runner.run(ContainerCommands.networkCreate(name: name, subnet: subnet,
                                                             internalOnly: internalOnly, labels: labels))
    }
    @discardableResult public func deleteNetworks(_ names: [String]) async throws -> Data {
        try await runner.run(ContainerCommands.networkDelete(names))
    }

    // MARK: Helpers

    private func decode<T: Decodable>(_ type: T.Type,
                                      _ args: [String],
                                      _ name: String,
                                      priority: CommandExecutionPriority = .userInitiated) async throws -> T {
        let data = try await runner.run(args, stdin: nil, priority: priority)
        do {
            return try ContainerJSON.decode(type, from: data)
        } catch {
            throw CommandError.decodingFailed(underlying: String(describing: error), command: name)
        }
    }
}

extension ContainerClient: ContainerRuntimeClient {}

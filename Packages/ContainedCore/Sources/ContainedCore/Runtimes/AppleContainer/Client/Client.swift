import Foundation

/// Typed facade over a `CommandRunning`. Returns decoded models; maps decode failures to
/// `CommandError.decodingFailed` so callers handle one error type.
struct AppleContainerClient: Sendable {
    let runner: any CommandRunning
    var descriptor: RuntimeDescriptor { .appleContainer }

    init(runner: any CommandRunning) {
        self.runner = runner
    }

    // MARK: Reads

    func listContainers(all: Bool = true) async throws -> [ContainerSnapshot] {
        try await decode([ContainerSnapshot].self, ContainerCommands.list(all: all), "list")
    }

    func stats(ids: [String] = []) async throws -> [ContainerStats] {
        try await decode([ContainerStats].self,
                         ContainerCommands.stats(ids: ids),
                         "stats",
                         priority: .utility)
    }

    private func statsTableStream(ids: [String] = []) -> AsyncThrowingStream<String, Error> {
        runner.stream(ContainerCommands.statsTableStream(ids: ids), priority: .utility)
    }

    func streamStats(ids: [String] = []) -> AsyncThrowingStream<[RuntimeStatsSnapshot], Error> {
        let source = statsTableStream(ids: ids)
        return AsyncThrowingStream { continuation in
            let task = Task(priority: .utility) {
                var parser = ContainerStatsTableParser()
                do {
                    for try await chunk in source {
                        try Task.checkCancellation()
                        let samples = parser.append(chunk)
                        if !samples.isEmpty { continuation.yield(samples) }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func diskUsage() async throws -> DiskUsage {
        try await decode(DiskUsage.self, ContainerCommands.systemDF, "system df")
    }

    func systemProperties() async throws -> SystemProperties {
        try await decode(SystemProperties.self, ContainerCommands.systemPropertyList, "system property list")
    }

    /// List local DNS domains (`system dns list`). Returns domain names.
    func dnsDomains() async throws -> [String] {
        try await decode([String].self, ContainerCommands.systemDNSList, "system dns list")
    }
    @discardableResult func createDNSDomain(_ domain: String) async throws -> Data {
        try await runner.run(ContainerCommands.systemDNSCreate(domain))
    }
    @discardableResult func deleteDNSDomain(_ domain: String) async throws -> Data {
        try await runner.run(ContainerCommands.systemDNSDelete(domain))
    }
    /// Install the recommended kernel (`system kernel set --recommended`).
    @discardableResult func setRecommendedKernel() async throws -> Data {
        try await runner.run(ContainerCommands.systemKernelSetRecommended)
    }

    /// Capture the output of a one-shot `exec` (no TTY) — e.g. `ps`, `ls -la`.
    func execCapture(_ id: String, _ command: [String]) async throws -> String {
        let data = try await runner.run(ContainerCommands.exec(id, command))
        return String(decoding: data, as: UTF8.self)
    }

    /// Copy between host and container. Paths are `container-id:path` or local.
    @discardableResult func copy(source: String, destination: String) async throws -> Data {
        try await runner.run(ContainerCommands.copy(source: source, destination: destination))
    }

    /// Stream `system logs` (service logs). With `follow`, runs until cancelled.
    func streamSystemLogs(follow: Bool, last: Int? = 500) -> AsyncThrowingStream<String, Error> {
        runner.stream(ContainerCommands.systemLogs(follow: follow, last: last))
    }

    func systemStatus() async throws -> SystemStatus {
        try await decode(SystemStatus.self, ContainerCommands.systemStatus, "system status")
    }

    func previewCreateCommand(for request: ContainerCreateRequest) throws -> RuntimeCommandPreview {
        AppleContainerCreateTranslator.preview(for: request)
    }

    @discardableResult func createContainer(_ request: ContainerCreateRequest) async throws -> ContainerCreateResult {
        let data = try await runner.run(ContainerCommands.run(request))
        return AppleContainerCreateTranslator.result(from: data, request: request)
    }

    func translateCompose(_ project: ComposeProject, baseDirectory: URL?) throws -> RuntimeComposeImportPlan {
        AppleContainerCreateTranslator.composePlan(for: project, baseDirectory: baseDirectory)
    }

    func imageDefaults(for request: ContainerCreateRequest,
                              in images: [ImageResource]) throws -> ContainerImageDefaults? {
        AppleContainerCreateTranslator.imageDefaults(for: request, in: images)
    }

    func networks() async throws -> [NetworkResource] {
        try await decode([NetworkResource].self, ContainerCommands.networkList(), "network list")
    }

    func volumes() async throws -> [VolumeResource] {
        try await decode([VolumeResource].self, ContainerCommands.volumeList(), "volume list")
    }

    func images() async throws -> [ImageResource] {
        try await decode([ImageResource].self, ContainerCommands.imageList(), "image list")
    }

    func inspectImage(_ ref: String) async throws -> [ImageResource] {
        try await decode([ImageResource].self, ContainerCommands.imageInspect([ref]), "image inspect")
    }

    // MARK: Streaming

    /// Stream a container's logs. The CLI emits merged stdout/stderr; lines arrive as they're produced.
    /// Cancelling the consuming task terminates the child process (no leaked `logs -f`).
    func streamLogs(id: String, follow: Bool = true, tail: Int? = 200, boot: Bool = false)
        -> AsyncThrowingStream<String, Error> {
        runner.stream(ContainerCommands.logs(id, follow: follow, tail: tail, boot: boot))
    }

    /// Stream `image pull --progress plain` output as it downloads.
    func streamPull(_ ref: String, platform: String? = nil) -> AsyncThrowingStream<String, Error> {
        runner.stream(ContainerCommands.imagePull(ref, platform: platform))
    }

    /// Stream `container build --progress plain` (BuildKit log).
    func streamBuild(context: String, tag: String? = nil, dockerfile: String? = nil,
                            buildArgs: [String: String] = [:], noCache: Bool = false,
                            platform: String? = nil) -> AsyncThrowingStream<String, Error> {
        runner.stream(ContainerCommands.build(context: context, tag: tag, dockerfile: dockerfile,
                                              buildArgs: buildArgs, noCache: noCache, platform: platform))
    }

    /// Stream `image push --progress plain` to a logged-in registry.
    func streamPush(_ ref: String, platform: String? = nil) -> AsyncThrowingStream<String, Error> {
        runner.stream(ContainerCommands.imagePush(ref, platform: platform))
    }

    @discardableResult func runContainer(arguments: [String]) async throws -> Data {
        try await runner.run(arguments)
    }

    @discardableResult func performSystemAction(_ action: RuntimeSystemAction) async throws -> Data {
        try await runner.run(["system", action.rawValue])
    }

    // MARK: Registries

    func registries() async throws -> [RegistryLogin] {
        try await decode([RegistryLogin].self, ContainerCommands.registryList(), "registry list")
    }

    /// Log in to `server` as `username`, piping `password` via stdin (never in argv).
    @discardableResult func registryLogin(server: String, username: String, password: String) async throws -> Data {
        try await runner.run(ContainerCommands.registryLogin(server: server, username: username),
                             stdin: Data(password.utf8))
    }
    @discardableResult func registryLogout(server: String) async throws -> Data {
        try await runner.run(ContainerCommands.registryLogout(server: server))
    }

    // MARK: Image writes

    @discardableResult func deleteImages(_ refs: [String]) async throws -> Data {
        try await runner.run(ContainerCommands.imageDelete(refs))
    }
    @discardableResult func tagImage(source: String, target: String) async throws -> Data {
        try await runner.run(ContainerCommands.imageTag(source: source, target: target))
    }
    @discardableResult func saveImages(_ refs: [String], to output: String) async throws -> Data {
        try await runner.run(ContainerCommands.imageSave(refs: refs, output: output))
    }
    @discardableResult func loadImages(from input: String) async throws -> Data {
        try await runner.run(ContainerCommands.imageLoad(input: input))
    }
    /// Export a container's filesystem as a tar archive (not an OCI image).
    @discardableResult func exportContainer(_ id: String, to output: String) async throws -> Data {
        try await runner.run(ContainerCommands.containerExport(id, output: output))
    }
    @discardableResult func pruneImages(all: Bool = false) async throws -> Data {
        try await runner.run(ContainerCommands.imagePrune(all: all))
    }

    // MARK: Lifecycle (fire-and-forget; throw on failure)

    @discardableResult func start(_ ids: [String]) async throws -> Data {
        try await runner.run(ContainerCommands.start(ids))
    }
    @discardableResult func stop(_ ids: [String]) async throws -> Data {
        try await runner.run(ContainerCommands.stop(ids))
    }
    @discardableResult func deleteContainers(_ ids: [String], force: Bool) async throws -> Data {
        try await runner.run(ContainerCommands.deleteContainers(ids, force: force))
    }
    @discardableResult func pruneContainers() async throws -> Data {
        try await runner.run(ContainerCommands.containerPrune())
    }
    @discardableResult func pruneVolumes() async throws -> Data {
        try await runner.run(ContainerCommands.volumePrune())
    }
    @discardableResult func pruneNetworks() async throws -> Data {
        try await runner.run(ContainerCommands.networkPrune())
    }

    // MARK: Infra writes

    @discardableResult func createVolume(name: String, size: String? = nil,
                                                labels: [String: String] = [:]) async throws -> Data {
        try await runner.run(ContainerCommands.volumeCreate(name: name, size: size, labels: labels))
    }
    @discardableResult func deleteVolumes(_ names: [String]) async throws -> Data {
        try await runner.run(ContainerCommands.volumeDelete(names))
    }
    @discardableResult func createNetwork(name: String, subnet: String? = nil, internalOnly: Bool = false,
                                                 labels: [String: String] = [:]) async throws -> Data {
        try await runner.run(ContainerCommands.networkCreate(name: name, subnet: subnet,
                                                             internalOnly: internalOnly, labels: labels))
    }
    @discardableResult func deleteNetworks(_ names: [String]) async throws -> Data {
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

extension AppleContainerClient: ContainerRuntimeClient {}

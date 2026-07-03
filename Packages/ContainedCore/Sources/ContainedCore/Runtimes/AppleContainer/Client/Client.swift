import Foundation

/// Typed facade over a `Core.Command.Running`. Returns decoded models; maps decode failures to
/// `Core.Command.Error.decodingFailed` so callers handle one error type.
struct AppleContainerClient: Sendable {
    let runner: any Core.Command.Running
    var descriptor: Core.Runtime.Descriptor { .appleContainer }

    init(runner: any Core.Command.Running) {
        self.runner = runner
    }

    // MARK: Reads

    func listContainers(all: Bool = true) async throws -> [Core.Container.Snapshot] {
        try await decode([Core.Container.Snapshot].self, ContainerCommands.list(all: all), "list")
    }

    func stats(ids: [String] = []) async throws -> [Core.Metrics.ContainerStats] {
        try await decode([Core.Metrics.ContainerStats].self,
                         ContainerCommands.stats(ids: ids),
                         "stats",
                         priority: .utility)
    }

    private func statsTableStream(ids: [String] = []) -> AsyncThrowingStream<String, Error> {
        runner.stream(ContainerCommands.statsTableStream(ids: ids), priority: .utility)
    }

    func streamStats(ids: [String] = []) -> AsyncThrowingStream<[Core.Metrics.RuntimeStatsSnapshot], Error> {
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

    func diskUsage() async throws -> Core.System.DiskUsage {
        try await decode(Core.System.DiskUsage.self, ContainerCommands.systemDF, "system df")
    }

    func systemProperties() async throws -> Core.System.Properties {
        try await decode(Core.System.Properties.self, ContainerCommands.systemPropertyList, "system property list")
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

    func systemStatus() async throws -> Core.System.Status {
        try await decode(Core.System.Status.self, ContainerCommands.systemStatus, "system status")
    }

    func previewCreateCommand(for request: Core.Container.CreateRequest) throws -> Core.Command.Preview {
        AppleContainerCreateTranslator.preview(for: request)
    }

    @discardableResult func createContainer(_ request: Core.Container.CreateRequest) async throws -> Core.Container.CreateResult {
        let data = try await runner.run(ContainerCommands.run(request))
        return AppleContainerCreateTranslator.result(from: data, request: request)
    }

    func translateCompose(_ project: Core.Compose.Project, baseDirectory: URL?) throws -> Core.Compose.ImportPlan {
        AppleContainerCreateTranslator.composePlan(for: project, baseDirectory: baseDirectory)
    }

    func imageDefaults(for request: Core.Container.CreateRequest,
                              in images: [Core.Image.Resource]) throws -> Core.Container.ImageDefaults? {
        AppleContainerCreateTranslator.imageDefaults(for: request, in: images)
    }

    func networks() async throws -> [Core.Network.Resource] {
        try await decode([Core.Network.Resource].self, ContainerCommands.networkList(), "network list")
    }

    func volumes() async throws -> [Core.Volume.Resource] {
        try await decode([Core.Volume.Resource].self, ContainerCommands.volumeList(), "volume list")
    }

    func images() async throws -> [Core.Image.Resource] {
        try await decode([Core.Image.Resource].self, ContainerCommands.imageList(), "image list")
    }

    func inspectImage(_ ref: String) async throws -> [Core.Image.Resource] {
        try await decode([Core.Image.Resource].self, ContainerCommands.imageInspect([ref]), "image inspect")
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

    @discardableResult func performSystemAction(_ action: Core.Runtime.SystemAction) async throws -> Data {
        try await runner.run(["system", action.rawValue])
    }

    // MARK: Registries

    func registries() async throws -> [Core.Registry.Login] {
        try await decode([Core.Registry.Login].self, ContainerCommands.registryList(), "registry list")
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
                                      priority: Core.Command.ExecutionPriority = .userInitiated) async throws -> T {
        let data = try await runner.run(args, stdin: nil, priority: priority)
        do {
            return try Core.Container.JSON.decode(type, from: data)
        } catch {
            throw Core.Command.Error.decodingFailed(underlying: String(describing: error), command: name)
        }
    }
}

extension AppleContainerClient: ContainerRuntimeClient {}

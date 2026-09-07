import Foundation

struct DockerClient: Sendable {
    let runner: any Core.Command.Running
    var descriptor: Core.Runtime.Descriptor { .docker }
    var recreateVerificationDelay: Duration { .seconds(1) }

    init(runner: any Core.Command.Running) {
        self.runner = runner
    }

    // MARK: Reads

    func listContainers(all: Bool = true) async throws -> [Core.Container.Snapshot] {
        let data = try await runner.run(DockerCommands.containerIDs(all: all))
        let ids = String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map(String.init)
        guard !ids.isEmpty else { return [] }
        let inspectData = try await runner.run(DockerCommands.inspectContainers(ids))
        return try DockerJSON.decode([DockerContainerInspect].self, from: inspectData)
            .map { try $0.coreSnapshot() }
    }

    func stats(ids: [String] = []) async throws -> [Core.Metrics.ContainerStats] {
        let rows = try await decodeLines(DockerStatsRow.self,
                                         DockerCommands.stats(ids: ids),
                                         "docker stats",
                                         priority: .utility)
        return rows.map { row in
            let sample = row.snapshot
            return Core.Metrics.ContainerStats(id: sample.id,
                                               cpuUsageUsec: nil,
                                               memoryUsageBytes: sample.memoryUsageBytes,
                                               memoryLimitBytes: sample.memoryLimitBytes,
                                               blockReadBytes: sample.blockReadBytes,
                                               blockWriteBytes: sample.blockWriteBytes,
                                               networkRxBytes: sample.networkRxBytes,
                                               networkTxBytes: sample.networkTxBytes,
                                               numProcesses: sample.numProcesses)
        }
    }

    func streamStats(ids: [String] = []) -> AsyncThrowingStream<[Core.Metrics.RuntimeStatsSnapshot], Error> {
        let source = runner.stream(DockerCommands.stats(ids: ids, noStream: false), priority: .utility)
        return AsyncThrowingStream { continuation in
            let task = Task(priority: .utility) {
                var buffer = ""
                do {
                    for try await chunk in source {
                        try Task.checkCancellation()
                        buffer += chunk
                        var lines = buffer.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                        buffer = lines.popLast() ?? ""
                        let samples = lines.compactMap { line -> Core.Metrics.RuntimeStatsSnapshot? in
                            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                  let data = line.data(using: .utf8),
                                  let row = try? DockerJSON.decode(DockerStatsRow.self, from: data) else { return nil }
                            return row.snapshot
                        }
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
        let data = try await runner.run(DockerCommands.systemDF, stdin: nil, priority: .utility)
        let rows = (try? DockerJSON.decodeJSONLines(DockerSystemDFRow.self, from: data)) ?? []
        func category(_ type: String) -> Core.System.DiskUsage.Category {
            guard let row = rows.first(where: { $0.type.caseInsensitiveCompare(type) == .orderedSame }) else {
                return Core.System.DiskUsage.Category(active: 0, total: 0, sizeInBytes: 0, reclaimable: 0)
            }
            return Core.System.DiskUsage.Category(active: row.activeCount,
                                                  total: row.totalCount,
                                                  sizeInBytes: row.sizeBytes,
                                                  reclaimable: row.reclaimableBytes)
        }
        return Core.System.DiskUsage(containers: category("Containers"),
                                     images: category("Images"),
                                     volumes: category("Local Volumes"))
    }

    func systemProperties() async throws -> Core.System.Properties {
        try await decode(DockerInfo.self, DockerCommands.systemStatus, "docker info").systemProperties
    }

    func dnsDomains() async throws -> [String] { throw unsupported(.dnsManagement) }
    @discardableResult func createDNSDomain(_ domain: String) async throws -> Data { throw unsupported(.dnsManagement) }
    @discardableResult func deleteDNSDomain(_ domain: String) async throws -> Data { throw unsupported(.dnsManagement) }
    @discardableResult func setRecommendedKernel() async throws -> Data { throw unsupported(.kernelManagement) }

    func execCapture(_ id: String, _ command: [String]) async throws -> String {
        let data = try await runner.run(DockerCommands.exec(id, command))
        return String(decoding: data, as: UTF8.self)
    }

    @discardableResult func copy(source: String, destination: String) async throws -> Data {
        try await runner.run(DockerCommands.copy(source: source, destination: destination))
    }

    func streamSystemLogs(follow: Bool, last: Int?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: unsupported(.systemLogs))
        }
    }

    func previewCreateCommand(for request: Core.Container.CreateRequest) throws -> Core.Command.Preview {
        DockerCreateTranslator.preview(for: request)
    }

    @discardableResult func createContainer(_ request: Core.Container.CreateRequest) async throws -> Core.Container.CreateResult {
        let data = try await runner.run(DockerCommands.run(request))
        return DockerCreateTranslator.result(from: data, request: request)
    }

    func translateCompose(_ project: Core.Compose.Project, baseDirectory: URL?) throws -> Core.Compose.ImportPlan {
        DockerCreateTranslator.composePlan(for: project, baseDirectory: baseDirectory)
    }

    func imageDefaults(for request: Core.Container.CreateRequest,
                       in images: [Core.Image.Resource]) throws -> Core.Container.ImageDefaults? {
        DockerCreateTranslator.imageDefaults(for: request, in: images.filter { $0.runtimeKind == .docker })
    }

    func coreSwitchPlan(for containerID: String, to target: Core.Runtime.Descriptor?) throws -> Core.Migration.Plan {
        Core.Migration.Plan(isAvailable: false,
                            unavailableReason: .exportImportUnsupported,
                            context: ["source": descriptor.kind.rawValue, "target": target?.kind.rawValue ?? ""],
                            source: descriptor.kind,
                            target: target?.kind)
    }

    func systemStatus() async throws -> Core.System.Status {
        try await decode(DockerInfo.self, DockerCommands.systemStatus, "docker info").systemStatus
    }

    func networks() async throws -> [Core.Network.Resource] {
        try await decodeLines(DockerNetworkRow.self, DockerCommands.networkList(), "docker network ls")
            .map { $0.coreNetwork() }
    }

    func volumes() async throws -> [Core.Volume.Resource] {
        try await decodeLines(DockerVolumeRow.self, DockerCommands.volumeList(), "docker volume ls")
            .map { $0.coreVolume() }
    }

    func images() async throws -> [Core.Image.Resource] {
        try await decodeLines(DockerImageListRow.self, DockerCommands.imageList(), "docker image ls")
            .compactMap { $0.coreImage() }
    }

    func inspectImage(_ ref: String) async throws -> [Core.Image.Resource] {
        try await decode([DockerImageInspect].self, DockerCommands.imageInspect([ref]), "docker image inspect")
            .flatMap { $0.coreImages(fallbackReference: ref) }
    }

    // MARK: Streaming

    func streamLogs(id: String, follow: Bool = true, tail: Int? = 200, boot: Bool = false)
        -> AsyncThrowingStream<String, Error> {
        runner.stream(DockerCommands.logs(id, follow: follow, tail: tail))
    }

    func streamPull(_ ref: String, platform: String? = nil) -> AsyncThrowingStream<String, Error> {
        runner.stream(DockerCommands.imagePull(ref, platform: platform))
    }

    func streamBuild(context: String, tag: String? = nil, dockerfile: String? = nil,
                     buildArgs: [String: String] = [:], noCache: Bool = false,
                     platform: String? = nil) -> AsyncThrowingStream<String, Error> {
        runner.stream(DockerCommands.build(context: context,
                                           tag: tag,
                                           dockerfile: dockerfile,
                                           buildArgs: buildArgs,
                                           noCache: noCache,
                                           platform: platform))
    }

    func streamPush(_ ref: String, platform: String? = nil) -> AsyncThrowingStream<String, Error> {
        runner.stream(DockerCommands.imagePush(ref, platform: platform))
    }

    @discardableResult func runContainer(arguments: [String]) async throws -> Data {
        try await runner.run(arguments)
    }

    @discardableResult func performSystemAction(_ action: Core.Runtime.SystemAction) async throws -> Data {
        throw unsupported(.systemStatus)
    }

    // MARK: Registries

    func registries() async throws -> [Core.Registry.Login] { [] }

    @discardableResult func registryLogin(server: String, username: String, password: String) async throws -> Data {
        try await runner.run(DockerCommands.registryLogin(server: server, username: username),
                             stdin: Data(password.utf8))
    }

    @discardableResult func registryLogout(server: String) async throws -> Data {
        try await runner.run(DockerCommands.registryLogout(server: server))
    }

    // MARK: Image writes

    @discardableResult func deleteImages(_ refs: [String]) async throws -> Data {
        try await runner.run(DockerCommands.imageDelete(refs))
    }
    @discardableResult func tagImage(source: String, target: String) async throws -> Data {
        try await runner.run(DockerCommands.imageTag(source: source, target: target))
    }
    @discardableResult func saveImages(_ refs: [String], to output: String) async throws -> Data {
        try await runner.run(DockerCommands.imageSave(refs: refs, output: output))
    }
    @discardableResult func loadImages(from input: String) async throws -> Data {
        try await runner.run(DockerCommands.imageLoad(input: input))
    }
    @discardableResult func exportContainer(_ id: String, to output: String) async throws -> Data {
        try await runner.run(DockerCommands.containerExport(id, output: output))
    }
    @discardableResult func pruneImages(all: Bool = false) async throws -> Data {
        try await runner.run(DockerCommands.imagePrune(all: all))
    }

    // MARK: Lifecycle

    @discardableResult func start(_ ids: [String]) async throws -> Data {
        try await runner.run(DockerCommands.start(ids))
    }
    @discardableResult func stop(_ ids: [String]) async throws -> Data {
        try await runner.run(DockerCommands.stop(ids))
    }
    @discardableResult func deleteContainers(_ ids: [String], force: Bool) async throws -> Data {
        try await runner.run(DockerCommands.deleteContainers(ids, force: force))
    }
    @discardableResult func pruneContainers() async throws -> Data {
        try await runner.run(DockerCommands.containerPrune())
    }
    @discardableResult func pruneVolumes() async throws -> Data {
        try await runner.run(DockerCommands.volumePrune())
    }
    @discardableResult func pruneNetworks() async throws -> Data {
        try await runner.run(DockerCommands.networkPrune())
    }

    // MARK: Infra writes

    @discardableResult func createVolume(name: String, size: String? = nil,
                                         labels: [String: String] = [:]) async throws -> Data {
        try await runner.run(DockerCommands.volumeCreate(name: name, size: size, labels: labels))
    }
    @discardableResult func deleteVolumes(_ names: [String]) async throws -> Data {
        try await runner.run(DockerCommands.volumeDelete(names))
    }
    @discardableResult func createNetwork(name: String, subnet: String? = nil, internalOnly: Bool = false,
                                          labels: [String: String] = [:]) async throws -> Data {
        try await runner.run(DockerCommands.networkCreate(name: name,
                                                          subnet: subnet,
                                                          internalOnly: internalOnly,
                                                          labels: labels))
    }
    @discardableResult func deleteNetworks(_ names: [String]) async throws -> Data {
        try await runner.run(DockerCommands.networkDelete(names))
    }

    // MARK: Helpers

    private func decode<T: Decodable>(_ type: T.Type,
                                      _ args: [String],
                                      _ name: String,
                                      priority: Core.Command.ExecutionPriority = .userInitiated) async throws -> T {
        let data = try await runner.run(args, stdin: nil, priority: priority)
        do {
            return try DockerJSON.decode(type, from: data)
        } catch {
            throw Core.Command.Error.decodingFailed(underlying: String(describing: error), command: name)
        }
    }

    private func decodeLines<T: Decodable>(_ type: T.Type,
                                           _ args: [String],
                                           _ name: String,
                                           priority: Core.Command.ExecutionPriority = .userInitiated) async throws -> [T] {
        let data = try await runner.run(args, stdin: nil, priority: priority)
        do {
            return try DockerJSON.decodeJSONLines(type, from: data)
        } catch {
            throw Core.Command.Error.decodingFailed(underlying: String(describing: error), command: name)
        }
    }

    private func unsupported(_ capability: Core.Runtime.Capability) -> Core.Runtime.UnsupportedCapability {
        Core.Runtime.UnsupportedCapability(kind: descriptor.kind, capability: capability)
    }
}

private struct DockerSystemDFRow: Decodable {
    var type: String
    var totalCountString: String?
    var activeString: String?
    var sizeString: String?
    var reclaimableString: String?

    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case totalCountString = "TotalCount"
        case activeString = "Active"
        case sizeString = "Size"
        case reclaimableString = "Reclaimable"
    }

    var totalCount: Int { Int(totalCountString ?? "") ?? 0 }
    var activeCount: Int { Int(activeString ?? "") ?? 0 }
    var sizeBytes: UInt64 { parseByteSpec(sizeString ?? "") ?? 0 }
    var reclaimableBytes: UInt64 {
        let first = (reclaimableString ?? "").split(separator: " ").first.map(String.init) ?? ""
        return parseByteSpec(first) ?? 0
    }
}

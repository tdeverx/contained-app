import Foundation

public extension Core {
    struct Configuration: Sendable {
        public var defaultRuntime: Core.Runtime.Kind
        public var appleContainer: AppleContainerConfiguration

        public init(defaultRuntime: Core.Runtime.Kind = .appleContainer,
                    appleContainer: AppleContainerConfiguration = AppleContainerConfiguration()) {
            self.defaultRuntime = defaultRuntime
            self.appleContainer = appleContainer
        }
    }

    struct AppleContainerConfiguration: Sendable {
        public var cliPathOverride: String?

        public init(cliPathOverride: String? = nil) {
            self.cliPathOverride = cliPathOverride
        }
    }
}

public extension Core {
    struct Orchestrator: Sendable, Equatable {
        public enum Bootstrap: Sendable, Equatable {
            case cliMissing
            case unsupported(orchestrator: Core.Orchestrator, cliURL: URL, version: String)
            case ready(orchestrator: Core.Orchestrator, cliURL: URL, version: String?)
        }

        private let client: AppleContainerClient
        public let cliURL: URL
        public let defaultRuntime: Core.Runtime.Kind

        public static func == (lhs: Core.Orchestrator, rhs: Core.Orchestrator) -> Bool {
            lhs.cliURL == rhs.cliURL && lhs.defaultRuntime == rhs.defaultRuntime
        }

        public static func live(configuration: Core.Configuration = Core.Configuration()) -> Core.Orchestrator? {
            guard let url = AppleContainerCLILocator.locate(override: configuration.appleContainer.cliPathOverride) else {
                return nil
            }
            return Core.Orchestrator(cliURL: url,
                                     defaultRuntime: configuration.defaultRuntime,
                                     client: AppleContainerClient(runner: Core.Command.Runner(executableURL: url)))
        }

        public static func testing(runner: any Core.Command.Running,
                                   cliURL: URL = URL(fileURLWithPath: "/usr/bin/container"),
                                   defaultRuntime: Core.Runtime.Kind = .appleContainer) -> Core.Orchestrator {
            Core.Orchestrator(cliURL: cliURL,
                              defaultRuntime: defaultRuntime,
                              client: AppleContainerClient(runner: runner))
        }

        public static func bootstrap(configuration: Core.Configuration = Core.Configuration()) async -> Bootstrap {
            guard let orchestrator = live(configuration: configuration) else { return .cliMissing }
            let runner = Core.Command.Runner(executableURL: orchestrator.cliURL)
            let versionData = try? await runner.run(ContainerCommands.version)
            let version = versionData.map { String(decoding: $0, as: UTF8.self) }
                .flatMap(AppleContainerCLILocator.parseVersion)
            if let version, !AppleContainerCLILocator.isSupported(version) {
                return .unsupported(orchestrator: orchestrator,
                                    cliURL: orchestrator.cliURL,
                                    version: version)
            }
            return .ready(orchestrator: orchestrator,
                          cliURL: orchestrator.cliURL,
                          version: version)
        }

        init(cliURL: URL, defaultRuntime: Core.Runtime.Kind, client: AppleContainerClient) {
            self.cliURL = cliURL
            self.defaultRuntime = defaultRuntime
            self.client = client
        }

        public var descriptor: Core.Runtime.Descriptor { client.descriptor }

        public var availableRuntimeDescriptors: [Core.Runtime.Descriptor] {
            [.appleContainer]
        }

        public var runtimeCoreSelectorIsEnabled: Bool {
            availableRuntimeDescriptors.count > 1
        }

        public func descriptor(for kind: Core.Runtime.Kind) -> Core.Runtime.Descriptor {
            availableRuntimeDescriptors.first { $0.kind == kind } ?? .appleContainer
        }

        public func supportsRuntime(_ kind: Core.Runtime.Kind, capability: Core.Runtime.Capability = .containers) -> Bool {
            availableRuntimeDescriptors.first { $0.kind == kind }?.supports(capability) == true
        }

        private func requireRuntime(_ kind: Core.Runtime.Kind,
                                    capability: Core.Runtime.Capability) throws -> AppleContainerClient {
            guard client.descriptor.kind == kind else {
                throw Core.Runtime.UnsupportedCapability(kind: kind, capability: capability)
            }
            try client.descriptor.require(capability)
            return client
        }

        public func listContainers(all: Bool = true) async throws -> [Core.Container.Snapshot] {
            try await client.listContainers(all: all)
        }

        public func stats(ids: [String] = []) async throws -> [Core.Metrics.ContainerStats] {
            try await client.stats(ids: ids)
        }

        public func streamStats(ids: [String] = []) -> AsyncThrowingStream<[Core.Metrics.RuntimeStatsSnapshot], Swift.Error> {
            client.streamStats(ids: ids)
        }

        public func diskUsage() async throws -> Core.System.DiskUsage {
            try await client.diskUsage()
        }

        public func systemProperties() async throws -> Core.System.Properties {
            try await client.systemProperties()
        }

        public func dnsDomains() async throws -> [String] {
            try await client.dnsDomains()
        }

        @discardableResult public func createDNSDomain(_ domain: String) async throws -> Data {
            try await client.createDNSDomain(domain)
        }

        @discardableResult public func deleteDNSDomain(_ domain: String) async throws -> Data {
            try await client.deleteDNSDomain(domain)
        }

        @discardableResult public func setRecommendedKernel() async throws -> Data {
            try await client.setRecommendedKernel()
        }

        public func execCapture(_ id: String, _ command: [String]) async throws -> String {
            try await client.execCapture(id, command)
        }

        @discardableResult public func copy(source: String, destination: String) async throws -> Data {
            try await client.copy(source: source, destination: destination)
        }

        public func terminalInvocation(containerID: String, shell: String) throws -> Core.Command.Invocation {
            Core.Command.Invocation(executableURL: cliURL,
                              arguments: ContainerCommands.execInteractive(containerID, shell: shell))
        }

        public func streamSystemLogs(follow: Bool, last: Int? = 500) -> AsyncThrowingStream<String, Swift.Error> {
            client.streamSystemLogs(follow: follow, last: last)
        }

        public func systemStatus() async throws -> Core.System.Status {
            try await client.systemStatus()
        }

        public func previewCreateCommand(for request: Core.Container.CreateRequest) throws -> Core.Command.Preview {
            try requireRuntime(request.runtimeKind, capability: .containers).previewCreateCommand(for: request)
        }

        @discardableResult public func createContainer(_ request: Core.Container.CreateRequest) async throws -> Core.Container.CreateResult {
            try await requireRuntime(request.runtimeKind, capability: .containers).createContainer(request)
        }

        @discardableResult public func recreateContainer(originalID: String,
                                                         request: Core.Container.CreateRequest) async throws -> Core.Container.CreateResult {
            let runtime = try requireRuntime(request.runtimeKind, capability: .containers)
            _ = try? await runtime.stop([originalID])
            _ = try await runtime.deleteContainers([originalID], force: true)
            return try await runtime.createContainer(request)
        }

        public func translateCompose(_ project: Core.Compose.Project,
                                     baseDirectory: URL?,
                                     runtimeKind: Core.Runtime.Kind = .appleContainer) throws -> Core.Compose.ImportPlan {
            try requireRuntime(runtimeKind, capability: .composeImport)
                .translateCompose(project, baseDirectory: baseDirectory)
        }

        public func imageDefaults(for request: Core.Container.CreateRequest,
                                  in images: [Core.Image.Resource]) throws -> Core.Container.ImageDefaults? {
            try requireRuntime(request.runtimeKind, capability: .containers)
                .imageDefaults(for: request, in: images)
        }

        public func planMigration(_ document: Core.Container.Document,
                                  to target: Core.Runtime.Kind?) throws -> Core.Migration.Plan {
            let source = document.canonical.createRequest.runtimeKind
            return try requireRuntime(source, capability: .coreMigration)
                .coreSwitchPlan(for: document.canonical.createRequest.effectiveName ?? "", to: target.map(descriptor(for:)))
        }

        public func coreSwitchPlan(for containerID: String,
                                   source: Core.Runtime.Kind = .appleContainer,
                                   to target: Core.Runtime.Descriptor?) throws -> Core.Migration.Plan {
            try requireRuntime(source, capability: .coreMigration).coreSwitchPlan(for: containerID, to: target)
        }

        public func networks() async throws -> [Core.Network.Resource] {
            try await client.networks()
        }

        public func volumes() async throws -> [Core.Volume.Resource] {
            try await client.volumes()
        }

        public func images() async throws -> [Core.Image.Resource] {
            try await client.images()
        }

        public func inspectImage(_ ref: String) async throws -> [Core.Image.Resource] {
            try await client.inspectImage(ref)
        }

        public func streamLogs(id: String,
                               follow: Bool = true,
                               tail: Int? = 200,
                               boot: Bool = false) -> AsyncThrowingStream<String, Swift.Error> {
            client.streamLogs(id: id, follow: follow, tail: tail, boot: boot)
        }

        public func streamPull(_ ref: String,
                               platform: String? = nil) -> AsyncThrowingStream<String, Swift.Error> {
            client.streamPull(ref, platform: platform)
        }

        public func streamBuild(context: String,
                                tag: String? = nil,
                                dockerfile: String? = nil,
                                buildArgs: [String: String] = [:],
                                noCache: Bool = false,
                                platform: String? = nil) -> AsyncThrowingStream<String, Swift.Error> {
            client.streamBuild(context: context,
                               tag: tag,
                               dockerfile: dockerfile,
                               buildArgs: buildArgs,
                               noCache: noCache,
                               platform: platform)
        }

        public func streamPush(_ ref: String,
                               platform: String? = nil) -> AsyncThrowingStream<String, Swift.Error> {
            client.streamPush(ref, platform: platform)
        }

        @discardableResult public func runContainer(arguments: [String]) async throws -> Data {
            try await client.runContainer(arguments: arguments)
        }

        @discardableResult public func performSystemAction(_ action: Core.Runtime.SystemAction) async throws -> Data {
            try await client.performSystemAction(action)
        }

        public func registries() async throws -> [Core.Registry.Login] {
            try await client.registries()
        }

        @discardableResult public func registryLogin(server: String,
                                                     username: String,
                                                     password: String) async throws -> Data {
            try await client.registryLogin(server: server, username: username, password: password)
        }

        @discardableResult public func registryLogout(server: String) async throws -> Data {
            try await client.registryLogout(server: server)
        }

        @discardableResult public func deleteImages(_ refs: [String]) async throws -> Data {
            try await client.deleteImages(refs)
        }

        @discardableResult public func tagImage(source: String, target: String) async throws -> Data {
            try await client.tagImage(source: source, target: target)
        }

        @discardableResult public func saveImages(_ refs: [String], to output: String) async throws -> Data {
            try await client.saveImages(refs, to: output)
        }

        @discardableResult public func loadImages(from input: String) async throws -> Data {
            try await client.loadImages(from: input)
        }

        @discardableResult public func exportContainer(_ id: String, to output: String) async throws -> Data {
            try await client.exportContainer(id, to: output)
        }

        @discardableResult public func pruneImages(all: Bool = false) async throws -> Data {
            try await client.pruneImages(all: all)
        }

        @discardableResult public func start(_ ids: [String]) async throws -> Data {
            try await client.start(ids)
        }

        @discardableResult public func stop(_ ids: [String]) async throws -> Data {
            try await client.stop(ids)
        }

        @discardableResult public func deleteContainers(_ ids: [String], force: Bool) async throws -> Data {
            try await client.deleteContainers(ids, force: force)
        }

        @discardableResult public func pruneContainers() async throws -> Data {
            try await client.pruneContainers()
        }

        @discardableResult public func pruneVolumes() async throws -> Data {
            try await client.pruneVolumes()
        }

        @discardableResult public func pruneNetworks() async throws -> Data {
            try await client.pruneNetworks()
        }

        @discardableResult public func createVolume(name: String,
                                                    size: String? = nil,
                                                    labels: [String: String] = [:]) async throws -> Data {
            try await client.createVolume(name: name, size: size, labels: labels)
        }

        @discardableResult public func deleteVolumes(_ names: [String]) async throws -> Data {
            try await client.deleteVolumes(names)
        }

        @discardableResult public func createNetwork(name: String,
                                                     subnet: String? = nil,
                                                     internalOnly: Bool = false,
                                                     labels: [String: String] = [:]) async throws -> Data {
            try await client.createNetwork(name: name,
                                           subnet: subnet,
                                           internalOnly: internalOnly,
                                           labels: labels)
        }

        @discardableResult public func deleteNetworks(_ names: [String]) async throws -> Data {
            try await client.deleteNetworks(names)
        }
    }
}

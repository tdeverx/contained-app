import Foundation

public extension Core {
    struct Configuration: Sendable {
        public var appleContainer: AppleContainerConfiguration
        public var docker: DockerConfiguration

        public init(appleContainer: AppleContainerConfiguration = AppleContainerConfiguration(),
                    docker: DockerConfiguration = DockerConfiguration()) {
            self.appleContainer = appleContainer
            self.docker = docker
        }
    }

    struct AppleContainerConfiguration: Sendable {
        public var cliPathOverride: String?

        public init(cliPathOverride: String? = nil) {
            self.cliPathOverride = cliPathOverride
        }
    }

    struct DockerConfiguration: Sendable {
        public var cliPathOverride: String?

        public init(cliPathOverride: String? = nil) {
            self.cliPathOverride = cliPathOverride
        }
    }
}

public extension Core {
    struct RuntimeReadiness: Sendable, Equatable, Identifiable {
        public enum State: String, Sendable, Equatable {
            case ready
            case unsupported
            case endpointUnavailable
        }

        public var kind: Core.Runtime.Kind
        public var cliURL: URL
        public var version: String?
        public var state: State
        public var message: String?

        public var id: Core.Runtime.Kind { kind }

        public init(kind: Core.Runtime.Kind,
                    cliURL: URL,
                    version: String? = nil,
                    state: State = .ready,
                    message: String? = nil) {
            self.kind = kind
            self.cliURL = cliURL
            self.version = version
            self.state = state
            self.message = message
        }
    }

    struct Orchestrator: Sendable, Equatable {
        public enum Bootstrap: Sendable, Equatable {
            case cliMissing
            case ready(orchestrator: Core.Orchestrator, runtimes: [Core.RuntimeReadiness])
        }

        private let runtimes: [Core.Runtime.Kind: any ContainerRuntimeClient]
        private let runtimeCLIURLs: [Core.Runtime.Kind: URL]

        public static func == (lhs: Core.Orchestrator, rhs: Core.Orchestrator) -> Bool {
            lhs.runtimeCLIURLs == rhs.runtimeCLIURLs
        }

        public static func live(configuration: Core.Configuration = Core.Configuration()) -> Core.Orchestrator? {
            var runtimes: [Core.Runtime.Kind: any ContainerRuntimeClient] = [:]
            var cliURLs: [Core.Runtime.Kind: URL] = [:]

            if let url = AppleContainerCLILocator.locate(override: configuration.appleContainer.cliPathOverride) {
                cliURLs[.appleContainer] = url
                runtimes[.appleContainer] = AppleContainerClient(runner: Core.Command.Runner(executableURL: url))
            }

            if let url = DockerCLILocator.locate(override: configuration.docker.cliPathOverride) {
                cliURLs[.docker] = url
                runtimes[.docker] = DockerClient(runner: Core.Command.Runner(executableURL: url))
            }

            guard !runtimes.isEmpty else { return nil }
            return Core.Orchestrator(cliURLs: cliURLs, runtimes: runtimes)
        }

        public static func testing(runner: any Core.Command.Running,
                                   cliURL: URL = URL(fileURLWithPath: "/usr/bin/container"),
                                   runtimeKind: Core.Runtime.Kind = .appleContainer) -> Core.Orchestrator {
            let client: any ContainerRuntimeClient = runtimeKind == .docker
                ? DockerClient(runner: runner)
                : AppleContainerClient(runner: runner)
            return Core.Orchestrator(cliURLs: [runtimeKind: cliURL],
                                     runtimes: [runtimeKind: client])
        }

        public static func testing(runners: [Core.Runtime.Kind: any Core.Command.Running],
                                   cliURLs: [Core.Runtime.Kind: URL] = [:]) -> Core.Orchestrator {
            var clients: [Core.Runtime.Kind: any ContainerRuntimeClient] = [:]
            for (kind, runner) in runners {
                clients[kind] = kind == .docker
                    ? DockerClient(runner: runner)
                    : AppleContainerClient(runner: runner)
            }
            let resolvedURLs = Dictionary(uniqueKeysWithValues: clients.keys.map { kind in
                (kind, cliURLs[kind] ?? URL(fileURLWithPath: kind == .docker ? "/usr/local/bin/docker" : "/usr/bin/container"))
            })
            return Core.Orchestrator(cliURLs: resolvedURLs, runtimes: clients)
        }

        public static func bootstrap(configuration: Core.Configuration = Core.Configuration()) async -> Bootstrap {
            guard let orchestrator = live(configuration: configuration) else { return .cliMissing }
            var readiness: [Core.RuntimeReadiness] = []
            for descriptor in orchestrator.availableRuntimeDescriptors {
                guard let cliURL = orchestrator.cliURL(for: descriptor.kind) else { continue }
                let version: String?
                let state: Core.RuntimeReadiness.State
                switch descriptor.kind {
                case .appleContainer:
                    let runner = Core.Command.Runner(executableURL: cliURL)
                    let versionData = try? await runner.run(ContainerCommands.version)
                    version = versionData.map { String(decoding: $0, as: UTF8.self) }
                        .flatMap(AppleContainerCLILocator.parseVersion)
                    state = version.map(AppleContainerCLILocator.isSupported) == false ? .unsupported : .ready
                case .docker:
                    let runner = Core.Command.Runner(executableURL: cliURL)
                    let versionData = try? await runner.run(DockerCommands.version)
                    version = versionData.map { String(decoding: $0, as: UTF8.self) }
                        .flatMap(DockerCLILocator.parseVersion)
                    state = .ready
                default:
                    version = nil
                    state = .ready
                }
                readiness.append(Core.RuntimeReadiness(kind: descriptor.kind,
                                                       cliURL: cliURL,
                                                       version: version,
                                                       state: state))
            }
            return .ready(orchestrator: orchestrator, runtimes: readiness)
        }

        init(cliURLs: [Core.Runtime.Kind: URL],
             runtimes: [Core.Runtime.Kind: any ContainerRuntimeClient]) {
            self.runtimeCLIURLs = cliURLs
            self.runtimes = runtimes
        }

        public var availableRuntimeDescriptors: [Core.Runtime.Descriptor] {
            runtimes.values.map(\.descriptor).sorted { $0.displayName < $1.displayName }
        }

        public func descriptor(for kind: Core.Runtime.Kind) -> Core.Runtime.Descriptor {
            availableRuntimeDescriptors.first { $0.kind == kind }
                ?? (kind == .docker ? .docker : .appleContainer)
        }

        public func supportsRuntime(_ kind: Core.Runtime.Kind, capability: Core.Runtime.Capability = .containers) -> Bool {
            availableRuntimeDescriptors.first { $0.kind == kind }?.supports(capability) == true
        }

        internal func requireRuntime(_ kind: Core.Runtime.Kind,
                                     capability: Core.Runtime.Capability) throws -> any ContainerRuntimeClient {
            guard let runtime = runtimes[kind] else {
                throw Core.Runtime.UnsupportedCapability(kind: kind, capability: capability)
            }
            try runtime.descriptor.require(capability)
            return runtime
        }

        public func cliURL(for kind: Core.Runtime.Kind) -> URL? {
            runtimeCLIURLs[kind]
        }

        private func requireCLIURL(for kind: Core.Runtime.Kind) throws -> URL {
            guard let url = runtimeCLIURLs[kind] else {
                throw Core.Runtime.UnsupportedCapability(kind: kind, capability: .containers)
            }
            return url
        }

        public func schemaDefinition(for operation: Core.Schema.Operation,
                                     runtimeKind: Core.Runtime.Kind) -> Core.Schema.Definition {
            Core.Schema.Definition.containerRunEdit(runtimeKind: runtimeKind,
                                                    operation: operation)
        }

        public func listRuntimeContainers(all: Bool = true) async throws -> [Core.Container.Snapshot] {
            var snapshots: [Core.Container.Snapshot] = []
            var successes = 0
            var firstError: Swift.Error?
            for kind in runtimes.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard let runtime = runtimes[kind] else { continue }
                do {
                    snapshots += try await runtime.listContainers(all: all).map { $0.scoped(to: kind) }
                    successes += 1
                } catch {
                    firstError = firstError ?? error
                }
            }
            if successes == 0, let firstError { throw firstError }
            return snapshots
        }

        public func stats(ids: [String] = [],
                          runtimeKind: Core.Runtime.Kind) async throws -> [Core.Metrics.ContainerStats] {
            let runtime = try requireRuntime(runtimeKind, capability: .containers)
            return try await runtime.stats(ids: ids).map { $0.scoped(to: runtimeKind) }
        }

        public func streamStats(ids: [String] = [],
                                runtimeKind: Core.Runtime.Kind) -> AsyncThrowingStream<[Core.Metrics.RuntimeStatsSnapshot], Swift.Error> {
            do {
                let runtime = try requireRuntime(runtimeKind, capability: .containers)
                let source = runtime.streamStats(ids: ids)
                return AsyncThrowingStream { continuation in
                    let task = Task(priority: .utility) {
                        do {
                            for try await samples in source {
                                continuation.yield(samples.map { $0.scoped(to: runtimeKind) })
                            }
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            } catch {
                return AsyncThrowingStream { continuation in continuation.finish(throwing: error) }
            }
        }

        public func diskUsage(runtimeKind: Core.Runtime.Kind) async throws -> Core.System.DiskUsage {
            try await requireRuntime(runtimeKind, capability: .systemStatus).diskUsage()
        }

        public func systemProperties(runtimeKind: Core.Runtime.Kind) async throws -> Core.System.Properties {
            try await requireRuntime(runtimeKind, capability: .systemProperties).systemProperties()
        }

        public func dnsDomains(runtimeKind: Core.Runtime.Kind) async throws -> [String] {
            try await requireRuntime(runtimeKind, capability: .dnsManagement).dnsDomains()
        }

        @discardableResult public func createDNSDomain(_ domain: String,
                                                       runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .dnsManagement).createDNSDomain(domain)
        }

        @discardableResult public func deleteDNSDomain(_ domain: String,
                                                       runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .dnsManagement).deleteDNSDomain(domain)
        }

        @discardableResult public func setRecommendedKernel(runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .kernelManagement).setRecommendedKernel()
        }

        public func execCapture(_ id: String,
                                _ command: [String],
                                runtimeKind: Core.Runtime.Kind) async throws -> String {
            try await requireRuntime(runtimeKind, capability: .exec).execCapture(id, command)
        }

        @discardableResult public func copy(source: String,
                                            destination: String,
                                            runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .copy).copy(source: source, destination: destination)
        }

        public func terminalInvocation(containerID: String,
                                       shell: String,
                                       runtimeKind: Core.Runtime.Kind) throws -> Core.Command.Invocation {
            _ = try requireRuntime(runtimeKind, capability: .exec)
            let executable = try requireCLIURL(for: runtimeKind)
            let arguments = runtimeKind == .docker
                ? DockerCommands.execInteractive(containerID, shell: shell)
                : ContainerCommands.execInteractive(containerID, shell: shell)
            return Core.Command.Invocation(executableURL: executable, arguments: arguments)
        }

        public func streamSystemLogs(follow: Bool,
                                     last: Int? = 500,
                                     runtimeKind: Core.Runtime.Kind) -> AsyncThrowingStream<String, Swift.Error> {
            do {
                let runtime = try requireRuntime(runtimeKind, capability: .systemLogs)
                return runtime.streamSystemLogs(follow: follow, last: last)
            } catch {
                return AsyncThrowingStream { continuation in continuation.finish(throwing: error) }
            }
        }

        public func systemStatus(runtimeKind: Core.Runtime.Kind) async throws -> Core.System.Status {
            try await requireRuntime(runtimeKind, capability: .systemStatus).systemStatus()
        }

        private func previewCreateCommand(for request: Core.Container.CreateRequest) throws -> Core.Command.Preview {
            try requireRuntime(request.runtimeKind, capability: .containers).previewCreateCommand(for: request)
        }

        public func previewCreateCommand(for document: Core.Schema.Document) throws -> Core.Command.Preview {
            let definition = schemaDefinition(for: document.operation, runtimeKind: document.runtimeKind)
            let request = try document.validatedRequest(definition: definition)
            return try previewCreateCommand(for: request)
        }

        @discardableResult private func createContainer(_ request: Core.Container.CreateRequest) async throws -> Core.Container.CreateResult {
            try await requireRuntime(request.runtimeKind, capability: .containers).createContainer(request)
        }

        @discardableResult public func createContainer(_ document: Core.Schema.Document) async throws -> Core.Container.CreateResult {
            let definition = schemaDefinition(for: document.operation, runtimeKind: document.runtimeKind)
            let request = try document.validatedRequest(definition: definition)
            return try await createContainer(request)
        }

        @discardableResult private func recreateContainer(originalID: String,
                                                         request: Core.Container.CreateRequest) async throws -> Core.Container.CreateResult {
            let runtime = try requireRuntime(request.runtimeKind, capability: .containers)
            _ = try? await runtime.stop([originalID])
            _ = try await runtime.deleteContainers([originalID], force: true)
            return try await runtime.createContainer(request)
        }

        @discardableResult public func recreateContainer(originalID: String,
                                                         document: Core.Schema.Document) async throws -> Core.Container.CreateResult {
            let definition = schemaDefinition(for: document.operation, runtimeKind: document.runtimeKind)
            let request = try document.validatedRequest(definition: definition)
            return try await recreateContainer(originalID: originalID, request: request)
        }

        public func translateCompose(_ project: Core.Compose.Project,
                                     baseDirectory: URL?,
                                     runtimeKind: Core.Runtime.Kind) throws -> Core.Compose.ImportPlan {
            try requireRuntime(runtimeKind, capability: .composeImport)
                .translateCompose(project, baseDirectory: baseDirectory)
        }

        private func imageDefaults(for request: Core.Container.CreateRequest,
                                  in images: [Core.Image.Resource]) throws -> Core.Container.ImageDefaults? {
            try requireRuntime(request.runtimeKind, capability: .containers)
                .imageDefaults(for: request, in: images)
        }

        public func imageDefaults(for document: Core.Schema.Document,
                                  in images: [Core.Image.Resource]) throws -> Core.Container.ImageDefaults? {
            let definition = schemaDefinition(for: document.operation, runtimeKind: document.runtimeKind)
            let request = try document.validatedRequest(definition: definition)
            return try imageDefaults(for: request, in: images)
        }

        public func planMigration(_ document: Core.Container.Document,
                                  to target: Core.Runtime.Kind?) throws -> Core.Migration.Plan {
            let source = document.canonical.createRequest.runtimeKind
            return try requireRuntime(source, capability: .coreMigration)
                .coreSwitchPlan(for: document.canonical.createRequest.effectiveName ?? "", to: target.map(descriptor(for:)))
        }

        public func coreSwitchPlan(for containerID: String,
                                   source: Core.Runtime.Kind,
                                   to target: Core.Runtime.Descriptor?) throws -> Core.Migration.Plan {
            try requireRuntime(source, capability: .coreMigration).coreSwitchPlan(for: containerID, to: target)
        }

        public func runtimeNetworks() async throws -> [Core.Network.Resource] {
            var networks: [Core.Network.Resource] = []
            var successes = 0
            var firstError: Swift.Error?
            for kind in runtimes.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard let runtime = runtimes[kind] else { continue }
                do {
                    networks += try await runtime.networks().map { $0.scoped(to: kind) }
                    successes += 1
                } catch {
                    firstError = firstError ?? error
                }
            }
            if successes == 0, let firstError { throw firstError }
            return networks
        }

        public func runtimeVolumes() async throws -> [Core.Volume.Resource] {
            var volumes: [Core.Volume.Resource] = []
            var successes = 0
            var firstError: Swift.Error?
            for kind in runtimes.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard let runtime = runtimes[kind] else { continue }
                do {
                    volumes += try await runtime.volumes().map { $0.scoped(to: kind) }
                    successes += 1
                } catch {
                    firstError = firstError ?? error
                }
            }
            if successes == 0, let firstError { throw firstError }
            return volumes
        }

        public func runtimeImages() async throws -> [Core.Image.Resource] {
            var images: [Core.Image.Resource] = []
            var successes = 0
            var firstError: Swift.Error?
            for kind in runtimes.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard let runtime = runtimes[kind] else { continue }
                do {
                    images += try await runtime.images().map { $0.scoped(to: kind) }
                    successes += 1
                } catch {
                    firstError = firstError ?? error
                }
            }
            if successes == 0, let firstError { throw firstError }
            return images
        }

        public func inspectImage(_ ref: String,
                                 runtimeKind: Core.Runtime.Kind) async throws -> [Core.Image.Resource] {
            let images = try await requireRuntime(runtimeKind, capability: .images).inspectImage(ref)
            return images.map { $0.scoped(to: runtimeKind) }
        }

        public func streamLogs(id: String,
                               runtimeKind: Core.Runtime.Kind,
                               follow: Bool = true,
                               tail: Int? = 200,
                               boot: Bool = false) -> AsyncThrowingStream<String, Swift.Error> {
            do {
                let runtime = try requireRuntime(runtimeKind, capability: .containers)
                return runtime.streamLogs(id: id, follow: follow, tail: tail, boot: boot)
            } catch {
                return AsyncThrowingStream { continuation in continuation.finish(throwing: error) }
            }
        }

        public func streamPull(_ ref: String,
                               platform: String? = nil,
                               runtimeKind: Core.Runtime.Kind) -> AsyncThrowingStream<String, Swift.Error> {
            do {
                let runtime = try requireRuntime(runtimeKind, capability: .images)
                return runtime.streamPull(ref, platform: platform)
            } catch {
                return AsyncThrowingStream { continuation in continuation.finish(throwing: error) }
            }
        }

        public func streamBuild(context: String,
                                tag: String? = nil,
                                dockerfile: String? = nil,
                                buildArgs: [String: String] = [:],
                                noCache: Bool = false,
                                platform: String? = nil,
                                runtimeKind: Core.Runtime.Kind) -> AsyncThrowingStream<String, Swift.Error> {
            do {
                let runtime = try requireRuntime(runtimeKind, capability: .imageBuild)
                return runtime.streamBuild(context: context,
                                           tag: tag,
                                           dockerfile: dockerfile,
                                           buildArgs: buildArgs,
                                           noCache: noCache,
                                           platform: platform)
            } catch {
                return AsyncThrowingStream { continuation in continuation.finish(throwing: error) }
            }
        }

        public func streamPush(_ ref: String,
                               platform: String? = nil,
                               runtimeKind: Core.Runtime.Kind) -> AsyncThrowingStream<String, Swift.Error> {
            do {
                let runtime = try requireRuntime(runtimeKind, capability: .imagePush)
                return runtime.streamPush(ref, platform: platform)
            } catch {
                return AsyncThrowingStream { continuation in continuation.finish(throwing: error) }
            }
        }

        @discardableResult public func runContainer(arguments: [String],
                                                    runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .containers).runContainer(arguments: arguments)
        }

        @discardableResult public func performSystemAction(_ action: Core.Runtime.SystemAction) async throws -> Data {
            try await requireRuntime(.appleContainer, capability: .systemStatus).performSystemAction(action)
        }

        public func registries(runtimeKind: Core.Runtime.Kind) async throws -> [Core.Registry.Login] {
            try await requireRuntime(runtimeKind, capability: .registries).registries().map { $0.scoped(to: runtimeKind) }
        }

        @discardableResult public func registryLogin(server: String,
                                                     username: String,
                                                     password: String,
                                                     runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .registries)
                .registryLogin(server: server, username: username, password: password)
        }

        @discardableResult public func registryLogout(server: String,
                                                      runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .registries).registryLogout(server: server)
        }

        @discardableResult public func deleteImages(_ refs: [String],
                                                    runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .images).deleteImages(refs)
        }

        @discardableResult public func tagImage(source: String,
                                                target: String,
                                                runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .images).tagImage(source: source, target: target)
        }

        @discardableResult public func saveImages(_ refs: [String],
                                                  to output: String,
                                                  runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .imageArchive).saveImages(refs, to: output)
        }

        @discardableResult public func loadImages(from input: String,
                                                  runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .imageArchive).loadImages(from: input)
        }

        @discardableResult public func exportContainer(_ id: String,
                                                       to output: String,
                                                       runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .containerExport).exportContainer(id, to: output)
        }

        @discardableResult public func pruneImages(all: Bool = false,
                                                   runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .images).pruneImages(all: all)
        }

        @discardableResult public func start(_ ids: [String],
                                             runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .containers).start(ids)
        }

        @discardableResult public func stop(_ ids: [String],
                                            runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .containers).stop(ids)
        }

        @discardableResult public func deleteContainers(_ ids: [String],
                                                        force: Bool,
                                                        runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .containers).deleteContainers(ids, force: force)
        }

        @discardableResult public func pruneContainers(runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .containers).pruneContainers()
        }

        @discardableResult public func pruneVolumes(runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .volumes).pruneVolumes()
        }

        @discardableResult public func pruneNetworks(runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .networks).pruneNetworks()
        }

        @discardableResult public func createVolume(name: String,
                                                    size: String? = nil,
                                                    labels: [String: String] = [:],
                                                    runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .volumes)
                .createVolume(name: name, size: size, labels: labels)
        }

        @discardableResult public func deleteVolumes(_ names: [String],
                                                     runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .volumes).deleteVolumes(names)
        }

        @discardableResult public func createNetwork(name: String,
                                                     subnet: String? = nil,
                                                     internalOnly: Bool = false,
                                                     labels: [String: String] = [:],
                                                     runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .networks)
                .createNetwork(name: name,
                               subnet: subnet,
                               internalOnly: internalOnly,
                               labels: labels)
        }

        @discardableResult public func deleteNetworks(_ names: [String],
                                                      runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind, capability: .networks).deleteNetworks(names)
        }
    }
}

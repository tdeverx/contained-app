import Foundation

public extension Core {
    struct Configuration: Sendable, Equatable {
        public var runtimes: [Core.Runtime.Kind: Core.Runtime.Configuration]

        public init(runtimes: [Core.Runtime.Kind: Core.Runtime.Configuration] = [:]) {
            self.runtimes = runtimes
        }

        public func configuration(for kind: Core.Runtime.Kind) -> Core.Runtime.Configuration {
            runtimes[kind] ?? Core.Runtime.Configuration()
        }
    }
}

public extension Core {
    struct RuntimeReadiness: Sendable, Equatable, Identifiable {
        public enum State: String, Sendable, Equatable {
            case cliMissing
            case ready
            case unsupported
            case endpointUnavailable
        }

        public var kind: Core.Runtime.Kind
        public var cliURL: URL?
        public var version: String?
        public var state: State
        public var message: String?

        public var id: Core.Runtime.Kind { kind }

        public init(kind: Core.Runtime.Kind,
                    cliURL: URL?,
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
            case cliMissing(runtimes: [Core.RuntimeReadiness])
            case ready(orchestrator: Core.Orchestrator, runtimes: [Core.RuntimeReadiness])
        }

        let runtimes: [Core.Runtime.Kind: any RuntimeClient]
        private let runtimeCLIURLs: [Core.Runtime.Kind: URL]
        private let modules: [Core.Runtime.Kind: any Core.Runtime.Module]

        public static func == (lhs: Core.Orchestrator, rhs: Core.Orchestrator) -> Bool {
            lhs.runtimeCLIURLs == rhs.runtimeCLIURLs
        }

        public static func live(configuration: Core.Configuration = Core.Configuration()) -> Core.Orchestrator? {
            var runtimes: [Core.Runtime.Kind: any RuntimeClient] = [:]
            var cliURLs: [Core.Runtime.Kind: URL] = [:]
            var modules: [Core.Runtime.Kind: any Core.Runtime.Module] = [:]

            for module in Core.Runtime.builtInModules {
                let runtimeConfiguration = configuration.configuration(for: module.descriptor.kind)
                guard let url = module.locateCLI(override: runtimeConfiguration.cliPathOverride) else { continue }
                cliURLs[module.descriptor.kind] = url
                modules[module.descriptor.kind] = module
                runtimes[module.descriptor.kind] = module.makeClient(
                    runner: Core.Command.Runner(executableURL: url)
                )
            }

            guard !runtimes.isEmpty else { return nil }
            return Core.Orchestrator(cliURLs: cliURLs, runtimes: runtimes, modules: modules)
        }

        public static func testing(runner: any Core.Command.Running,
                                   cliURL: URL = URL(fileURLWithPath: "/usr/bin/container"),
                                   runtimeKind: Core.Runtime.Kind) -> Core.Orchestrator {
            guard let module = Core.Runtime.module(for: runtimeKind) else {
                preconditionFailure("No runtime module registered for \(runtimeKind.rawValue)")
            }
            return Core.Orchestrator(
                cliURLs: [runtimeKind: cliURL],
                runtimes: [runtimeKind: module.makeClient(runner: runner)],
                modules: [runtimeKind: module]
            )
        }

        public static func testing(runners: [Core.Runtime.Kind: any Core.Command.Running],
                                   cliURLs: [Core.Runtime.Kind: URL] = [:]) -> Core.Orchestrator {
            var clients: [Core.Runtime.Kind: any RuntimeClient] = [:]
            var modules: [Core.Runtime.Kind: any Core.Runtime.Module] = [:]
            for (kind, runner) in runners {
                guard let module = Core.Runtime.module(for: kind) else {
                    preconditionFailure("No runtime module registered for \(kind.rawValue)")
                }
                modules[kind] = module
                clients[kind] = module.makeClient(runner: runner)
            }
            let resolvedURLs = Dictionary(uniqueKeysWithValues: clients.keys.map { kind in
                let executableName = modules[kind]?.descriptor.executableName ?? kind.rawValue
                return (kind, cliURLs[kind] ?? URL(fileURLWithPath: "/usr/bin/\(executableName)"))
            })
            return Core.Orchestrator(cliURLs: resolvedURLs, runtimes: clients, modules: modules)
        }

        public static func bootstrap(configuration: Core.Configuration = Core.Configuration()) async -> Bootstrap {
            var readiness: [Core.RuntimeReadiness] = []
            var runtimes: [Core.Runtime.Kind: any RuntimeClient] = [:]
            var cliURLs: [Core.Runtime.Kind: URL] = [:]
            var modules: [Core.Runtime.Kind: any Core.Runtime.Module] = [:]

            for module in Core.Runtime.builtInModules {
                let kind = module.descriptor.kind
                let runtimeConfiguration = configuration.configuration(for: kind)
                guard let cliURL = module.locateCLI(override: runtimeConfiguration.cliPathOverride) else {
                    readiness.append(Core.RuntimeReadiness(kind: kind,
                                                           cliURL: nil,
                                                           state: .cliMissing,
                                                           message: "\(module.descriptor.executableName ?? kind.rawValue) CLI was not found."))
                    continue
                }

                let runner = Core.Command.Runner(executableURL: cliURL)
                cliURLs[kind] = cliURL
                modules[kind] = module
                runtimes[kind] = module.makeClient(runner: runner)
                readiness.append(await module.readiness(cliURL: cliURL, runner: runner))
            }

            guard !runtimes.isEmpty else { return .cliMissing(runtimes: readiness) }
            return .ready(
                orchestrator: Core.Orchestrator(cliURLs: cliURLs, runtimes: runtimes, modules: modules),
                runtimes: readiness
            )
        }

        init(cliURLs: [Core.Runtime.Kind: URL],
             runtimes: [Core.Runtime.Kind: any RuntimeClient],
             modules: [Core.Runtime.Kind: any Core.Runtime.Module]? = nil) {
            self.runtimeCLIURLs = cliURLs
            self.runtimes = runtimes
            self.modules = modules ?? Dictionary(
                uniqueKeysWithValues: Core.Runtime.builtInModules
                    .filter { runtimes.keys.contains($0.descriptor.kind) }
                    .map { ($0.descriptor.kind, $0) }
            )
        }

        public var availableRuntimeDescriptors: [Core.Runtime.Descriptor] {
            runtimes.values.map(\.descriptor).sorted { $0.displayName < $1.displayName }
        }

        public func descriptor(for kind: Core.Runtime.Kind) -> Core.Runtime.Descriptor? {
            availableRuntimeDescriptors.first { $0.kind == kind } ?? modules[kind]?.descriptor
        }

        public func supportsRuntime(_ kind: Core.Runtime.Kind, capability: Core.Runtime.Capability = .containers) -> Bool {
            availableRuntimeDescriptors.first { $0.kind == kind }?.supports(capability) == true
        }

        internal func requireRuntime(_ kind: Core.Runtime.Kind,
                                     capability: Core.Runtime.Capability) throws -> any RuntimeClient {
            guard let runtime = runtimes[kind] else {
                throw Core.Runtime.UnsupportedCapability(kind: kind, capability: capability)
            }
            try runtime.descriptor.require(capability)
            return runtime
        }

        internal func requireRuntime<Capability>(_ kind: Core.Runtime.Kind,
                                                 capability: Core.Runtime.Capability,
                                                 as capabilityType: Capability.Type) throws -> Capability {
            let runtime = try requireRuntime(kind, capability: capability)
            guard let typed = runtime as? Capability else {
                throw Core.Runtime.UnsupportedCapability(kind: kind, capability: capability)
            }
            return typed
        }

        private func requireModule(_ kind: Core.Runtime.Kind,
                                   capability: Core.Runtime.Capability) throws -> any Core.Runtime.Module {
            guard let module = modules[kind] ?? Core.Runtime.module(for: kind) else {
                throw Core.Runtime.UnsupportedCapability(kind: kind, capability: capability)
            }
            try module.descriptor.require(capability)
            return module
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

        public func stats(ids: [String] = [],
                          runtimeKind: Core.Runtime.Kind) async throws -> [Core.Metrics.ContainerStats] {
            let runtime = try requireRuntime(runtimeKind,
                                             capability: .containers,
                                             as: (any RuntimeContainerClient).self)
            return try await runtime.stats(ids: ids).map { $0.scoped(to: runtimeKind) }
        }

        public func streamStats(ids: [String] = [],
                                runtimeKind: Core.Runtime.Kind) -> AsyncThrowingStream<[Core.Metrics.RuntimeStatsSnapshot], Swift.Error> {
            do {
                let runtime = try requireRuntime(runtimeKind,
                                                 capability: .containers,
                                                 as: (any RuntimeContainerClient).self)
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
            try await requireRuntime(runtimeKind,
                                     capability: .systemStatus,
                                     as: (any RuntimeSystemStatusClient).self).diskUsage()
        }

        public func systemProperties(runtimeKind: Core.Runtime.Kind) async throws -> Core.System.Properties {
            try await requireRuntime(runtimeKind,
                                     capability: .systemProperties,
                                     as: (any RuntimeSystemStatusClient).self).systemProperties()
        }

        public func dnsDomains(runtimeKind: Core.Runtime.Kind) async throws -> [String] {
            try await requireRuntime(runtimeKind,
                                     capability: .dnsManagement,
                                     as: (any RuntimeDNSClient).self).dnsDomains()
        }

        @discardableResult public func createDNSDomain(_ domain: String,
                                                       runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .dnsManagement,
                                     as: (any RuntimeDNSClient).self).createDNSDomain(domain)
        }

        @discardableResult public func deleteDNSDomain(_ domain: String,
                                                       runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .dnsManagement,
                                     as: (any RuntimeDNSClient).self).deleteDNSDomain(domain)
        }

        @discardableResult public func setRecommendedKernel(runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .kernelManagement,
                                     as: (any RuntimeKernelClient).self).setRecommendedKernel()
        }

        public func execCapture(_ id: String,
                                _ command: [String],
                                runtimeKind: Core.Runtime.Kind) async throws -> String {
            try await requireRuntime(runtimeKind,
                                     capability: .exec,
                                     as: (any RuntimeExecClient).self).execCapture(id, command)
        }

        @discardableResult public func copy(source: String,
                                            destination: String,
                                            runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .copy,
                                     as: (any RuntimeExecClient).self).copy(source: source, destination: destination)
        }

        public func terminalInvocation(containerID: String,
                                       shell: String,
                                       runtimeKind: Core.Runtime.Kind) throws -> Core.Command.Invocation {
            _ = try requireRuntime(runtimeKind, capability: .exec, as: (any RuntimeExecClient).self)
            let module = try requireModule(runtimeKind, capability: .exec)
            return module.terminalInvocation(containerID: containerID,
                                             shell: shell,
                                             cliURL: try requireCLIURL(for: runtimeKind))
        }

        public func streamSystemLogs(follow: Bool,
                                     last: Int? = 500,
                                     runtimeKind: Core.Runtime.Kind) -> AsyncThrowingStream<String, Swift.Error> {
            do {
                let runtime = try requireRuntime(runtimeKind,
                                                 capability: .systemLogs,
                                                 as: (any RuntimeSystemLogsClient).self)
                return runtime.streamSystemLogs(follow: follow, last: last)
            } catch {
                return AsyncThrowingStream { continuation in continuation.finish(throwing: error) }
            }
        }

        public func systemStatus(runtimeKind: Core.Runtime.Kind) async throws -> Core.System.Status {
            try await requireRuntime(runtimeKind,
                                     capability: .systemStatus,
                                     as: (any RuntimeSystemStatusClient).self).systemStatus()
        }

        private func previewCreateCommand(for request: Core.Container.CreateRequest) throws -> Core.Command.Preview {
            try requireRuntime(request.runtimeKind,
                               capability: .containers,
                               as: (any RuntimeContainerClient).self).previewCreateCommand(for: request)
        }

        public func previewCreateCommand(for document: Core.Schema.Document) throws -> Core.Command.Preview {
            let definition = schemaDefinition(for: document.operation, runtimeKind: document.runtimeKind)
            let request = try document.validatedRequest(definition: definition)
            return try previewCreateCommand(for: request)
        }

        @discardableResult private func createContainer(_ request: Core.Container.CreateRequest) async throws -> Core.Container.CreateResult {
            try await requireRuntime(request.runtimeKind,
                                     capability: .containers,
                                     as: (any RuntimeContainerClient).self).createContainer(request)
        }

        @discardableResult public func createContainer(_ document: Core.Schema.Document) async throws -> Core.Container.CreateResult {
            let definition = schemaDefinition(for: document.operation, runtimeKind: document.runtimeKind)
            let request = try document.validatedRequest(definition: definition)
            return try await createContainer(request)
        }

        @discardableResult private func recreateContainer(originalID: String,
                                                         replacement: Core.Container.CreateRequest,
                                                         rollback: Core.Container.CreateRequest) async throws -> Core.Container.CreateResult {
            guard replacement.runtimeKind == rollback.runtimeKind else {
                throw Core.Container.RecreateFailure(phase: .createReplacement,
                                                     recovery: .notNeeded,
                                                     primaryError: RecreatePreflightError.runtimeMismatch)
            }
            let runtime = try requireRuntime(replacement.runtimeKind,
                                             capability: .containers,
                                             as: (any RuntimeContainerClient).self)
            return try await runtime.recreateContainer(originalID: originalID,
                                                       replacement: replacement,
                                                       rollback: rollback)
        }

        @discardableResult public func recreateContainer(originalID: String,
                                                         replacement: Core.Schema.Document,
                                                         rollback: Core.Schema.Document) async throws -> Core.Container.CreateResult {
            let replacementDefinition = schemaDefinition(for: replacement.operation,
                                                         runtimeKind: replacement.runtimeKind)
            let rollbackDefinition = schemaDefinition(for: rollback.operation,
                                                      runtimeKind: rollback.runtimeKind)
            // Validate both documents before the runtime receives any destructive request.
            let replacementRequest = try replacement.validatedRequest(definition: replacementDefinition)
            let rollbackRequest = try rollback.validatedRequest(definition: rollbackDefinition)
            return try await recreateContainer(originalID: originalID,
                                               replacement: replacementRequest,
                                               rollback: rollbackRequest)
        }

        public func translateCompose(_ project: Core.Compose.Project,
                                     baseDirectory: URL?,
                                     runtimeKind: Core.Runtime.Kind) throws -> Core.Compose.ImportPlan {
            try requireRuntime(runtimeKind,
                               capability: .composeImport,
                               as: (any RuntimeComposeClient).self)
                .translateCompose(project, baseDirectory: baseDirectory)
        }

        private func imageDefaults(for request: Core.Container.CreateRequest,
                                  in images: [Core.Image.Resource]) throws -> Core.Container.ImageDefaults? {
            try requireRuntime(request.runtimeKind,
                               capability: .composeImport,
                               as: (any RuntimeComposeClient).self)
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
            return try requireRuntime(source,
                                      capability: .coreMigration,
                                      as: (any RuntimeComposeClient).self)
                .coreSwitchPlan(for: document.canonical.createRequest.effectiveName ?? "",
                                to: target.flatMap(descriptor(for:)))
        }

        public func coreSwitchPlan(for containerID: String,
                                   source: Core.Runtime.Kind,
                                   to target: Core.Runtime.Descriptor?) throws -> Core.Migration.Plan {
            try requireRuntime(source,
                               capability: .coreMigration,
                               as: (any RuntimeComposeClient).self)
                .coreSwitchPlan(for: containerID, to: target)
        }

        public func inspectImage(_ ref: String,
                                 runtimeKind: Core.Runtime.Kind) async throws -> [Core.Image.Resource] {
            let images = try await requireRuntime(runtimeKind,
                                                  capability: .images,
                                                  as: (any RuntimeImageClient).self).inspectImage(ref)
            return images.map { $0.scoped(to: runtimeKind) }
        }

        public func streamLogs(id: String,
                               runtimeKind: Core.Runtime.Kind,
                               follow: Bool = true,
                               tail: Int? = 200,
                               boot: Bool = false) -> AsyncThrowingStream<String, Swift.Error> {
            do {
                let runtime = try requireRuntime(runtimeKind,
                                                 capability: .containers,
                                                 as: (any RuntimeContainerClient).self)
                return runtime.streamLogs(id: id, follow: follow, tail: tail, boot: boot)
            } catch {
                return AsyncThrowingStream { continuation in continuation.finish(throwing: error) }
            }
        }

        public func streamPull(_ ref: String,
                               platform: String? = nil,
                               runtimeKind: Core.Runtime.Kind) -> AsyncThrowingStream<String, Swift.Error> {
            do {
                let runtime = try requireRuntime(runtimeKind,
                                                 capability: .images,
                                                 as: (any RuntimeImageClient).self)
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
                let runtime = try requireRuntime(runtimeKind,
                                                 capability: .imageBuild,
                                                 as: (any RuntimeImageClient).self)
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
                let runtime = try requireRuntime(runtimeKind,
                                                 capability: .imagePush,
                                                 as: (any RuntimeImageClient).self)
                return runtime.streamPush(ref, platform: platform)
            } catch {
                return AsyncThrowingStream { continuation in continuation.finish(throwing: error) }
            }
        }

        @discardableResult public func runContainer(arguments: [String],
                                                    runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .containers,
                                     as: (any RuntimeContainerClient).self).runContainer(arguments: arguments)
        }

        @discardableResult public func performSystemAction(_ action: Core.Runtime.SystemAction,
                                                           runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .serviceControl,
                                     as: (any RuntimeServiceControlClient).self).performSystemAction(action)
        }

        public func registries(runtimeKind: Core.Runtime.Kind) async throws -> [Core.Registry.Login] {
            try await requireRuntime(runtimeKind,
                                     capability: .registries,
                                     as: (any RuntimeRegistryClient).self).registries().map { $0.scoped(to: runtimeKind) }
        }

        @discardableResult public func registryLogin(server: String,
                                                     username: String,
                                                     password: String,
                                                     runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .registries,
                                     as: (any RuntimeRegistryClient).self)
                .registryLogin(server: server, username: username, password: password)
        }

        @discardableResult public func registryLogout(server: String,
                                                      runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .registries,
                                     as: (any RuntimeRegistryClient).self).registryLogout(server: server)
        }

        @discardableResult public func deleteImages(_ refs: [String],
                                                    runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .images,
                                     as: (any RuntimeImageClient).self).deleteImages(refs)
        }

        @discardableResult public func tagImage(source: String,
                                                target: String,
                                                runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .images,
                                     as: (any RuntimeImageClient).self).tagImage(source: source, target: target)
        }

        @discardableResult public func saveImages(_ refs: [String],
                                                  to output: String,
                                                  runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .imageArchive,
                                     as: (any RuntimeImageClient).self).saveImages(refs, to: output)
        }

        @discardableResult public func loadImages(from input: String,
                                                  runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .imageArchive,
                                     as: (any RuntimeImageClient).self).loadImages(from: input)
        }

        @discardableResult public func exportContainer(_ id: String,
                                                       to output: String,
                                                       runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .containerExport,
                                     as: (any RuntimeImageClient).self).exportContainer(id, to: output)
        }

        @discardableResult public func pruneImages(all: Bool = false,
                                                   runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .images,
                                     as: (any RuntimeImageClient).self).pruneImages(all: all)
        }

        @discardableResult public func start(_ ids: [String],
                                             runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .containers,
                                     as: (any RuntimeContainerClient).self).start(ids)
        }

        @discardableResult public func stop(_ ids: [String],
                                            runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .containers,
                                     as: (any RuntimeContainerClient).self).stop(ids)
        }

        @discardableResult public func deleteContainers(_ ids: [String],
                                                        force: Bool,
                                                        runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .containers,
                                     as: (any RuntimeContainerClient).self).deleteContainers(ids, force: force)
        }

        @discardableResult public func pruneContainers(runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .containers,
                                     as: (any RuntimeContainerClient).self).pruneContainers()
        }

        @discardableResult public func pruneVolumes(runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .volumes,
                                     as: (any RuntimeVolumeClient).self).pruneVolumes()
        }

        @discardableResult public func pruneNetworks(runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .networks,
                                     as: (any RuntimeNetworkClient).self).pruneNetworks()
        }

        @discardableResult public func createVolume(name: String,
                                                    size: String? = nil,
                                                    labels: [String: String] = [:],
                                                    runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .volumes,
                                     as: (any RuntimeVolumeClient).self)
                .createVolume(name: name, size: size, labels: labels)
        }

        @discardableResult public func deleteVolumes(_ names: [String],
                                                     runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .volumes,
                                     as: (any RuntimeVolumeClient).self).deleteVolumes(names)
        }

        @discardableResult public func createNetwork(name: String,
                                                     subnet: String? = nil,
                                                     internalOnly: Bool = false,
                                                     labels: [String: String] = [:],
                                                     runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .networks,
                                     as: (any RuntimeNetworkClient).self)
                .createNetwork(name: name,
                               subnet: subnet,
                               internalOnly: internalOnly,
                               labels: labels)
        }

        @discardableResult public func deleteNetworks(_ names: [String],
                                                      runtimeKind: Core.Runtime.Kind) async throws -> Data {
            try await requireRuntime(runtimeKind,
                                     capability: .networks,
                                     as: (any RuntimeNetworkClient).self).deleteNetworks(names)
        }
    }
}

private enum RecreatePreflightError: Error {
    case runtimeMismatch
}

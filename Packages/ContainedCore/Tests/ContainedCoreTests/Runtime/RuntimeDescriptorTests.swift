import Foundation
import Testing
@testable import ContainedCore

@Suite("Runtime descriptor contracts")
struct RuntimeDescriptorTests {
    @Test func openRuntimeKindsCanAdvertiseCapabilities() throws {
        let descriptor = Core.Runtime.Descriptor(
            kind: Core.Runtime.Kind(rawValue: "future-runtime"),
            displayName: "Future runtime",
            executableName: "future",
            capabilities: [.containers, .composeImport]
        )

        #expect(descriptor.supports(.containers))
        #expect(descriptor.supports(.composeImport))
        #expect(!descriptor.supports(.imageBuild))
        try descriptor.require(.containers)
    }

    @Test func unsupportedCapabilityIsDisplayNeutralPackageError() {
        let error = Core.Runtime.UnsupportedCapability(
            kind: .docker,
            capability: .imageBuild
        )

        #expect(error.packageName == "ContainedCore")
        #expect(error.packageErrorCode == "unsupportedRuntimeCapability")
        #expect(error.packageErrorContext["kind"] == Core.Runtime.Kind.docker.rawValue)
        #expect(error.packageErrorContext["capability"] == String(Core.Runtime.Capability.imageBuild.rawValue))
    }

    @Test func defaultCoreSwitchPlanIsDisplayNeutral() throws {
        let runtime = UnavailableRuntime(
            descriptor: Core.Runtime.Descriptor(
                kind: Core.Runtime.Kind(rawValue: "future-runtime"),
                displayName: "Future runtime",
                executableName: "future",
                capabilities: [.containers]
            )
        )

        let plan = try runtime.coreSwitchPlan(for: "web", to: .appleContainer)

        #expect(!plan.isAvailable)
        #expect(plan.unavailableReason == .exportImportUnsupported)
        #expect(plan.context["source"] == "future-runtime")
        #expect(plan.context["target"] == Core.Runtime.Kind.appleContainer.rawValue)
    }

    @Test func orchestratorAggregatesAndScopesContainersAcrossRuntimes() async throws {
        let apple = UnavailableRuntime(
            descriptor: .appleContainer,
            containers: [.placeholder(id: "web", image: "nginx:latest", runtimeKind: .appleContainer)]
        )
        let docker = UnavailableRuntime(
            descriptor: .docker,
            containers: [.placeholder(id: "web", image: "nginx:latest", runtimeKind: .docker)]
        )
        let orchestrator = Core.Orchestrator(
            cliURLs: [
                .appleContainer: URL(fileURLWithPath: "/usr/bin/container"),
                .docker: URL(fileURLWithPath: "/usr/local/bin/docker"),
            ],
            runtimes: [
                .appleContainer: apple,
                .docker: docker,
            ] as [Core.Runtime.Kind: any RuntimeClient]
        )

        let snapshots = try await orchestrator.listRuntimeContainers()

        #expect(snapshots.count == 2)
        #expect(Set(snapshots.map { $0.id }) == ["web"])
        #expect(Set(snapshots.map { $0.scopedID }) == [
            "apple-container::web",
            "docker::web",
        ])
        #expect(Set(snapshots.map { $0.runtimeKind }) == [
            Core.Runtime.Kind.appleContainer,
            Core.Runtime.Kind.docker,
        ])
    }

    @Test func orchestratorPreservesPartialInventoryWhenOneRuntimeFails() async throws {
        let apple = UnavailableRuntime(
            descriptor: .appleContainer,
            containers: [.placeholder(id: "apple-web", image: "nginx:latest", runtimeKind: .appleContainer)]
        )
        let docker = UnavailableRuntime(
            descriptor: .docker,
            listError: TestStubError.unused
        )
        let orchestrator = Core.Orchestrator(
            cliURLs: [
                .appleContainer: URL(fileURLWithPath: "/usr/bin/container"),
                .docker: URL(fileURLWithPath: "/usr/local/bin/docker"),
            ],
            runtimes: [
                .appleContainer: apple,
                .docker: docker,
            ] as [Core.Runtime.Kind: any RuntimeClient]
        )

        let snapshots = try await orchestrator.listRuntimeContainers()

        #expect(snapshots.map { $0.scopedID } == ["apple-container::apple-web"])
    }

    @Test func orchestratorTerminalInvocationRoutesByRuntimeKind() throws {
        let orchestrator = Core.Orchestrator(
            cliURLs: [
                .appleContainer: URL(fileURLWithPath: "/usr/bin/container"),
                .docker: URL(fileURLWithPath: "/usr/local/bin/docker"),
            ],
            runtimes: [
                .appleContainer: UnavailableRuntime(descriptor: .appleContainer),
                .docker: UnavailableRuntime(descriptor: .docker),
            ] as [Core.Runtime.Kind: any RuntimeClient]
        )

        let docker = try orchestrator.terminalInvocation(containerID: "web",
                                                         shell: "/bin/sh",
                                                         runtimeKind: .docker)
        let apple = try orchestrator.terminalInvocation(containerID: "web",
                                                        shell: "/bin/sh",
                                                        runtimeKind: .appleContainer)

        #expect(docker.executableURL.path == "/usr/local/bin/docker")
        #expect(docker.arguments == DockerCommands.execInteractive("web", shell: "/bin/sh"))
        #expect(apple.executableURL.path == "/usr/bin/container")
        #expect(apple.arguments == ContainerCommands.execInteractive("web", shell: "/bin/sh"))
    }

    @Test func orchestratorDoesNotFabricateUnregisteredDescriptors() {
        let orchestrator = Core.Orchestrator(
            cliURLs: [.appleContainer: URL(fileURLWithPath: "/usr/bin/container")],
            runtimes: [.appleContainer: UnavailableRuntime(descriptor: .appleContainer)] as [Core.Runtime.Kind: any RuntimeClient]
        )

        #expect(orchestrator.descriptor(for: .appleContainer) == .appleContainer)
        #expect(orchestrator.descriptor(for: .docker) == nil)
        #expect(orchestrator.descriptor(for: Core.Runtime.Kind(rawValue: "future-runtime")) == nil)
    }

    @Test func serviceControlRequiresExplicitCapability() async {
        let orchestrator = Core.Orchestrator(
            cliURLs: [.docker: URL(fileURLWithPath: "/usr/local/bin/docker")],
            runtimes: [.docker: UnavailableRuntime(descriptor: .docker)] as [Core.Runtime.Kind: any RuntimeClient]
        )

        await #expect(throws: Core.Runtime.UnsupportedCapability.self) {
            _ = try await orchestrator.performSystemAction(.start, runtimeKind: .docker)
        }
    }
}

private struct UnavailableRuntime: RuntimeClient,
                                   RuntimeContainerClient,
                                   RuntimeSystemStatusClient,
                                   RuntimeDNSClient,
                                   RuntimeKernelClient,
                                   RuntimeExecClient,
                                   RuntimeSystemLogsClient,
                                   RuntimeComposeClient,
                                   RuntimeNetworkClient,
                                   RuntimeVolumeClient,
                                   RuntimeImageClient,
                                   RuntimeRegistryClient,
                                   RuntimeServiceControlClient {
    let descriptor: Core.Runtime.Descriptor
    var containers: [Core.Container.Snapshot] = []
    var listError: TestStubError?

    func listContainers(all: Bool) async throws -> [Core.Container.Snapshot] {
        if let listError { throw listError }
        return containers
    }
    func stats(ids: [String]) async throws -> [Core.Metrics.ContainerStats] { [] }
    func streamStats(ids: [String]) -> AsyncThrowingStream<[Core.Metrics.RuntimeStatsSnapshot], Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func diskUsage() async throws -> Core.System.DiskUsage { throw TestStubError.unused }
    func systemProperties() async throws -> Core.System.Properties { throw TestStubError.unused }
    func dnsDomains() async throws -> [String] { [] }
    func createDNSDomain(_ domain: String) async throws -> Data { throw TestStubError.unused }
    func deleteDNSDomain(_ domain: String) async throws -> Data { throw TestStubError.unused }
    func setRecommendedKernel() async throws -> Data { throw TestStubError.unused }
    func execCapture(_ id: String, _ command: [String]) async throws -> String { "" }
    func copy(source: String, destination: String) async throws -> Data { throw TestStubError.unused }
    func streamSystemLogs(follow: Bool, last: Int?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func systemStatus() async throws -> Core.System.Status { throw TestStubError.unused }
    func networks() async throws -> [Core.Network.Resource] { [] }
    func volumes() async throws -> [Core.Volume.Resource] { [] }
    func images() async throws -> [Core.Image.Resource] { [] }
    func inspectImage(_ ref: String) async throws -> [Core.Image.Resource] { [] }
    func streamLogs(id: String, follow: Bool, tail: Int?, boot: Bool) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func streamPull(_ ref: String, platform: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func streamBuild(context: String, tag: String?, dockerfile: String?,
                     buildArgs: [String: String], noCache: Bool,
                     platform: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func streamPush(_ ref: String, platform: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func runContainer(arguments: [String]) async throws -> Data { throw TestStubError.unused }
    func performSystemAction(_ action: Core.Runtime.SystemAction) async throws -> Data { throw TestStubError.unused }
    func registries() async throws -> [Core.Registry.Login] { [] }
    func registryLogin(server: String, username: String, password: String) async throws -> Data { throw TestStubError.unused }
    func registryLogout(server: String) async throws -> Data { throw TestStubError.unused }
    func deleteImages(_ refs: [String]) async throws -> Data { throw TestStubError.unused }
    func tagImage(source: String, target: String) async throws -> Data { throw TestStubError.unused }
    func saveImages(_ refs: [String], to output: String) async throws -> Data { throw TestStubError.unused }
    func loadImages(from input: String) async throws -> Data { throw TestStubError.unused }
    func exportContainer(_ id: String, to output: String) async throws -> Data { throw TestStubError.unused }
    func pruneImages(all: Bool) async throws -> Data { throw TestStubError.unused }
    func start(_ ids: [String]) async throws -> Data { throw TestStubError.unused }
    func stop(_ ids: [String]) async throws -> Data { throw TestStubError.unused }
    func deleteContainers(_ ids: [String], force: Bool) async throws -> Data { throw TestStubError.unused }
    func pruneContainers() async throws -> Data { throw TestStubError.unused }
    func pruneVolumes() async throws -> Data { throw TestStubError.unused }
    func pruneNetworks() async throws -> Data { throw TestStubError.unused }
    func createVolume(name: String, size: String?, labels: [String: String]) async throws -> Data { throw TestStubError.unused }
    func deleteVolumes(_ names: [String]) async throws -> Data { throw TestStubError.unused }
    func createNetwork(name: String, subnet: String?, internalOnly: Bool,
                       labels: [String: String]) async throws -> Data { throw TestStubError.unused }
    func deleteNetworks(_ names: [String]) async throws -> Data { throw TestStubError.unused }
}

private enum TestStubError: Error {
    case unused
}

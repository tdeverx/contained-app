import Foundation
import Testing
import ContainedCore
@testable import ContainedRuntime

@Suite("Runtime descriptor contracts")
struct RuntimeDescriptorTests {
    @Test func openRuntimeKindsCanAdvertiseCapabilities() throws {
        let descriptor = RuntimeDescriptor(
            kind: RuntimeKind(rawValue: "future-runtime"),
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
        let error = UnsupportedRuntimeCapability(
            kind: .dockerCompatible,
            capability: .imageBuild
        )

        #expect(error.packageName == "ContainedRuntime")
        #expect(error.packageErrorCode == "unsupportedRuntimeCapability")
        #expect(error.packageErrorContext["kind"] == RuntimeKind.dockerCompatible.rawValue)
        #expect(error.packageErrorContext["capability"] == String(RuntimeCapability.imageBuild.rawValue))
    }

    @Test func defaultCoreSwitchPlanIsDisplayNeutral() throws {
        let runtime = UnavailableRuntime(
            descriptor: RuntimeDescriptor(
                kind: RuntimeKind(rawValue: "future-runtime"),
                displayName: "Future runtime",
                executableName: "future",
                capabilities: [.containers]
            )
        )

        let plan = try runtime.coreSwitchPlan(for: "web", to: .appleContainer)

        #expect(!plan.isAvailable)
        #expect(plan.unavailableReason == .exportImportUnsupported)
        #expect(plan.context["source"] == "future-runtime")
        #expect(plan.context["target"] == RuntimeKind.appleContainer.rawValue)
    }
}

private struct UnavailableRuntime: ContainerRuntimeClient {
    let descriptor: RuntimeDescriptor

    func listContainers(all: Bool) async throws -> [ContainerSnapshot] { [] }
    func stats(ids: [String]) async throws -> [ContainerStats] { [] }
    func streamStats(ids: [String]) -> AsyncThrowingStream<[RuntimeStatsSnapshot], Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func diskUsage() async throws -> DiskUsage { throw TestStubError.unused }
    func systemProperties() async throws -> SystemProperties { throw TestStubError.unused }
    func dnsDomains() async throws -> [String] { [] }
    func createDNSDomain(_ domain: String) async throws -> Data { throw TestStubError.unused }
    func deleteDNSDomain(_ domain: String) async throws -> Data { throw TestStubError.unused }
    func setRecommendedKernel() async throws -> Data { throw TestStubError.unused }
    func execCapture(_ id: String, _ command: [String]) async throws -> String { "" }
    func copy(source: String, destination: String) async throws -> Data { throw TestStubError.unused }
    func streamSystemLogs(follow: Bool, last: Int?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func systemStatus() async throws -> SystemStatus { throw TestStubError.unused }
    func networks() async throws -> [NetworkResource] { [] }
    func volumes() async throws -> [VolumeResource] { [] }
    func images() async throws -> [ImageResource] { [] }
    func inspectImage(_ ref: String) async throws -> [ImageResource] { [] }
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
    func performSystemAction(_ action: String) async throws -> Data { throw TestStubError.unused }
    func registries() async throws -> [RegistryLogin] { [] }
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

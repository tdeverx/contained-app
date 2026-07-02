import Foundation
import Testing
import ContainedCore
import ContainedRuntime
import AppleContainerRuntime

@Suite("Runtime adapter boundary")
struct AppleContainerRuntimeTests {
    @Test func runtimeKindAcceptsFutureAdapters() throws {
        let descriptor = RuntimeDescriptor(kind: RuntimeKind(rawValue: "future-engine"),
                                           displayName: "Future Engine",
                                           capabilities: [.containers])

        #expect(descriptor.kind.rawValue == "future-engine")
        #expect(descriptor.executableName == nil)
        #expect(descriptor.supports(.containers))
        #expect(!descriptor.supports(.imageBuild))
        #expect(throws: UnsupportedRuntimeCapability.self) {
            try descriptor.require(.imageBuild)
        }
        do {
            try descriptor.require(.imageBuild)
        } catch let error as UnsupportedRuntimeCapability {
            #expect(error.packageName == "ContainedRuntime")
            #expect(error.packageErrorCode == "unsupportedRuntimeCapability")
            #expect(error.packageErrorContext["kind"] == "future-engine")
        }
    }

    @Test func commandErrorsExposePackageCodesAndContext() {
        let error = CommandError.nonZeroExit(code: 42, stderr: "boom", command: "container list")

        #expect(error.packageName == "ContainedRuntime")
        #expect(error.packageErrorCode == "nonZeroExit")
        #expect(error.packageErrorContext["code"] == "42")
        #expect(error.packageErrorContext["stderr"] == "boom")
        #expect(error.packageErrorContext["command"] == "container list")
    }

    @Test func appleCLIVersionParsingAndSupport() {
        let version = AppleContainerCLILocator.parseVersion(
            "container CLI version 1.0.0 (build: release, commit: ee848e3)"
        )

        #expect(version == "1.0.0")
        #expect(AppleContainerCLILocator.isSupported(version))
        #expect(!AppleContainerCLILocator.isSupported("0.10.0"))
        #expect(!AppleContainerCLILocator.isSupported(nil))
    }

    @Test func appleRuntimeDescriptorAdvertisesCurrentCapabilities() throws {
        let descriptor = RuntimeDescriptor.appleContainer

        #expect(descriptor.kind == .appleContainer)
        #expect(descriptor.displayName == "Apple container")
        #expect(descriptor.executableName == "container")
        #expect(descriptor.supports([.containers, .images, .volumes, .networks]))
        #expect(descriptor.supports([.systemStatus, .systemLogs, .exec, .copy]))
        try descriptor.require([.imageBuild, .imagePush, .registries])
    }

    @Test func appleClientConformsToRuntimeClient() async throws {
        let runner = MockCommandRunner(result: .success(try Fixture.data("list")))
        let runtime: any ContainerRuntimeClient = AppleContainerClient(runner: runner)

        #expect(runtime.descriptor == .appleContainer)
        let containers = try await runtime.listContainers(all: true)
        #expect(containers.first?.id == "fixture-web")
    }

    @Test func appleClientDecodesThroughMock() async throws {
        let runner = MockCommandRunner(result: .success(try Fixture.data("list")))
        let client = AppleContainerClient(runner: runner)

        let containers = try await client.listContainers()
        #expect(containers.first?.id == "fixture-web")
    }

    @Test func appleClientMapsDecodeFailure() async throws {
        let bad = MockCommandRunner(result: .success(Data("Error: content with digest sha256:...".utf8)))
        let client = AppleContainerClient(runner: bad)

        await #expect(throws: CommandError.self) {
            _ = try await client.listContainers()
        }
    }

    @Test func appleClientPropagatesNonZeroExit() async throws {
        let failing = MockCommandRunner(result: .failure(.nonZeroExit(code: 1,
                                                                      stderr: "boom",
                                                                      command: "list")))
        let client = AppleContainerClient(runner: failing)

        await #expect(throws: CommandError.self) {
            _ = try await client.listContainers()
        }
    }

    @Test func appleClientImagesDecode() async throws {
        let runner = MockCommandRunner(result: .success(try Fixture.data("image-inspect")))
        let client = AppleContainerClient(runner: runner)

        let images = try await client.images()
        #expect(!images.isEmpty)
    }

    @Test func appleClientStreamLogsYieldsChunks() async throws {
        let runner = MockCommandRunner(result: .success(Data()), streamChunks: ["line one\n", "line two\n"])
        let client = AppleContainerClient(runner: runner)
        var received: [String] = []

        for try await chunk in client.streamLogs(id: "web") { received.append(chunk) }

        #expect(received == ["line one\n", "line two\n"])
    }

    @Test func appleStatsTableParserUsesLatestANSIFrame() throws {
        let samples = ContainerStatsTableParser.parseLatestFrame(in: try Fixture.string("stats-table"))

        #expect(samples.count == 2)
        #expect(samples[0].id == "buildkit")
        #expect(samples[0].memoryUsageBytes == 108_202_557)
        #expect(samples[0].memoryLimitBytes == 2_147_483_648)
        #expect(samples[0].networkRxBytes == 486_953)
        #expect(samples[0].networkTxBytes == 604)
        #expect(samples[0].blockReadBytes == 62_044_242)
        #expect(samples[0].blockWriteBytes == 24_576)
        #expect(samples[0].numProcesses == 17)
        #expect(samples[1].id == "sonarrhd")
        #expect(abs((samples[1].cpuCoreFraction ?? 0) - 0.0006) < 0.00001)
    }

    @Test func appleClientStreamsTypedStatsSnapshots() async throws {
        let stream = try Fixture.string("stats-table")
        let runner = MockCommandRunner(result: .success(Data()), streamChunks: [stream])
        let runtime: any ContainerRuntimeClient = AppleContainerClient(runner: runner)
        var received: [[RuntimeStatsSnapshot]] = []

        for try await samples in runtime.streamStats(ids: ["buildkit", "sonarrhd"]) {
            received.append(samples)
        }

        #expect(received.count == 1)
        #expect(received.first?.map(\.id) == ["buildkit", "sonarrhd"])
    }
}

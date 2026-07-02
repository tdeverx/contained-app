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
        #expect(descriptor.supports(.composeImport))
        #expect(!descriptor.supports(.coreMigration))
        try descriptor.require([.imageBuild, .imagePush, .registries])
    }

    @Test func appleCreateTranslatorBuildsPreviewAndResult() {
        var request = ContainerCreateRequest()
        request.image = "nginx:latest"
        request.name = "web"
        request.cpus = "2"

        let preview = AppleContainerCreateTranslator.preview(for: request)
        #expect(preview.command == ["run", "--detach", "--name", "web", "--cpus", "2", "nginx:latest"])
        #expect(preview.warnings.isEmpty)

        let namedResult = AppleContainerCreateTranslator.result(from: Data("generated-id\n".utf8), request: request)
        #expect(namedResult.id == "web")

        request.name = ""
        let generatedResult = AppleContainerCreateTranslator.result(from: Data("generated-id\n".utf8), request: request)
        #expect(generatedResult.id == "generated-id")
    }

    @Test func appleComposeTranslationReturnsStandardCreateFields() throws {
        let yaml = """
        services:
          app:
            image: example/app:1
            container_name: demo-app
            command: ["serve", "--port", "8080"]
            ports:
              - "18080:8080"
            volumes:
              - "./config:/config:ro"
            environment:
              TZ: Europe/London
            restart: always
            healthcheck:
              test: ["CMD", "curl", "-f", "http://localhost:8080"]
              retries: 2
        """
        let project = try ComposeParser.parse(yaml, projectName: "demo")
        let base = URL(filePath: "/opt/stacks/demo", directoryHint: .isDirectory)
        let plan = AppleContainerCreateTranslator.composePlan(for: project, baseDirectory: base)
        let item = try #require(plan.items.first)

        #expect(item.request.runtimeKind == .appleContainer)
        #expect(item.request.name == "demo-app")
        #expect(item.request.image == "example/app:1")
        #expect(item.request.command == ["serve", "--port", "8080"])
        #expect(item.request.ports.map(\.spec) == ["18080:8080"])
        #expect(item.request.volumes.map(\.spec) == ["/opt/stacks/demo/config:/config:ro"])
        #expect(item.request.env.map { "\($0.key)=\($0.value)" } == ["TZ=Europe/London"])
        #expect(item.request.restart == .always)
        #expect(item.request.labels.contains { $0.key == "contained.stack" && $0.value == "demo" })
        #expect(item.healthCheck?.command == ["curl", "-f", "http://localhost:8080"])
        #expect(item.healthCheck?.retries == 2)
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

import Foundation
import Testing
@testable import ContainedCore

@Suite("Runtime adapter boundary")
struct AppleContainerAdapterTests {
    @Test func runtimeKindAcceptsFutureAdapters() throws {
        let descriptor = Core.Runtime.Descriptor(kind: Core.Runtime.Kind(rawValue: "future-runtime"),
                                           displayName: "Future Runtime",
                                           capabilities: [.containers])

        #expect(descriptor.kind.rawValue == "future-runtime")
        #expect(descriptor.executableName == nil)
        #expect(descriptor.supports(.containers))
        #expect(!descriptor.supports(.imageBuild))
        #expect(throws: Core.Runtime.UnsupportedCapability.self) {
            try descriptor.require(.imageBuild)
        }
        do {
            try descriptor.require(.imageBuild)
        } catch let error as Core.Runtime.UnsupportedCapability {
            #expect(error.packageName == "ContainedCore")
            #expect(error.packageErrorCode == "unsupportedRuntimeCapability")
            #expect(error.packageErrorContext["kind"] == "future-runtime")
        }
    }

    @Test func commandErrorsExposePackageCodesAndContext() {
        let error = Core.Command.Error.nonZeroExit(code: 42, stderr: "boom", command: "container list")

        #expect(error.packageName == "ContainedCore")
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
        let descriptor = Core.Runtime.Descriptor.appleContainer

        #expect(descriptor.kind == .appleContainer)
        #expect(descriptor.displayName == "Apple container")
        #expect(descriptor.executableName == "container")
        #expect(descriptor.supports([.containers, .images, .volumes, .networks]))
        #expect(descriptor.supports([.systemStatus, .systemLogs, .exec, .copy]))
        #expect(descriptor.supports(.composeImport))
        #expect(!descriptor.supports(.coreMigration))
        try descriptor.require([.imageBuild, .imagePush, .registries])
    }

    @Test func appleModuleReadinessDistinguishesUnsupportedAndStopped() async {
        let module = AppleContainerRuntimeModule()
        let ready = await module.readiness(
            cliURL: URL(fileURLWithPath: "/usr/local/bin/container"),
            runner: CommandMapRunner(outputs: [
                ContainerCommands.version: .success(Data("container CLI version 1.0.0\n".utf8)),
                ContainerCommands.systemStatus: .success(Data(#"{"status":"running"}"#.utf8)),
            ])
        )

        #expect(ready.kind == .appleContainer)
        #expect(ready.version == "1.0.0")
        #expect(ready.state == .ready)

        let unsupported = await module.readiness(
            cliURL: URL(fileURLWithPath: "/usr/local/bin/container"),
            runner: CommandMapRunner(outputs: [
                ContainerCommands.version: .success(Data("container CLI version 0.9.0\n".utf8)),
            ])
        )

        #expect(unsupported.version == "0.9.0")
        #expect(unsupported.state == .unsupported)

        let stopped = await module.readiness(
            cliURL: URL(fileURLWithPath: "/usr/local/bin/container"),
            runner: CommandMapRunner(outputs: [
                ContainerCommands.version: .success(Data("container CLI version 1.0.0\n".utf8)),
                ContainerCommands.systemStatus: .success(Data(#"{"status":"stopped"}"#.utf8)),
            ])
        )

        #expect(stopped.state == .endpointUnavailable)
    }

    @Test func appleCreateTranslatorBuildsPreviewAndResult() {
        var request = Core.Container.CreateRequest(runtimeKind: .appleContainer)
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
        let project = try Core.Compose.Parser.parse(yaml, projectName: "demo")
        let base = URL(filePath: "/opt/stacks/demo", directoryHint: .isDirectory)
        let plan = AppleContainerCreateTranslator.composePlan(for: project, baseDirectory: base)
        let item = try #require(plan.items.first)
        let request = try item.document.validatedRequest()

        #expect(request.runtimeKind == .appleContainer)
        #expect(request.name == "demo-app")
        #expect(request.image == "example/app:1")
        #expect(request.command == ["serve", "--port", "8080"])
        #expect(request.ports.map(\.spec) == ["18080:8080"])
        #expect(request.volumes.map(\.spec) == ["/opt/stacks/demo/config:/config:ro"])
        #expect(request.env.map { "\($0.key)=\($0.value)" } == ["TZ=Europe/London"])
        #expect(request.restart == .always)
        #expect(request.labels.contains { $0.key == "contained.stack" && $0.value == "demo" })
        #expect(item.healthCheck?.command == ["curl", "-f", "http://localhost:8080"])
        #expect(item.healthCheck?.retries == 2)
    }

    @Test func appleClientConformsToRuntimeContainerClient() async throws {
        let runner = MockCommandRunner(result: .success(try Fixture.data("list")))
        let runtime: any RuntimeContainerClient = AppleContainerClient(runner: runner)

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

        await #expect(throws: Core.Command.Error.self) {
            _ = try await client.listContainers()
        }
    }

    @Test func appleClientPropagatesNonZeroExit() async throws {
        let failing = MockCommandRunner(result: .failure(.nonZeroExit(code: 1,
                                                                      stderr: "boom",
                                                                      command: "list")))
        let client = AppleContainerClient(runner: failing)

        await #expect(throws: Core.Command.Error.self) {
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
        let runtime: any RuntimeContainerClient = AppleContainerClient(runner: runner)
        var received: [[Core.Metrics.RuntimeStatsSnapshot]] = []

        for try await samples in runtime.streamStats(ids: ["buildkit", "sonarrhd"]) {
            received.append(samples)
        }

        #expect(received.count == 1)
        #expect(received.first?.map(\.id) == ["buildkit", "sonarrhd"])
    }
}

private struct CommandMapRunner: Core.Command.Running {
    var outputs: [[String]: Result<Data, Core.Command.Error>]

    func run(_ arguments: [String],
             stdin: Data?,
             priority: Core.Command.ExecutionPriority) async throws -> Data {
        try (outputs[arguments] ?? .failure(.nonZeroExit(
            code: 127,
            stderr: "unexpected command: \(arguments.joined(separator: " "))",
            command: arguments.joined(separator: " ")
        ))).get()
    }

    func stream(_ arguments: [String],
                priority: Core.Command.ExecutionPriority) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

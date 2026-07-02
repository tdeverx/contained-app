import Foundation
import Testing
@testable import ContainedCore

@Suite("Command builders and client behavior")
struct CommandTests {

    @Test func listArgv() {
        #expect(ContainerCommands.list(all: false) == ["list", "--format", "json"])
        #expect(ContainerCommands.list(all: true) == ["list", "--all", "--format", "json"])
    }

    @Test func lifecycleArgv() {
        #expect(ContainerCommands.start(["a", "b"]) == ["start", "a", "b"])
        #expect(ContainerCommands.stop(["a"], signal: "SIGTERM", time: 5) == ["stop", "--signal", "SIGTERM", "--time", "5", "a"])
        #expect(ContainerCommands.deleteContainers(["a"], force: true) == ["delete", "--force", "a"])
    }

    @Test func logsArgv() {
        #expect(ContainerCommands.logs("web", follow: true, tail: 100) == ["logs", "--follow", "-n", "100", "web"])
        #expect(ContainerCommands.logs("web", boot: true) == ["logs", "--boot", "web"])
    }

    @Test func systemArgv() {
        #expect(ContainerCommands.systemStatus == ["system", "status", "--format", "json"])
        #expect(ContainerCommands.systemDF == ["system", "df", "--format", "json"])
        #expect(ContainerCommands.imageInspect(["alpine"]) == ["image", "inspect", "alpine"])
    }

    @Test func imageSaveLoadAndExportArgv() {
        #expect(ContainerCommands.imageSave(refs: ["nginx:latest", "alpine"], output: "/tmp/i.tar")
                == ["image", "save", "nginx:latest", "alpine", "--output", "/tmp/i.tar"])
        #expect(ContainerCommands.imageLoad(input: "/tmp/i.tar") == ["image", "load", "--input", "/tmp/i.tar"])
        #expect(ContainerCommands.containerExport("web", output: "/tmp/fs.tar")
                == ["export", "--output", "/tmp/fs.tar", "web"])
    }

    @Test func systemKernelAndDNSArgv() {
        #expect(ContainerCommands.systemDNSList == ["system", "dns", "list", "--format", "json"])
        #expect(ContainerCommands.systemDNSCreate("test.local") == ["system", "dns", "create", "test.local"])
        #expect(ContainerCommands.systemDNSDelete("test.local") == ["system", "dns", "delete", "test.local"])
        #expect(ContainerCommands.systemKernelSetRecommended == ["system", "kernel", "set", "--recommended"])
    }

    @Test func composeDependsOnAndOrdering() throws {
        let yaml = """
        services:
          web:
            image: nginx
            depends_on:
              db:
                condition: service_healthy
          db:
            image: postgres
            healthcheck:
              test: ["CMD-SHELL", "pg_isready"]
              interval: 10s
              retries: 5
        """
        let project = try ComposeParser.parse(yaml, projectName: "demo")
        let web = project.services.first { $0.key == "web" }
        let db = project.services.first { $0.key == "db" }
        #expect(web?.dependsOn.first?.service == "db")
        #expect(web?.dependsOn.first?.condition == .healthy)
        #expect(db?.healthcheck?.test == ["sh", "-c", "pg_isready"])
        #expect(db?.healthcheck?.intervalSeconds == 10)
        #expect(db?.healthcheck?.retries == 5)
        // db must launch before web
        let (order, cycle) = ComposeOrder.sorted(project.services)
        #expect(!cycle)
        #expect(order.firstIndex(of: "db")! < order.firstIndex(of: "web")!)
    }

    @Test func composeCycleFallsBack() {
        let a = ComposeService(key: "a", name: "a", image: "x", platform: nil, command: nil, ports: [], volumes: [],
                               environment: [], restart: nil,
                               dependsOn: [ComposeDependency(service: "b", condition: .started)], healthcheck: nil)
        let b = ComposeService(key: "b", name: "b", image: "x", platform: nil, command: nil, ports: [], volumes: [],
                               environment: [], restart: nil,
                               dependsOn: [ComposeDependency(service: "a", condition: .started)], healthcheck: nil)
        let (order, cycle) = ComposeOrder.sorted([a, b])
        #expect(cycle)
        #expect(order == ["a", "b"])   // declared order on cycle
    }

    @Test func healthDecision() {
        #expect(HealthDecision.status(consecutiveFailures: 0, retries: 3) == .healthy)
        #expect(HealthDecision.status(consecutiveFailures: 2, retries: 3) == .healthy)
        #expect(HealthDecision.status(consecutiveFailures: 3, retries: 3) == .unhealthy)
        #expect(HealthDecision.status(consecutiveFailures: 5, retries: 3) == .unhealthy)
        // retries floored at 1 so a zero/negative budget can't make it permanently healthy
        #expect(HealthDecision.status(consecutiveFailures: 1, retries: 0) == .unhealthy)
    }

    @Test func hubSearchURL() {
        let url = HubSearch.url(query: "nginx", pageSize: 10)
        #expect(url?.absoluteString == "https://hub.docker.com/v2/search/repositories/?query=nginx&page_size=10")
        #expect(HubSearch.url(query: "   ") == nil)   // blank query → no request
    }

    @Test func hubSearchDecodes() throws {
        let json = """
        {"results":[{"repo_name":"library/nginx","short_description":"web server","star_count":18000,"is_official":true,"is_automated":false}]}
        """
        let decoded = try JSONDecoder().decode(HubSearchResponse.self, from: Data(json.utf8))
        #expect(decoded.results.first?.repoName == "library/nginx")
        #expect(decoded.results.first?.isOfficial == true)
        #expect(decoded.results.first?.starCount == 18000)
        #expect(decoded.results.first?.pullReference == "nginx")
    }

    @Test func parseVersionAndSupport() {
        let v = CLILocator.parseVersion("container CLI version 1.0.0 (build: release, commit: ee848e3)")
        #expect(v == "1.0.0")
        #expect(CLILocator.isSupported(v))
        #expect(!CLILocator.isSupported("0.10.0"))
        #expect(!CLILocator.isSupported(nil))
    }

    @Test func appleRuntimeDescriptorAdvertisesCurrentCapabilities() throws {
        let descriptor = RuntimeDescriptor.appleContainer
        #expect(descriptor.kind == .appleContainer)
        #expect(descriptor.displayName == "Apple container")
        #expect(descriptor.executableName == "container")
        #expect(descriptor.supports([.containers, .images, .volumes, .networks]))
        #expect(descriptor.supports([.systemStatus, .systemLogs, .exec, .copy]))
        try descriptor.require([.imageBuild, .imagePush, .registries])

        let readOnly = RuntimeDescriptor(kind: .dockerCompatible,
                                         displayName: "Read-only runtime",
                                         executableName: "container",
                                         capabilities: [.containers])
        #expect(!readOnly.supports(.imageBuild))
        #expect(throws: UnsupportedRuntimeCapability.self) {
            try readOnly.require(.imageBuild)
        }
    }

    @Test func containerClientConformsToRuntimeClient() async throws {
        let runner = MockCommandRunner(result: .success(try Fixture.data("list")))
        let runtime: any ContainerRuntimeClient = ContainerClient(runner: runner)
        #expect(runtime.descriptor == .appleContainer)

        let containers = try await runtime.listContainers(all: true)
        #expect(containers.first?.id == "fixture-web")
    }

    @Test func clientDecodesThroughMock() async throws {
        let runner = MockCommandRunner(result: .success(try Fixture.data("list")))
        let client = ContainerClient(runner: runner)
        let containers = try await client.listContainers()
        #expect(containers.first?.id == "fixture-web")
    }

    @Test func clientMapsDecodeFailure() async throws {
        // The real `image list` error case: stdout is an error line, not JSON.
        let bad = MockCommandRunner(result: .success(Data("Error: content with digest sha256:…".utf8)))
        let client = ContainerClient(runner: bad)
        await #expect(throws: CommandError.self) {
            _ = try await client.listContainers()
        }
    }

    @Test func clientPropagatesNonZeroExit() async throws {
        let failing = MockCommandRunner(result: .failure(.nonZeroExit(code: 1, stderr: "boom", command: "list")))
        let client = ContainerClient(runner: failing)
        await #expect(throws: CommandError.self) {
            _ = try await client.listContainers()
        }
    }

    @Test func statsDeltaComputesCPUFraction() {
        let prev = ContainerStats(id: "x", cpuUsageUsec: 1_000_000, memoryUsageBytes: 100, memoryLimitBytes: 1000,
                                  blockReadBytes: 0, blockWriteBytes: 0, networkRxBytes: 0, networkTxBytes: 0, numProcesses: 1)
        let curr = ContainerStats(id: "x", cpuUsageUsec: 1_500_000, memoryUsageBytes: 200, memoryLimitBytes: 1000,
                                  blockReadBytes: 0, blockWriteBytes: 1024, networkRxBytes: 2048, networkTxBytes: 0, numProcesses: 2)
        let delta = StatsDelta.between(previous: prev, current: curr, interval: 1.0)
        // 0.5s of CPU over 1s wall = 0.5 cores.
        #expect(abs(delta.cpuCoreFraction - 0.5) < 0.0001)
        #expect(delta.memoryFraction == 0.2)
        #expect(delta.blockWriteBytesPerSec == 1024)
        #expect(delta.netRxBytesPerSec == 2048)
        #expect(delta.numProcesses == 2)
    }

    @Test func statsDeltaConvertsRuntimeSnapshotRates() {
        let previous = RuntimeStatsSnapshot(id: "x", cpuCoreFraction: 0.1,
                                            memoryUsageBytes: 100, memoryLimitBytes: 1000,
                                            blockReadBytes: 1_000, blockWriteBytes: 2_000,
                                            networkRxBytes: 3_000, networkTxBytes: 4_000,
                                            numProcesses: 1)
        let current = RuntimeStatsSnapshot(id: "x", cpuCoreFraction: 0.42,
                                           memoryUsageBytes: 200, memoryLimitBytes: 1000,
                                           blockReadBytes: 1_500, blockWriteBytes: 2_800,
                                           networkRxBytes: 4_000, networkTxBytes: 4_400,
                                           numProcesses: 3)

        let delta = StatsDelta.from(snapshot: current, previous: previous, interval: 2)
        #expect(delta.cpuCoreFraction == 0.42)
        #expect(delta.memoryFraction == 0.2)
        #expect(delta.blockReadBytesPerSec == 250)
        #expect(delta.blockWriteBytesPerSec == 400)
        #expect(delta.netRxBytesPerSec == 500)
        #expect(delta.netTxBytesPerSec == 200)
        #expect(delta.numProcesses == 3)
    }
}

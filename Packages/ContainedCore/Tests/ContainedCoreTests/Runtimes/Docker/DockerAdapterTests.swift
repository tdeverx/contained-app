import Foundation
import Testing
@testable import ContainedCore

@Suite("Docker runtime adapter")
struct DockerAdapterTests {
    @Test func dockerRuntimeDescriptorAdvertisesCurrentCapabilities() throws {
        let descriptor = Core.Runtime.Descriptor.docker

        #expect(descriptor.kind == .docker)
        #expect(descriptor.displayName == "Docker")
        #expect(descriptor.executableName == "docker")
        #expect(descriptor.supports([.containers, .images, .volumes, .networks]))
        #expect(descriptor.supports([.systemStatus, .exec, .copy]))
        #expect(!descriptor.supports(.systemLogs))
        #expect(!descriptor.supports(.dnsManagement))
        try descriptor.require([.imageBuild, .imagePush, .registries])
    }

    @Test func dockerCLIVersionParsing() {
        #expect(DockerCLILocator.parseVersion("Docker version 27.3.1, build ce12230") == "27.3.1")
        #expect(DockerCLILocator.parseVersion("no version here") == nil)
    }

    @Test func dockerModuleReadinessDistinguishesEndpointFailure() async {
        let module = DockerRuntimeModule()
        let ready = await module.readiness(
            cliURL: URL(fileURLWithPath: "/usr/local/bin/docker"),
            runner: CommandMapRunner(outputs: [
                DockerCommands.version: .success(Data("Docker version 27.3.1, build ce12230\n".utf8)),
                DockerCommands.systemStatus: .success(Data(#"{"ServerVersion":"27.3.1","NCPU":8}"#.utf8)),
            ])
        )

        #expect(ready.kind == .docker)
        #expect(ready.version == "27.3.1")
        #expect(ready.state == .ready)

        let unavailable = await module.readiness(
            cliURL: URL(fileURLWithPath: "/usr/local/bin/docker"),
            runner: CommandMapRunner(outputs: [
                DockerCommands.version: .success(Data("Docker version 27.3.1, build ce12230\n".utf8)),
                DockerCommands.systemStatus: .failure(.nonZeroExit(
                    code: 1,
                    stderr: "Cannot connect to the Docker daemon",
                    command: "info"
                )),
            ])
        )

        #expect(unavailable.version == "27.3.1")
        #expect(unavailable.state == .endpointUnavailable)
    }

    @Test func dockerModuleOwnsTerminalAndPreviewArgv() {
        let module = DockerRuntimeModule()
        var request = Core.Container.CreateRequest(runtimeKind: .docker)
        request.image = "nginx:latest"
        request.network = "host"

        #expect(module.terminalInvocation(containerID: "web",
                                          shell: "/bin/sh",
                                          cliURL: URL(fileURLWithPath: "/usr/local/bin/docker")).arguments
            == ["container", "exec", "--interactive", "--tty", "web", "/bin/sh"])
        #expect(module.runPreview(for: request).contains("--network"))
        #expect(module.buildPreview(context: ".", tag: "web:dev", dockerfile: nil,
                                    buildArgs: [:], noCache: false, ssh: false, platform: nil)
            == ["build", "--progress", "plain", "--tag", "web:dev", "."])
    }

    @Test func dockerCreatePreservesConfigurationWithoutStartingOrDetaching() async throws {
        var request = Core.Container.CreateRequest(runtimeKind: .docker)
        request.image = "alpine"
        request.name = "web"
        request.removeOnExit = true
        request.interactive = true
        request.tty = true
        request.cpus = "2"
        request.memory = "512M"
        request.attachStreams = ["stdout", "stderr"]
        request.ports = [.init(hostPort: "8080", containerPort: "80")]
        request.volumes = [.init(source: "data", target: "/data")]
        request.env = [.init(key: "MODE", value: "recovery")]
        request.command = ["sleep", "100"]
        let expected = ["container", "create", "--rm", "--interactive", "--tty", "--name", "web",
                        "--cpus", "2", "--memory", "512M", "--attach", "stdout", "--attach", "stderr",
                        "--publish", "8080:80", "--volume", "data:/data", "--env", "MODE=recovery",
                        "alpine", "sleep", "100"]
        let client = DockerClient(runner: CommandMapRunner(outputs: [expected: .success(Data("generated-id\n".utf8))]))

        #expect(DockerCommands.run(request, start: false) == expected)
        #expect(try client.previewCreateCommand(for: request, start: false).command == expected)
        let result = try await client.createContainer(request, start: false)

        #expect(result.id == "web")
    }

    @Test func dockerSchemaProfileLivesWithRuntimeAdapter() throws {
        let profile = DockerRuntimeModule().schemaProfile()
        let definition = Core.Schema.Definition.containerRunEdit(runtimeProfile: profile)
        let pullPolicy = try #require(definition.descriptor(for: .imagePullPolicy))
        let rosetta = try #require(definition.descriptor(for: .securityRosetta))

        #expect(profile.kind == .docker)
        #expect(pullPolicy.support(for: .docker).state == .supported)
        #expect(rosetta.support(for: .docker).state == .disabled)
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

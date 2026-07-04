import Foundation
import Testing
@testable import ContainedCore

@Suite("Runtime command workflows")
struct RuntimeWorkflowTests {

    // MARK: Command builders

    @Test func imageAndStreamingArgv() {
        #expect(ContainerCommands.imageList() == ["image", "list", "--format", "json"])
        // Structured stats stay one-shot; table mode is the Apple CLI's streaming surface.
        #expect(ContainerCommands.stats(ids: ["web"], noStream: false) == ["stats", "--format", "json", "web"])
        #expect(ContainerCommands.stats(ids: ["web"]) == ["stats", "--no-stream", "--format", "json", "web"])
        #expect(ContainerCommands.statsTableStream(ids: ["web"]) == ["stats", "--format", "table", "web"])
        #expect(ContainerCommands.logs("web", follow: true, tail: 500) == ["logs", "--follow", "-n", "500", "web"])
    }

    @Test func dockerContainerImageAndStreamingArgv() {
        #expect(DockerCommands.containerIDs(all: true) == ["container", "ls", "--all", "--no-trunc", "--quiet"])
        #expect(DockerCommands.inspectContainers(["web"]) == ["container", "inspect", "web"])
        #expect(DockerCommands.stats(ids: ["web"]) == ["stats", "--no-stream", "--format", "{{json .}}", "web"])
        #expect(DockerCommands.logs("web", follow: true, tail: 500) == ["container", "logs", "--follow", "--tail", "500", "web"])
        #expect(DockerCommands.execInteractive("web", shell: "/bin/sh")
                == ["container", "exec", "--interactive", "--tty", "web", "/bin/sh"])
        #expect(DockerCommands.imageList() == ["image", "ls", "--digests", "--no-trunc", "--format", "{{json .}}"])
    }

    @Test func volumeAndNetworkWriteArgv() {
        #expect(ContainerCommands.volumeCreate(name: "data") == ["volume", "create", "data"])
        #expect(ContainerCommands.volumeCreate(name: "data", size: "10G", labels: ["a": "1"])
                == ["volume", "create", "--label", "a=1", "-s", "10G", "data"])
        #expect(ContainerCommands.volumeDelete(["a", "b"]) == ["volume", "delete", "a", "b"])

        #expect(ContainerCommands.networkCreate(name: "net") == ["network", "create", "net"])
        #expect(ContainerCommands.networkCreate(name: "net", subnet: "10.0.0.0/24", internalOnly: true)
                == ["network", "create", "--internal", "--subnet", "10.0.0.0/24", "net"])
        #expect(ContainerCommands.networkDelete(["net"]) == ["network", "delete", "net"])
    }

    @Test func imageWriteAndBuildArgv() {
        #expect(ContainerCommands.imageDelete(["a", "b"]) == ["image", "delete", "a", "b"])
        #expect(ContainerCommands.imageTag(source: "a:1", target: "a:2") == ["image", "tag", "a:1", "a:2"])
        #expect(ContainerCommands.imagePrune() == ["image", "prune"])
        #expect(ContainerCommands.imagePrune(all: true) == ["image", "prune", "--all"])
        #expect(ContainerCommands.imagePull("alpine") == ["image", "pull", "--progress", "plain", "alpine"])
        #expect(ContainerCommands.imagePull("alpine", platform: "linux/arm64")
                == ["image", "pull", "--progress", "plain", "--platform", "linux/arm64", "alpine"])
        #expect(ContainerCommands.build(context: ".") == ["build", "--progress", "plain", "."])
        #expect(ContainerCommands.build(context: "ctx", tag: "img:1", dockerfile: "Dockerfile",
                                        buildArgs: ["A": "1"], noCache: true)
                == ["build", "--progress", "plain", "--tag", "img:1", "--file", "Dockerfile",
                    "--build-arg", "A=1", "--no-cache", "ctx"])
    }

    @Test func dockerRunArgvIncludesDockerOnlyFields() {
        var request = Core.Container.CreateRequest(runtimeKind: .appleContainer)
        request.runtimeKind = .docker
        request.image = "nginx:latest"
        request.name = "web"
        request.detach = true
        request.network = "host"
        request.publishAll = true
        request.pullPolicy = "always"
        request.extraHosts = ["host.docker.internal:host-gateway"]
        request.loggingDriver = "json-file"
        request.loggingOptions = [Core.Container.KeyValue(key: "max-size", value: "10m")]
        request.gpus = "all"
        request.privileged = true
        request.securityOptions = ["no-new-privileges"]
        request.stopGracePeriod = "30"
        request.env = [Core.Container.KeyValue(key: "FOO", value: "bar")]
        request.ports = [Core.Container.Port(hostPort: "8080", containerPort: "80", proto: "tcp")]

        #expect(DockerCommands.run(request) == [
            "container", "run",
            "--detach",
            "--name", "web",
            "--privileged",
            "--publish-all",
            "--pull", "always",
            "--network", "host",
            "--stop-timeout", "30",
            "--gpus", "all",
            "--add-host", "host.docker.internal:host-gateway",
            "--publish", "8080:80",
            "--env", "FOO=bar",
            "--security-opt", "no-new-privileges",
            "--log-driver", "json-file",
            "--log-opt", "max-size=10m",
            "nginx:latest",
        ])
    }

    @Test func registryAndPushArgv() {
        #expect(ContainerCommands.registryList() == ["registry", "list", "--format", "json"])
        #expect(ContainerCommands.registryLogin(server: "ghcr.io", username: "me")
                == ["registry", "login", "--username", "me", "--password-stdin", "ghcr.io"])
        #expect(ContainerCommands.registryLogout(server: "ghcr.io") == ["registry", "logout", "ghcr.io"])
        #expect(ContainerCommands.imagePush("ghcr.io/me/app:1")
                == ["image", "push", "--progress", "plain", "ghcr.io/me/app:1"])
        #expect(DockerCommands.registryLogin(server: "ghcr.io", username: "me")
                == ["login", "--username", "me", "--password-stdin", "ghcr.io"])
        #expect(DockerCommands.registryLogout(server: "ghcr.io") == ["logout", "ghcr.io"])
        #expect(DockerCommands.imagePush("ghcr.io/me/app:1", platform: "linux/arm64")
                == ["image", "push", "--platform", "linux/arm64", "ghcr.io/me/app:1"])
    }

    @Test func pruneSystemAndCopyArgv() {
        #expect(ContainerCommands.containerPrune() == ["prune"])
        #expect(ContainerCommands.volumePrune() == ["volume", "prune"])
        #expect(ContainerCommands.networkPrune() == ["network", "prune"])
        #expect(ContainerCommands.systemPropertyList == ["system", "property", "list", "--format", "json"])
        #expect(ContainerCommands.systemLogs(follow: true, last: 200) == ["system", "logs", "--follow", "--last", "200"])
        #expect(ContainerCommands.exec("web", ["ps"]) == ["exec", "web", "ps"])
        #expect(ContainerCommands.copy(source: "web:/etc/hosts", destination: "/tmp/hosts")
                == ["copy", "web:/etc/hosts", "/tmp/hosts"])
    }

    @Test func composeParsing() throws {
        let yaml = """
        services:
          web:
            image: nginx:latest
            platform: linux/arm64
            ports:
              - "8080:80"
            environment:
              - FOO=bar
            restart: always
          db:
            image: postgres:16
            environment:
              POSTGRES_PASSWORD: secret
            volumes:
              - "pgdata:/var/lib/postgresql/data"
        networks:
          default: {}
        """
        let project = try Core.Compose.Parser.parse(yaml, projectName: "demo")
        #expect(project.services.count == 2)
        let web = project.services.first { $0.name == "web" }
        #expect(web?.image == "nginx:latest")
        #expect(web?.platform == "linux/arm64")
        #expect(web?.ports == ["8080:80"])
        #expect(web?.environment == ["FOO=bar"])
        #expect(web?.restart == "always")
        let db = project.services.first { $0.name == "db" }
        #expect(db?.environment == ["POSTGRES_PASSWORD=secret"])
        #expect(db?.volumes == ["pgdata:/var/lib/postgresql/data"])
        // The top-level `networks` key is reported as not translated.
        #expect(project.warnings.contains { $0.contains("networks") })
    }

    @Test func composeHostNetworkIsRuntimeSpecific() throws {
        let yaml = """
        services:
          web:
            image: nginx:latest
            network_mode: host
        """
        let project = try Core.Compose.Parser.parse(yaml, projectName: "demo")
        let apple = Core.Orchestrator.testing(runner: MockCommandRunner(result: .success(Data())),
                                                runtimeKind: .appleContainer)
        let dockerModule = DockerRuntimeModule()
        let docker = Core.Orchestrator(cliURLs: [.docker: URL(fileURLWithPath: "/usr/local/bin/docker")],
                                       runtimes: [.docker: dockerModule.makeClient(runner: MockCommandRunner(result: .success(Data())))] as [Core.Runtime.Kind: any RuntimeClient],
                                       modules: [.docker: dockerModule])

        let appleDocument = try #require(apple.translateCompose(project,
                                                                baseDirectory: nil,
                                                                runtimeKind: .appleContainer).items.first?.document)
        let dockerDocument = try #require(docker.translateCompose(project,
                                                                  baseDirectory: nil,
                                                                  runtimeKind: .docker).items.first?.document)

        #expect(appleDocument.runtimeKind == .appleContainer)
        #expect(appleDocument.string(.networkName) == "")
        #expect(dockerDocument.runtimeKind == .docker)
        #expect(dockerDocument.string(.networkName) == "host")
        #expect(try docker.previewCreateCommand(for: dockerDocument).command.contains("--network"))
        #expect(try docker.previewCreateCommand(for: dockerDocument).command.contains("host"))
    }

    // MARK: Restart watchdog decision logic

    @Test func restartPolicyParsing() {
        #expect(Core.Container.RestartPolicy(label: "always") == .always)
        #expect(Core.Container.RestartPolicy(label: "on-failure") == .onFailure)
        #expect(Core.Container.RestartPolicy(label: nil) == .no)
        #expect(Core.Container.RestartPolicy(label: "unless-stopped") == .no)
        #expect(Core.Container.RestartPolicy(label: "garbage") == .no)
    }

    @Test func watchdogDecision() {
        // User-initiated stops are never auto-restarted.
        #expect(!Core.Container.RestartDecision.shouldRestart(policy: .always, userInitiated: true))
        // .no never restarts.
        #expect(!Core.Container.RestartDecision.shouldRestart(policy: .no, userInitiated: false))
        // .always restarts any crash.
        #expect(Core.Container.RestartDecision.shouldRestart(policy: .always, userInitiated: false))
        // .onFailure: unknown exit treated as failure; known 0 suppressed; nonzero restarts.
        #expect(Core.Container.RestartDecision.shouldRestart(policy: .onFailure, userInitiated: false, exitCode: nil))
        #expect(!Core.Container.RestartDecision.shouldRestart(policy: .onFailure, userInitiated: false, exitCode: 0))
        #expect(Core.Container.RestartDecision.shouldRestart(policy: .onFailure, userInitiated: false, exitCode: 137))
    }

    @Test func watchdogBackoffGrowsAndCaps() {
        #expect(Core.Container.RestartDecision.backoff(attempt: 0) == 0)
        #expect(Core.Container.RestartDecision.backoff(attempt: 1) == 2)
        #expect(Core.Container.RestartDecision.backoff(attempt: 2) == 4)
        #expect(Core.Container.RestartDecision.backoff(attempt: 3) == 8)
        #expect(Core.Container.RestartDecision.backoff(attempt: 10) == 60)   // capped
    }
}

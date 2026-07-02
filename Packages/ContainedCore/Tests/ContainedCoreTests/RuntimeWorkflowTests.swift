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

    @Test func registryAndPushArgv() {
        #expect(ContainerCommands.registryList() == ["registry", "list", "--format", "json"])
        #expect(ContainerCommands.registryLogin(server: "ghcr.io", username: "me")
                == ["registry", "login", "--username", "me", "--password-stdin", "ghcr.io"])
        #expect(ContainerCommands.registryLogout(server: "ghcr.io") == ["registry", "logout", "ghcr.io"])
        #expect(ContainerCommands.imagePush("ghcr.io/me/app:1")
                == ["image", "push", "--progress", "plain", "ghcr.io/me/app:1"])
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
        let project = try ComposeParser.parse(yaml, projectName: "demo")
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

    // MARK: Restart watchdog decision logic

    @Test func restartPolicyParsing() {
        #expect(RestartPolicy(label: "always") == .always)
        #expect(RestartPolicy(label: "on-failure") == .onFailure)
        #expect(RestartPolicy(label: nil) == .no)
        #expect(RestartPolicy(label: "unless-stopped") == .no)
        #expect(RestartPolicy(label: "garbage") == .no)
    }

    @Test func watchdogDecision() {
        // User-initiated stops are never auto-restarted.
        #expect(!RestartDecision.shouldRestart(policy: .always, userInitiated: true))
        // .no never restarts.
        #expect(!RestartDecision.shouldRestart(policy: .no, userInitiated: false))
        // .always restarts any crash.
        #expect(RestartDecision.shouldRestart(policy: .always, userInitiated: false))
        // .onFailure: unknown exit treated as failure; known 0 suppressed; nonzero restarts.
        #expect(RestartDecision.shouldRestart(policy: .onFailure, userInitiated: false, exitCode: nil))
        #expect(!RestartDecision.shouldRestart(policy: .onFailure, userInitiated: false, exitCode: 0))
        #expect(RestartDecision.shouldRestart(policy: .onFailure, userInitiated: false, exitCode: 137))
    }

    @Test func watchdogBackoffGrowsAndCaps() {
        #expect(RestartDecision.backoff(attempt: 0) == 0)
        #expect(RestartDecision.backoff(attempt: 1) == 2)
        #expect(RestartDecision.backoff(attempt: 2) == 4)
        #expect(RestartDecision.backoff(attempt: 3) == 8)
        #expect(RestartDecision.backoff(attempt: 10) == 60)   // capped
    }
}

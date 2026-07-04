import Foundation
import Testing
import ContainedCore
@testable import ContainedApp

@Suite("Container runtime migration")
@MainActor
struct ContainerRuntimeMigrationTests {
    @Test func successfulMigrationStopsCreatesStabilizesThenDeletesSource() async {
        let app = AppModel(database: AppDatabase(isStoredInMemoryOnly: true))
        let apple = MigrationAppleRunner()
        let docker = MigrationDockerRunner()
        app.installRuntimeClientForTesting(appTestOrchestrator(runners: [.appleContainer: apple, .docker: docker]))
        app.migrationStabilizationTimeout = 0.2
        app.migrationPollInterval = 0.001
        app.healthChecks.setCheck(Core.Container.HealthCheck(command: ["true"], enabled: true),
                                  for: Core.Runtime.Kind.appleContainer.scopedID(for: "web"))

        await app.containers.refresh()
        let ok = await app.migrateContainer(scopedID: Core.Runtime.Kind.appleContainer.scopedID(for: "web"),
                                            to: .docker)

        #expect(ok)
        #expect(await apple.contains(["stop", "web"]))
        #expect(await apple.contains(["delete", "--force", "web"]))
        #expect(await docker.containsPrefix(["container", "run"]))
        #expect(await docker.contains(["container", "exec", "web", "true"]))
        #expect(app.containers.snapshots.map(\.scopedID) == [Core.Runtime.Kind.docker.scopedID(for: "web")])

        let records = app.database.fetch(ContainerRecord.self)
        #expect(records.count == 1)
        #expect(records.first?.scopedID == Core.Runtime.Kind.docker.scopedID(for: "web"))
        #expect(records.first?.migrationStateRaw == "none")
        #expect(records.first?.isHiddenDuringMigration == false)
    }

    @Test func targetCreateFailureKeepsStoppedSourceVisibleAndNotDeleted() async {
        let app = AppModel(database: AppDatabase(isStoredInMemoryOnly: true))
        let apple = MigrationAppleRunner()
        let docker = MigrationDockerRunner(createFails: true)
        app.installRuntimeClientForTesting(appTestOrchestrator(runners: [.appleContainer: apple, .docker: docker]))
        app.migrationStabilizationTimeout = 0.05
        app.migrationPollInterval = 0.001

        await app.containers.refresh()
        let ok = await app.migrateContainer(scopedID: Core.Runtime.Kind.appleContainer.scopedID(for: "web"),
                                            to: .docker)

        #expect(!ok)
        #expect(await apple.contains(["stop", "web"]))
        #expect(!(await apple.contains(["delete", "--force", "web"])))
        #expect(app.containers.snapshots.map(\.scopedID) == [Core.Runtime.Kind.appleContainer.scopedID(for: "web")])
        #expect(app.containers.snapshots.first?.state == .stopped)
        let record = app.database.fetch(ContainerRecord.self).first
        #expect(record?.scopedID == Core.Runtime.Kind.appleContainer.scopedID(for: "web"))
        #expect(record?.isHiddenDuringMigration == false)
        #expect(record?.migrationStateRaw.hasPrefix("failed") == true)
    }

    @Test func stabilizationTimeoutKeepsSourceAndDoesNotDeleteIt() async {
        let app = AppModel(database: AppDatabase(isStoredInMemoryOnly: true))
        let apple = MigrationAppleRunner()
        let docker = MigrationDockerRunner(targetState: .stopped)
        app.installRuntimeClientForTesting(appTestOrchestrator(runners: [.appleContainer: apple, .docker: docker]))
        app.migrationStabilizationTimeout = 0.02
        app.migrationPollInterval = 0.001

        await app.containers.refresh()
        let ok = await app.migrateContainer(scopedID: Core.Runtime.Kind.appleContainer.scopedID(for: "web"),
                                            to: .docker)

        #expect(!ok)
        #expect(await apple.contains(["stop", "web"]))
        #expect(!(await apple.contains(["delete", "--force", "web"])))
        #expect(app.containers.snapshots.contains { $0.scopedID == Core.Runtime.Kind.appleContainer.scopedID(for: "web") })
        let record = app.database.fetch(ContainerRecord.self).first { $0.scopedID == Core.Runtime.Kind.appleContainer.scopedID(for: "web") }
        #expect(record?.migrationStateRaw.hasPrefix("failed") == true)
    }
}

private actor MigrationAppleRunner: Core.Command.Running {
    private var calls: [[String]] = []
    private var exists = true
    private var state = "running"

    func run(_ arguments: [String],
             stdin: Data?,
             priority: Core.Command.ExecutionPriority) async throws -> Data {
        calls.append(arguments)
        switch arguments {
        case ["list", "--all", "--format", "json"]:
            guard exists else { return Data("[]".utf8) }
            return Self.containerListJSON(state: state)
        case ["stop", "web"]:
            state = "stopped"
            return Data()
        case ["delete", "--force", "web"]:
            exists = false
            return Data()
        case ["image", "list", "--format", "json"]:
            return Data("[]".utf8)
        default:
            return Data("[]".utf8)
        }
    }

    nonisolated func stream(_ arguments: [String],
                            priority: Core.Command.ExecutionPriority) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in continuation.finish() }
    }

    func contains(_ arguments: [String]) -> Bool {
        calls.contains(arguments)
    }

    private static func containerListJSON(state: String) -> Data {
        Data("""
        [{
          "configuration": {
            "id": "web",
            "image": { "reference": "nginx:latest" },
            "initProcess": {},
            "labels": {}
          },
          "id": "web",
          "status": { "state": "\(state)" }
        }]
        """.utf8)
    }
}

private actor MigrationDockerRunner: Core.Command.Running {
    private var calls: [[String]] = []
    private var created = false
    private let createFails: Bool
    private let targetState: Core.Runtime.Status

    init(createFails: Bool = false, targetState: Core.Runtime.Status = .running) {
        self.createFails = createFails
        self.targetState = targetState
    }

    func run(_ arguments: [String],
             stdin: Data?,
             priority: Core.Command.ExecutionPriority) async throws -> Data {
        calls.append(arguments)
        if arguments == ["image", "ls", "--digests", "--no-trunc", "--format", "{{json .}}"] {
            return Data(#"{"Repository":"nginx","Tag":"latest","Digest":"sha256:abc","ID":"sha256:image"}"#.utf8)
        }
        if arguments == ["container", "ls", "--all", "--no-trunc", "--quiet"] {
            return created ? Data("web\n".utf8) : Data()
        }
        if arguments == ["container", "inspect", "web"] {
            return Self.inspectJSON(state: targetState)
        }
        if arguments.starts(with: ["container", "run"]) {
            if createFails { throw MigrationRunnerError.createFailed }
            created = true
            return Data("web\n".utf8)
        }
        if arguments == ["container", "exec", "web", "true"] {
            return Data()
        }
        return Data()
    }

    nonisolated func stream(_ arguments: [String],
                            priority: Core.Command.ExecutionPriority) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in continuation.finish() }
    }

    func contains(_ arguments: [String]) -> Bool {
        calls.contains(arguments)
    }

    func containsPrefix(_ prefix: [String]) -> Bool {
        calls.contains { $0.starts(with: prefix) }
    }

    private static func inspectJSON(state: Core.Runtime.Status) -> Data {
        let running = state == .running ? "true" : "false"
        return Data("""
        [
          {
            "Id": "web",
            "Name": "/web",
            "Platform": "linux/arm64",
            "Config": {
              "Image": "nginx:latest",
              "Cmd": [],
              "Env": [],
              "Labels": {},
              "Tty": false
            },
            "State": {
              "Status": "\(state.rawValue)",
              "Running": \(running),
              "StartedAt": "2026-07-03T09:31:00Z"
            },
            "HostConfig": {
              "PortBindings": {},
              "ReadonlyRootfs": false,
              "Init": false
            },
            "NetworkSettings": {
              "Networks": {}
            },
            "Mounts": []
          }
        ]
        """.utf8)
    }
}

private enum MigrationRunnerError: LocalizedError {
    case createFailed

    var errorDescription: String? { "create failed" }
}

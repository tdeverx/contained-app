import Foundation
import Testing
import ContainedCore
import ContainedUI
@testable import ContainedApp

@Suite("Runtime-first app database")
@MainActor
struct AppDatabaseTests {
    @Test func settingsIgnoreOldDefaultsAndPersistToDatabase() {
        let defaults = UserDefaults(suiteName: "ContainedDatabaseTests-\(UUID().uuidString)")!
        defaults.set(UI.Theme.Tint.pink.rawValue, forKey: "accentTint")

        let database = AppDatabase(isStoredInMemoryOnly: true)
        let settings = SettingsStore(database: database)

        #expect(settings.accentTint == .multicolor)

        settings.accentTint = .teal
        let reloaded = SettingsStore(database: database)

        #expect(reloaded.accentTint == .teal)
    }

    @Test func runtimePathOverridesAreRuntimeScopedRecords() {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let settings = SettingsStore(database: database)

        settings.cliPathOverride = "/opt/container"
        settings.dockerCLIPathOverride = "/opt/docker"

        let records = database.fetch(RuntimeRecord.self)
        #expect(records.first { $0.runtimeKindRaw == Core.Runtime.Kind.appleContainer.rawValue }?.cliPathOverride == "/opt/container")
        #expect(records.first { $0.runtimeKindRaw == Core.Runtime.Kind.docker.rawValue }?.cliPathOverride == "/opt/docker")
    }

    @Test func containerRefreshUpsertsRuntimeScopedRecords() async throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let runner = DockerRecordingRunner()
        let store = ContainersStore()
        store.database = database
        store.client = Core.Orchestrator.testing(runner: runner,
                                                 cliURL: URL(fileURLWithPath: "/usr/local/bin/docker"),
                                                 runtimeKind: .docker)

        await store.refresh()

        let record = try #require(database.fetch(ContainerRecord.self).first)
        #expect(record.scopedID == "docker::web")
        #expect(record.runtimeKindRaw == Core.Runtime.Kind.docker.rawValue)
        #expect(record.runtimeID == "web")
        #expect(record.isMissing == false)
        #expect(record.snapshotData != nil)
        #expect(record.documentData != nil)

        database.upsertContainers([])
        #expect(database.fetch(ContainerRecord.self).isEmpty)
    }

    @Test func missingContainerWithAppOwnedMetadataIsRetained() async throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let runner = DockerRecordingRunner()
        let store = ContainersStore()
        store.database = database
        store.client = Core.Orchestrator.testing(runner: runner,
                                                 cliURL: URL(fileURLWithPath: "/usr/local/bin/docker"),
                                                 runtimeKind: .docker)

        await store.refresh()
        let healthCheck = Core.Container.HealthCheck(command: ["true"], enabled: true)
        let data = try JSONEncoder().encode(healthCheck)
        database.context.insert(HealthCheckRecord(containerScopedID: "docker::web", valueData: data))
        database.save()

        database.upsertContainers([])

        let record = try #require(database.fetch(ContainerRecord.self).first)
        #expect(record.scopedID == "docker::web")
        #expect(record.isMissing == true)
        #expect(record.missingSince != nil)
    }

    @Test func imageMetadataIsSharedWhileTagsStayRuntimeScoped() {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let images = [
            image(reference: "nginx:latest", id: "sha256:1", digest: "sha256:shared", runtimeKind: .appleContainer),
            image(reference: "docker.io/library/nginx:latest", id: "sha256:2", digest: "sha256:shared", runtimeKind: .docker),
        ]

        database.upsertImages(images)

        #expect(database.fetch(ImageRecord.self).count == 1)
        #expect(Set(database.fetch(ImageTagRecord.self).map(\.scopedID)) == [
            "apple-container::docker.io/library/nginx:latest",
            "docker::docker.io/library/nginx:latest",
        ])
    }

    @Test func imageUpdateStatusIsRuntimeScopedAtTagLevel() {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let app = AppModel(database: database)
        app.images = [
            image(reference: "nginx:latest", id: "sha256:1", digest: "sha256:old", runtimeKind: .appleContainer),
            image(reference: "docker.io/library/nginx:latest", id: "sha256:2", digest: "sha256:new", runtimeKind: .docker),
        ]

        let appleKey = app.imageUpdateKey("nginx:latest", runtimeKind: .appleContainer)
        let dockerKey = app.imageUpdateKey("nginx:latest", runtimeKind: .docker)
        app.imageUpdates = [
            appleKey: .resolved(localDigest: "sha256:old", remoteDigest: "sha256:new"),
            dockerKey: .resolved(localDigest: "sha256:new", remoteDigest: "sha256:new"),
        ]

        #expect(app.imageUpdateStatus(for: "nginx:latest").state == .updateAvailable)
        #expect(app.imageUpdateStatus(for: "nginx:latest", runtimeKind: .appleContainer).state == .updateAvailable)
        #expect(app.imageUpdateStatus(for: "nginx:latest", runtimeKind: .docker).state == .current)

        let tags = Dictionary(uniqueKeysWithValues: database.fetch(ImageTagRecord.self).map { ($0.scopedID, $0) })
        #expect(tags[appleKey]?.updateStatusData != nil)
        #expect(tags[dockerKey]?.updateStatusData != nil)
        #expect(database.fetch(ImageRecord.self).first?.updateStatusData == nil)
    }

    @Test func readyRuntimeDescriptorsExcludeRegisteredButUnavailableRuntimes() {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let app = AppModel(database: database)
        let orchestrator = Core.Orchestrator.testing(runners: [
            .appleContainer: NoopRunner(),
            .docker: NoopRunner(),
        ])

        app.installRuntimeClientForTesting(orchestrator,
                                           readiness: [
                                               Core.RuntimeReadiness(kind: .appleContainer,
                                                                     cliURL: URL(fileURLWithPath: "/usr/bin/container"),
                                                                     state: .unsupported,
                                                                     message: "Unsupported"),
                                               Core.RuntimeReadiness(kind: .docker,
                                                                     cliURL: URL(fileURLWithPath: "/usr/local/bin/docker"),
                                                                     state: .ready),
                                           ])

        #expect(Set(app.registeredRuntimeDescriptors.map(\.kind)) == [.appleContainer, .docker])
        #expect(app.availableRuntimeDescriptors.map(\.kind) == [.docker])
        #expect(app.core(for: .appleContainer) == nil)
        #expect(app.core(for: .docker) != nil)
    }

    private func image(reference: String,
                       id: String,
                       digest: String,
                       runtimeKind: Core.Runtime.Kind) -> Core.Image.Resource {
        let json = """
        {
          "configuration": {
            "name": "\(reference)",
            "descriptor": {
              "digest": "\(digest)",
              "mediaType": "application/vnd.oci.image.index.v1+json",
              "size": 10
            }
          },
          "id": "\(id)",
          "variants": [],
          "runtimeKind": "\(runtimeKind.rawValue)"
        }
        """
        return try! Core.Container.JSON.decode(Core.Image.Resource.self, from: Data(json.utf8))
    }
}

private struct NoopRunner: Core.Command.Running {
    func run(_ arguments: [String],
             stdin: Data?,
             priority: Core.Command.ExecutionPriority) async throws -> Data {
        Data()
    }

    func stream(_ arguments: [String],
                priority: Core.Command.ExecutionPriority) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

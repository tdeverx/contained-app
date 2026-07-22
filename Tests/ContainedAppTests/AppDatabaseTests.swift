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

        settings.setRuntimePathOverride("/opt/container", for: .appleContainer)
        settings.setRuntimePathOverride("/opt/docker", for: .docker)

        let records = database.fetch(RuntimeRecord.self)
        #expect(records.first { $0.runtimeKindRaw == Core.Runtime.Kind.appleContainer.rawValue }?.cliPathOverride == "/opt/container")
        #expect(records.first { $0.runtimeKindRaw == Core.Runtime.Kind.docker.rawValue }?.cliPathOverride == "/opt/docker")
        #expect(settings.runtimePathOverride(for: .docker) == "/opt/docker")
    }

    @Test func settingsBackupUsesRuntimeKeyedPathOverrides() throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let settings = SettingsStore(database: database)

        settings.setRuntimePathOverride("/opt/container", for: .appleContainer)
        settings.setRuntimePathOverride("/opt/docker", for: .docker)

        let snapshot = settings.backupSnapshot()
        #expect(snapshot.runtimePathOverrides[Core.Runtime.Kind.appleContainer.rawValue] == "/opt/container")
        #expect(snapshot.runtimePathOverrides[Core.Runtime.Kind.docker.rawValue] == "/opt/docker")

        let legacyJSON = """
        {
          "accentTint": "multicolor",
          "appearance": "system",
          "density": "medium",
          "windowMaterial": "fullScreenUI",
          "modalMaterial": "sheet",
          "cardMaterial": "glassRegular",
          "cliPathOverride": "/legacy/container",
          "dockerCLIPathOverride": "/legacy/docker",
          "refreshInterval": 2,
          "imageUpdateIntervalHours": 6,
          "imageUpdateChecksEnabled": true,
          "appUpdateChecksEnabled": true,
          "autoRestartEnabled": true,
          "notifyOnCrash": true,
          "revealCLI": true,
          "historyRetentionDays": 7,
          "loggingLevel": "important",
          "enabledLogDestinations": ["activity"],
          "enabledLogCategories": [],
          "updateChannel": "nightly",
          "commandPaletteEnabled": false,
          "hubSearchEnabled": false,
          "composeImportEnabled": false,
          "imageBuildEnabled": false,
          "experimentalToolbarUI": false
        }
        """
        let decoded = try JSONDecoder().decode(SettingsBackup.self, from: Data(legacyJSON.utf8))
        #expect(decoded.runtimePathOverrides[Core.Runtime.Kind.appleContainer.rawValue] == "/legacy/container")
        #expect(decoded.runtimePathOverrides[Core.Runtime.Kind.docker.rawValue] == "/legacy/docker")
    }

    @Test func containerRefreshUpsertsRuntimeScopedRecords() async throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let runner = DockerRecordingRunner()
        let store = ContainersStore()
        store.database = database
        store.client = appTestOrchestrator(runner: runner,
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

    @Test func unchangedRuntimeInventoryDoesNotRewriteRecords() async throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let runner = DockerRecordingRunner()
        let store = ContainersStore()
        store.database = database
        store.client = appTestOrchestrator(runner: runner,
                                           cliURL: URL(fileURLWithPath: "/usr/local/bin/docker"),
                                           runtimeKind: .docker)

        await store.refresh()
        let snapshot = try #require(store.snapshots.first)
        let original = try #require(database.fetch(ContainerRecord.self).first)
        let initialUpdatedAt = original.updatedAt

        database.upsertContainers([snapshot], observedAt: initialUpdatedAt.addingTimeInterval(60))

        #expect(try #require(database.fetch(ContainerRecord.self).first).updatedAt == initialUpdatedAt)
    }

    @Test func missingContainerWithAppOwnedMetadataIsRetained() async throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let runner = DockerRecordingRunner()
        let store = ContainersStore()
        store.database = database
        store.client = appTestOrchestrator(runner: runner,
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

    @Test func recreateRecoveryDocumentRetainsMissingContainerUntilResolved() async throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let runner = DockerRecordingRunner()
        let store = ContainersStore()
        store.database = database
        store.client = appTestOrchestrator(runner: runner,
                                           cliURL: URL(fileURLWithPath: "/usr/local/bin/docker"),
                                           runtimeKind: .docker)

        await store.refresh()
        let source = try #require(store.snapshots.first)
        let document = Core.Schema.Document.containerEdit(from: source.configuration)
        database.markContainerRecreateStarted(source: source, sourceDocument: document)
        database.upsertContainers([])

        let retained = try #require(database.fetch(ContainerRecord.self).first)
        #expect(retained.isMissing)
        #expect(retained.migrationStateRaw == "recreating")
        let projections = try JSONDecoder().decode(
            [String: Core.Schema.Document].self,
            from: try #require(retained.runtimeProjectionsData)
        )
        #expect(projections[Core.Runtime.Kind.docker.rawValue] == document)

        database.markContainerRecreateFailed(scopedID: source.scopedID)
        #expect(retained.migrationStateRaw == "recreateFailed")
        #expect(retained.runtimeProjectionsData != nil)
    }

    @Test func linkedVolumePathMetadataIsPersistedAndRetainsMissingContainer() async throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let runner = DockerRecordingRunner()
        let store = ContainersStore()
        store.database = database
        store.client = appTestOrchestrator(runner: runner,
                                           cliURL: URL(fileURLWithPath: "/usr/local/bin/docker"),
                                           runtimeKind: .docker)

        await store.refresh()
        let volumeID = try #require(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let links = [
            VolumeLinkedPath(id: volumeID,
                             volumeID: volumeID,
                             volumeSource: "web-config",
                             volumeTarget: "/config",
                             hostPath: "/Volumes/Vault/Media",
                             linkPath: "media",
                             readOnly: true),
        ]

        database.setLinkedVolumePaths(links, for: "docker::web")
        #expect(database.linkedVolumePaths(for: "docker::web") == links)

        database.upsertContainers([])

        let record = try #require(database.fetch(ContainerRecord.self).first)
        #expect(record.scopedID == "docker::web")
        #expect(record.isMissing == true)
        #expect(database.linkedVolumePaths(for: "docker::web") == links)
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
        app.setImages([
            image(reference: "nginx:latest", id: "sha256:1", digest: "sha256:old", runtimeKind: .appleContainer),
            image(reference: "docker.io/library/nginx:latest", id: "sha256:2", digest: "sha256:new", runtimeKind: .docker),
        ])

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

    @Test func duplicateLegacyImageTagRecordsDoNotPreventLaunch() {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let key = "apple-container::docker.io/library/nginx:latest"
        database.context.insert(ImageTagRecord(scopedID: key,
                                              imageIdentity: "nginx",
                                              reference: "nginx:latest",
                                              runtimeKindRaw: Core.Runtime.Kind.appleContainer.rawValue,
                                              runtimeImageID: "first"))
        database.context.insert(ImageTagRecord(scopedID: key,
                                              imageIdentity: "nginx",
                                              reference: "nginx:latest",
                                              runtimeKindRaw: Core.Runtime.Kind.appleContainer.rawValue,
                                              runtimeImageID: "second"))
        database.save()

        database.updateImageStatuses([key: .resolved(localDigest: "sha256:old", remoteDigest: "sha256:new")])

        #expect(database.fetch(ImageTagRecord.self).contains { $0.updateStatusData != nil })
    }

    @Test func defaultAppSupportedRuntimesKeepDockerDormant() {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let app = AppModel(database: database)

        #expect(app.supportedRuntimeDescriptors.map(\.kind) == [.appleContainer])
    }

    @Test func readyRuntimeDescriptorsExcludeRegisteredButUnavailableRuntimes() {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let app = AppModel(database: database)
        let orchestrator = appTestOrchestrator(runners: [
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

    @Test func runtimeIntentRequiresSelectionWhenMultipleRuntimesMatch() {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let app = AppModel(database: database)
        let orchestrator = appTestOrchestrator(runners: [
            .appleContainer: NoopRunner(),
            .docker: NoopRunner(),
        ])

        app.installRuntimeClientForTesting(orchestrator,
                                           readiness: [
                                               Core.RuntimeReadiness(kind: .appleContainer,
                                                                     cliURL: URL(fileURLWithPath: "/usr/bin/container"),
                                                                     state: .ready),
                                               Core.RuntimeReadiness(kind: .docker,
                                                                     cliURL: URL(fileURLWithPath: "/usr/local/bin/docker"),
                                                                     state: .ready),
                                           ])

        #expect(app.resolveRuntimeIntent(capability: .containers) == .needsSelection(app.availableRuntimeDescriptors))
        #expect(app.resolveRuntimeIntent(selected: .docker, capability: .containers) == .resolved(.docker))
    }

    @Test func runtimeIntentPreselectsOnlyReachableRuntime() {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let app = AppModel(database: database)
        let orchestrator = appTestOrchestrator(runners: [
            .appleContainer: NoopRunner(),
            .docker: NoopRunner(),
        ])

        app.installRuntimeClientForTesting(orchestrator,
                                           readiness: [
                                               Core.RuntimeReadiness(kind: .appleContainer,
                                                                     cliURL: URL(fileURLWithPath: "/usr/bin/container"),
                                                                     state: .cliMissing),
                                               Core.RuntimeReadiness(kind: .docker,
                                                                     cliURL: URL(fileURLWithPath: "/usr/local/bin/docker"),
                                                                     state: .ready),
                                           ])

        #expect(app.preselectedRuntimeKind(current: AppRuntimeIntent.placeholderKind, capability: .containers) == .docker)
        #expect(app.resolveRuntimeIntent(capability: .containers) == .resolved(.docker))
    }

    @Test func legacyRecipeShapeIsNotDecodedAsLiveRecipe() {
        let legacyJSON = """
        {
          "image": "nginx:latest",
          "name": "web",
          "ports": []
        }
        """
        let recipe = RecipeRecord(name: "Legacy",
                                  createdAt: Date(),
                                  updatedAt: Date(),
                                  documentData: Data(legacyJSON.utf8),
                                  sourceRaw: "template")

        #expect(recipe.spec == nil)
        #expect(RecipeSnapshot(recipe) == nil)
    }

    @Test func corruptSettingRecordsSurfaceTypedDatabaseFailure() {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        database.context.insert(AppSettingRecord(key: "corrupt", valueData: Data("not json".utf8)))

        let value: Int = database.setting("corrupt", fallback: 42)

        #expect(value == 42)
        guard case .decodeSetting(let key, _) = database.lastFailure else {
            Issue.record("Expected corrupt setting decode failure.")
            return
        }
        #expect(key == "corrupt")
    }

    @Test func imageUpdatePersistenceStaysOutOfUserDefaults() throws {
        let repoRoot = try repoRootURL()
        let source = repoRoot.appending(path: "Sources/ContainedApp/App/AppModel+ImageUpdates.swift")
        let contents = try String(contentsOf: source, encoding: .utf8)

        #expect(!contents.contains("loadImageUpdates"))
        #expect(!contents.contains("saveImageUpdates"))
        #expect(!contents.contains("UserDefaults"))
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

    private func repoRootURL() throws -> URL {
        var url = URL(filePath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
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

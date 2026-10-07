import Foundation
import SwiftData
import Testing
import ContainedCore
@testable import ContainedApp

@Suite("Container image update state")
@MainActor
struct ContainerImageUpdateTests {
    @Test func updatePreservesAndSavesOriginalBeforeMovingItsTag() async throws {
        let app = AppModel(database: AppDatabase(isStoredInMemoryOnly: true))
        let runner = UpdateRecoveryRunner(beforePull: {
            let recoveries = app.containerRecreationRecoveries
            #expect(recoveries.count == 1)
            #expect(recoveries.first?.snapshot.configuration.image.descriptor?.digest == UpdateRecoveryRunner.oldDigest)
            #expect(recoveries.first?.document.value(.imageReference) == .string(UpdateRecoveryRunner.pinnedReference))
            #expect(app.containers.busyIDs.contains(Core.Runtime.Kind.appleContainer.scopedID(for: "web")))
        })
        let source = try await prepareUpdate(app, runner: runner)

        #expect(await app.rebuildContainer(source))

        let commands = await runner.commands
        let tag = try #require(commands.firstIndex(of: ["image", "tag", UpdateRecoveryRunner.reference, UpdateRecoveryRunner.alias]))
        let pull = try #require(commands.firstIndex(where: { $0.starts(with: ["image", "pull"]) }))
        let stop = try #require(commands.firstIndex(of: ["stop", "web"]))
        #expect(tag < pull && pull < stop)
        #expect(app.containerRecreationRecoveries.isEmpty)
        #expect(app.containers.busyIDs.isEmpty)
        #expect(app.containers.snapshots.first?.configuration.image.descriptor?.digest == UpdateRecoveryRunner.newDigest)
    }

    @Test(arguments: [UpdatePreflightFailure.imagePreservation, .recipeSave, .recoveryRead, .pendingRecovery])
    func failedUpdatePreflightNeverPullsOrDeletes(_ failure: UpdatePreflightFailure) async throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let app = AppModel(database: database)
        let runner = UpdateRecoveryRunner(preservationFails: failure == .imagePreservation)
        let source = try await prepareUpdate(app, runner: runner)
        switch failure {
        case .recipeSave:
            database.failureInjector = { if $0 == "save" { throw UpdateRecoveryError.failed } }
        case .recoveryRead:
            database.recreationRecoveryCacheNeedsReload = true
            database.failureInjector = { if $0 == "fetch:ContainerRecord" { throw UpdateRecoveryError.failed } }
        case .pendingRecovery:
            #expect(database.markContainerRecreateStarted(source: source, sourceDocument: .containerRecovery(from: source.configuration)))
        case .imagePreservation: break
        }

        #expect(!(await app.rebuildContainer(source)))

        let commands = await runner.commands
        #expect(!commands.contains { $0.starts(with: ["image", "pull"]) || $0.starts(with: ["stop"]) || $0.starts(with: ["delete"]) })
        #expect(app.containers.busyIDs.isEmpty)
        if failure == .pendingRecovery {
            #expect(app.containerRecreationRecoveries.first?.snapshot == source)
        }
    }

    @Test(arguments: [true, false])
    func failedUpdatePullLeavesOriginalAndClearsOnlyItsOwnRecoveryMarker(originalWasRunning: Bool) async throws {
        let app = AppModel(database: AppDatabase(isStoredInMemoryOnly: true))
        let runner = UpdateRecoveryRunner(pullFails: true, originalWasRunning: originalWasRunning,
                                          failNextReplacement: true)
        let source = try await prepareUpdate(app, runner: runner)
        // Produce the stale failure through the real recovery path, without changing store ownership.
        #expect(await app.recreateContainer(originalID: source.scopedID,
                                            spec: ContainerFormState(from: source.configuration)) == nil)
        #expect(app.containers.recreateFailure?.recovery == .originalRestored)
        await runner.clearCommands()

        #expect(!(await app.rebuildContainer(source)))

        let commands = await runner.commands
        #expect(commands.contains { $0.starts(with: ["image", "pull"]) })
        #expect(!commands.contains { $0.starts(with: ["stop"]) || $0.starts(with: ["delete"]) })
        #expect(app.containerRecreationRecoveries.isEmpty)
        #expect(app.containers.snapshots.first == source)
        #expect(app.containers.busyIDs.isEmpty)
    }

    @Test func persistenceFailureAfterPullRetainsOriginalRecipeWithoutTeardown() async throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let app = AppModel(database: database)
        let runner = UpdateRecoveryRunner(beforePull: {
            database.failureInjector = { if $0 == "save" { throw UpdateRecoveryError.failed } }
        })
        let source = try await prepareUpdate(app, runner: runner)

        #expect(!(await app.rebuildContainer(source)))

        let commands = await runner.commands
        #expect(commands.contains { $0.starts(with: ["image", "pull"]) })
        #expect(!commands.contains { $0.starts(with: ["stop"]) || $0.starts(with: ["delete"]) })
        #expect(!database.canPersist)
        let saved = try #require(database.context.fetch(FetchDescriptor<ContainerRecord>()).first)
        let snapshotData = try #require(saved.snapshotData)
        #expect(try JSONDecoder().decode(Core.Container.Snapshot.self, from: snapshotData) == source)
        #expect(saved.migrationStateRaw == "recreating")
        #expect(app.containers.busyIDs.isEmpty)
    }

    private func prepareUpdate(_ app: AppModel, runner: UpdateRecoveryRunner) async throws -> Core.Container.Snapshot {
        app.installRuntimeClientForTesting(appTestOrchestrator(runner: runner, runtimeKind: .appleContainer))
        app.registryManifestLookup = { _, _ in .init(digest: UpdateRecoveryRunner.newDigest, authenticated: false) }
        await app.containers.refresh()
        await app.refreshImagesIfNeeded(force: true)
        let source = try #require(app.containers.snapshots.first)
        app.imageUpdates[app.imageUpdateKey(source.image, runtimeKind: .appleContainer)] =
            .resolved(localDigest: UpdateRecoveryRunner.oldDigest, remoteDigest: UpdateRecoveryRunner.newDigest)
        #expect(app.containerImageUpdateState(for: source).needsPull)
        return source
    }

    @Test func pulledTagRemainsReadyUntilContainerIsRecreated() throws {
        let app = AppModel(database: AppDatabase(isStoredInMemoryOnly: true))
        let reference = "docker.io/library/nginx:latest"
        let snapshot = try Core.Container.JSON.decode(
            Core.Container.Snapshot.self,
            from: Data("""
            {
              "configuration": {
                "id": "web",
                "image": {
                  "reference": "\(reference)",
                  "descriptor": { "digest": "sha256:old" }
                },
                "initProcess": {}
              },
              "id": "web",
              "status": { "state": "running" }
            }
            """.utf8),
            runtimeKind: .appleContainer
        )
        let images = try Core.Container.JSON.decode(
            [Core.Image.Resource].self,
            from: Data("""
            [{
              "configuration": {
                "name": "\(reference)",
                "descriptor": { "digest": "sha256:new" }
              },
              "id": "new",
              "variants": []
            }]
            """.utf8),
            runtimeKind: .appleContainer
        )
        app.setImages(images)
        app.imageUpdates[app.imageUpdateKey(reference, runtimeKind: .appleContainer)] =
            .resolved(localDigest: "sha256:new", remoteDigest: "sha256:new")

        #expect(app.containerImageUpdateState(for: snapshot) == .updateReady)

        app.imageUpdates[app.imageUpdateKey(reference, runtimeKind: .appleContainer)] =
            .resolved(localDigest: "sha256:new", remoteDigest: "sha256:newer")
        #expect(app.containerImageUpdateState(for: snapshot) == .updateAvailable)
    }

    @Test func repositoryGroupUsesUpdateStateFromEveryTag() throws {
        let app = AppModel(database: AppDatabase(isStoredInMemoryOnly: true))
        let images = try Core.Container.JSON.decode(
            [Core.Image.Resource].self,
            from: Data("""
            [
              {
                "configuration": {
                  "name": "ghcr.io/seerr-team/seerr:develop",
                  "descriptor": { "digest": "sha256:develop" }
                },
                "id": "develop",
                "variants": []
              },
              {
                "configuration": {
                  "name": "ghcr.io/seerr-team/seerr:latest",
                  "descriptor": { "digest": "sha256:latest" }
                },
                "id": "latest",
                "variants": []
              }
            ]
            """.utf8),
            runtimeKind: .appleContainer
        )
        app.setImages(images)
        let group = try #require(app.localImageGroups().first)
        app.imageUpdates[app.imageUpdateKey("ghcr.io/seerr-team/seerr:develop", runtimeKind: .appleContainer)] =
            .resolved(localDigest: "sha256:develop", remoteDigest: "sha256:develop")
        app.imageUpdates[app.imageUpdateKey("ghcr.io/seerr-team/seerr:latest", runtimeKind: .appleContainer)] =
            .resolved(localDigest: "sha256:latest", remoteDigest: "sha256:new")

        #expect(app.imageUpdateStatus(for: group).state == .updateAvailable)
        #expect(app.firstImageTagWithUpdate(in: group)?.reference == "ghcr.io/seerr-team/seerr:latest")
    }
}

enum UpdatePreflightFailure: Sendable {
    case imagePreservation, recipeSave, recoveryRead, pendingRecovery
}

private enum UpdateRecoveryError: Error { case failed }

private actor UpdateRecoveryRunner: Core.Command.Running {
    static let reference = "ghcr.io/example/web:latest"
    static let oldDigest = "sha256:" + String(repeating: "a", count: 64)
    static let newDigest = "sha256:" + String(repeating: "b", count: 64)
    static let pinnedReference = "ghcr.io/example/web@\(oldDigest)"
    static let alias = "ghcr.io/example/web:contained-recovery-" + String(repeating: "a", count: 64)
    private let preservationFails: Bool
    private let pullFails: Bool
    private let beforePull: @MainActor @Sendable () -> Void
    private var tagMoved = false
    private var aliasPreserved = false
    private var exists = true
    private var state = "running"
    private var containerDigest = oldDigest
    private var failNextReplacement: Bool
    private(set) var commands: [[String]] = []

    init(preservationFails: Bool = false, pullFails: Bool = false, originalWasRunning: Bool = true,
         failNextReplacement: Bool = false,
         beforePull: @escaping @MainActor @Sendable () -> Void = {}) {
        self.preservationFails = preservationFails
        self.pullFails = pullFails
        self.beforePull = beforePull
        self.failNextReplacement = failNextReplacement
        state = originalWasRunning ? "running" : "stopped"
    }

    func run(_ arguments: [String], stdin: Data?, priority: Core.Command.ExecutionPriority) async throws -> Data {
        commands.append(arguments)
        switch arguments {
        case ["image", "list", "--format", "json"]:
            var images = [try Self.image(reference: Self.reference, digest: tagMoved ? Self.newDigest : Self.oldDigest)]
            if aliasPreserved { images.append(try Self.image(reference: Self.alias, digest: Self.oldDigest)) }
            return try JSONEncoder().encode(images)
        case ["image", "tag", Self.reference, Self.alias]:
            guard !preservationFails else { throw UpdateRecoveryError.failed }
            aliasPreserved = true
            return Data()
        case ["image", "inspect", Self.alias]:
            guard aliasPreserved else { throw UpdateRecoveryError.failed }
            return try JSONEncoder().encode([Self.image(reference: Self.alias, digest: Self.oldDigest)])
        case ["image", "inspect", Self.reference]:
            return try JSONEncoder().encode([Self.image(reference: Self.reference, digest: tagMoved ? Self.newDigest : Self.oldDigest)])
        case ["image", "inspect", Self.pinnedReference]:
            throw UpdateRecoveryError.failed
        case ["list", "--all", "--format", "json"]:
            guard exists else { return Data("[]".utf8) }
            return Data("""
            [{"configuration":{"id":"web","image":{"reference":"\(Self.reference)","descriptor":{"digest":"\(containerDigest)"}},"initProcess":{}},"id":"web","status":{"state":"\(state)"}}]
            """.utf8)
        case ["stop", "web"]:
            state = "stopped"
            return Data()
        case ["delete", "--force", "web"]:
            exists = false
            return Data()
        default:
            if arguments.first == "run" || arguments.first == "create" {
                if failNextReplacement, !arguments.contains(Self.alias) {
                    failNextReplacement = false
                    throw UpdateRecoveryError.failed
                }
                exists = true
                state = arguments.first == "run" ? "running" : "stopped"
                containerDigest = arguments.contains(Self.alias) ? Self.oldDigest : Self.newDigest
                return Data("web\n".utf8)
            }
            return Data("[]".utf8)
        }
    }

    func clearCommands() { commands.removeAll() }

    nonisolated func stream(_ arguments: [String], priority: Core.Command.ExecutionPriority) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.pull(arguments)
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    }

    private func pull(_ arguments: [String]) async throws {
        commands.append(arguments)
        await beforePull()
        guard !pullFails else { throw UpdateRecoveryError.failed }
        tagMoved = true
    }

    private static func image(reference: String, digest: String) throws -> Core.Image.Resource {
        try Core.Container.JSON.decode(Core.Image.Resource.self, from: Data("""
        {"configuration":{"name":"\(reference)","descriptor":{"digest":"\(digest)"}},"id":"\(digest)","variants":[]}
        """.utf8), runtimeKind: .appleContainer)
    }
}

import Foundation
import Testing
import ContainedCore
@testable import ContainedApp

@Suite("Inventory failure consistency")
@MainActor
struct InventoryConsistencyTests {
    @Test func firstPartialImageLoadRetainsUnverifiedSavedStatusUntilRuntimeReturns() async {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let appleKey = "apple-container::" + Core.Registry.ImageReference.normalizedKey("alpine:latest")
        let dockerKey = "docker::" + Core.Registry.ImageReference.normalizedKey("nginx:latest")
        let appleStatus = Core.Image.UpdateStatus(state: .current, localDigest: "sha256:apple")
        let dockerStatus = Core.Image.UpdateStatus(state: .current, localDigest: "sha256:docker")
        database.updateImageStatuses([appleKey: appleStatus, dockerKey: dockerStatus])
        let apple = InventoryAuditRunner(kind: .appleContainer)
        let docker = InventoryAuditRunner(kind: .docker)
        await docker.setUnavailable(true)
        let app = AppModel(database: database)
        app.installRuntimeClientForTesting(appTestOrchestrator(runners: [.appleContainer: apple, .docker: docker]))

        await app.refreshImagesIfNeeded(force: true)

        #expect(app.imageUpdates[appleKey] == appleStatus)
        #expect(app.imageUpdates[dockerKey] == nil)
        #expect(database.imageStatusesSnapshot()[dockerKey] == dockerStatus)
        app.imageUpdates[appleKey] = .init(state: .updateAvailable, localDigest: "sha256:apple", remoteDigest: "sha256:new")
        #expect(database.imageStatusesSnapshot()[dockerKey] == dockerStatus)

        await docker.setUnavailable(false)
        await app.refreshImagesIfNeeded(force: true)

        #expect(app.imageUpdates[dockerKey] == dockerStatus)
        #expect(database.imageStatusesSnapshot()[dockerKey] == dockerStatus)
    }

    @Test func partialRefreshPreservesUnavailableContainersImagesAndMetrics() async throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let apple = InventoryAuditRunner(kind: .appleContainer)
        let docker = InventoryAuditRunner(kind: .docker)
        let app = AppModel(database: database)
        app.installRuntimeClientForTesting(appTestOrchestrator(runners: [.appleContainer: apple, .docker: docker]))
        await app.containers.refresh()
        await app.refreshImagesIfNeeded(force: true)
        let originalIDs = Set(app.containers.snapshots.map(\.scopedID))
        let originalImages = app.images
        #expect(originalIDs.count == 2)
        #expect(originalImages.count == 2)
        app.containers.applyStreamedStats([.init(id: "docker::web", cpuCoreFraction: 0.1,
                                                memoryUsageBytes: 1, memoryLimitBytes: 10,
                                                blockReadBytes: 0, blockWriteBytes: 0,
                                                networkRxBytes: 0, networkTxBytes: 0, numProcesses: 1)])
        let savedStats = app.containers.statsByID["docker::web"]
        let statusKey = "docker::" + Core.Registry.ImageReference.normalizedKey("nginx:latest")
        app.imageUpdates[statusKey] = .init(state: .current, localDigest: "sha256:docker")

        await docker.setUnavailable(true)
        await app.containers.refresh()
        await app.refreshImagesIfNeeded(force: true)

        #expect(Set(app.containers.snapshots.map(\.scopedID)) == originalIDs)
        #expect(app.containers.authoritativeRuntimeKinds == [.appleContainer])
        #expect(app.containers.statsByID["docker::web"] == savedStats)
        #expect(Set(app.images.map(\.reference)) == Set(originalImages.map(\.reference)))
        #expect(app.imageInventoryRuntimeKinds == [.appleContainer])
        #expect(app.containers.errorMessage != nil)
        #expect(app.imagesError != nil)
        #expect(try database.fetchRequired(ContainerRecord.self).allSatisfy { !$0.isMissing })
        #expect(database.imageStatusesSnapshot()[statusKey]?.state == .current)

        await docker.setUnavailable(false)
        await docker.setRemoved(true)
        await app.containers.refresh()
        await app.refreshImagesIfNeeded(force: true)

        #expect(app.containers.snapshots.map(\.runtimeKind) == [.appleContainer])
        #expect(app.images.map(\.runtimeKind) == [.appleContainer])
        #expect(try database.fetchRequired(ContainerRecord.self).allSatisfy { $0.runtimeKindRaw != "docker" })
        #expect(app.containers.errorMessage == nil)
        #expect(app.imagesError == nil)
    }

    @Test func orphanCleanupDoesNothingWithoutCompleteFreshInventories() async throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let apple = InventoryAuditRunner(kind: .appleContainer)
        let docker = InventoryAuditRunner(kind: .docker)
        let app = AppModel(database: database)
        app.installRuntimeClientForTesting(appTestOrchestrator(runners: [.appleContainer: apple, .docker: docker]))
        let id = "docker::gone"
        saveMetadata(in: app, id: id)
        await docker.setUnavailable(true)

        await app.purgeDeadRows()

        #expect(app.personalization.override(for: id)?.nickname == "Saved")
        #expect(app.healthChecks.check(for: id)?.enabled == true)
        #expect(try database.fetchRequired(EventRecord.self).contains { $0.containerID == id })
        #expect(!app.purgingOrphans)
    }

    @Test func successfulOrphanCleanupProtectsRecoveryMigrationAndUnqueriedRuntimes() async throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let app = AppModel(database: database)
        app.installRuntimeClientForTesting(appTestOrchestrator(runner: InventoryAuditRunner(kind: .docker), runtimeKind: .docker))
        let pending = Core.Container.Snapshot.placeholder(id: "pending", image: "nginx:original", runtimeKind: .docker)
        let migrating = Core.Container.Snapshot.placeholder(id: "migrating", image: "nginx:original", runtimeKind: .docker)
        #expect(database.markContainerRecreateStarted(source: pending, sourceDocument: .containerRecovery(from: pending.configuration)))
        database.markContainerRecreateFailed(scopedID: pending.scopedID)
        database.markContainerMigrationStarted(source: migrating, targetRuntimeKind: .appleContainer,
                                               sourceDocument: .containerRecovery(from: migrating.configuration))
        let protectedIDs = [pending.scopedID, migrating.scopedID, "apple-container::offline"]
        for id in protectedIDs + ["docker::gone"] { saveMetadata(in: app, id: id) }

        await app.purgeDeadRows()

        for id in protectedIDs {
            #expect(app.personalization.override(for: id)?.nickname == "Saved")
            #expect(app.healthChecks.check(for: id)?.enabled == true)
            #expect(try database.fetchRequired(EventRecord.self).contains { $0.containerID == id })
        }
        #expect(app.personalization.override(for: "docker::gone") == nil)
        #expect(app.healthChecks.check(for: "docker::gone") == nil)
        #expect(try database.fetchRequired(EventRecord.self).contains { $0.containerID == "docker::gone" } == false)
        #expect(database.containerRecreationRecoveries().map(\.id) == [pending.scopedID])
    }

    @Test func pendingRecoveryBlocksAnotherRecreateBeforeRuntimeCommands() async throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let runner = InventoryAuditRunner(kind: .docker)
        let app = AppModel(database: database)
        app.installRuntimeClientForTesting(appTestOrchestrator(runner: runner, runtimeKind: .docker))
        await app.containers.refresh()
        let partial = try #require(app.containers.snapshots.first)
        let original = Core.Container.Snapshot.placeholder(id: partial.id, image: "nginx:original", runtimeKind: .docker)
        #expect(database.markContainerRecreateStarted(source: original, sourceDocument: .containerRecovery(from: original.configuration)))
        database.markContainerRecreateFailed(scopedID: original.scopedID)
        let calls = await runner.callCount

        let result = await app.recreateContainer(originalID: partial.scopedID, spec: ContainerFormState(from: partial.configuration))

        #expect(result == nil)
        #expect(await runner.callCount == calls)
        #expect(database.containerRecreationRecoveries().first?.snapshot == original)
    }

    @Test func orphanCleanupKeepsOriginalImageStyleBehindAPartialReplacement() async throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let app = AppModel(database: database)
        app.installRuntimeClientForTesting(appTestOrchestrator(runner: InventoryAuditRunner(kind: .docker), runtimeKind: .docker))
        await app.containers.refresh()
        let partial = try #require(app.containers.snapshots.first)
        let original = Core.Container.Snapshot.placeholder(id: partial.id, image: "nginx:original", runtimeKind: .docker)
        #expect(database.markContainerRecreateStarted(source: original, sourceDocument: .containerRecovery(from: original.configuration)))
        database.markContainerRecreateFailed(scopedID: original.scopedID)
        _ = await database.upsertContainers([partial])
        var style = Personalization()
        style.nickname = "Original image"
        app.personalization.setImageDefault(style, for: original.image)

        await app.purgeDeadRows()

        #expect(app.personalization.imageDefault(for: original.image)?.nickname == "Original image")
        #expect(database.containerRecreationRecoveries().first?.snapshot == original)
    }

    private func saveMetadata(in app: AppModel, id: String) {
        var style = Personalization()
        style.nickname = "Saved"
        app.personalization.setOverride(style, for: id)
        app.healthChecks.setCheck(.init(command: ["true"], enabled: true), for: id)
        app.historyStore.record(.ui, containerID: id, message: "Saved metadata")
    }
}

private actor InventoryAuditRunner: Core.Command.Running {
    let kind: Core.Runtime.Kind
    private var unavailable = false
    private var removed = false
    private let docker = DockerRecordingRunner()
    private(set) var callCount = 0

    init(kind: Core.Runtime.Kind) { self.kind = kind }
    func setUnavailable(_ value: Bool) { unavailable = value }
    func setRemoved(_ value: Bool) { removed = value }

    func run(_ arguments: [String], stdin: Data?, priority: Core.Command.ExecutionPriority) async throws -> Data {
        callCount += 1
        if unavailable { throw NSError(domain: "InventoryAudit", code: 1) }
        if kind == .docker {
            if arguments.starts(with: ["image", "ls"]) {
                return removed ? Data() : Data(#"{"Repository":"nginx","Tag":"latest","Digest":"sha256:docker","ID":"sha256:docker"}"#.utf8)
            }
            if removed, arguments.starts(with: ["container", "ls"]) { return Data() }
            return try await docker.run(arguments, stdin: stdin, priority: priority)
        }
        if arguments == ["list", "--all", "--format", "json"] {
            return removed ? Data("[]".utf8) : Data(#"[{"configuration":{"id":"apple-web","image":{"reference":"alpine:latest"},"initProcess":{},"labels":{}},"id":"apple-web","status":{"state":"running"}}]"#.utf8)
        }
        if arguments == ["image", "list", "--format", "json"] {
            return Data(#"[{"configuration":{"name":"alpine:latest","descriptor":{"digest":"sha256:apple"}},"id":"sha256:apple","variants":[]}]"#.utf8)
        }
        return Data("[]".utf8)
    }

    nonisolated func stream(_ arguments: [String], priority: Core.Command.ExecutionPriority) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

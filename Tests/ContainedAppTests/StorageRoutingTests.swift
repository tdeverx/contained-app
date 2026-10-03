import Foundation
import Testing
import ContainedCore
@testable import ContainedApp

@Suite("Storage cleanup routing")
@MainActor
struct StorageRoutingTests {
    @Test func freeUpSpaceNeverSelectsDeletionByDefaultOrRunsPruneDuringPreview() async {
        for action in Core.System.CleanupAction.allCases {
            #expect(AppModel.cleanupSelectedByDefault(action, recommended: true) == (action.risk == .compaction))
            #expect(AppModel.cleanupSelectedByDefault(action, recommended: false))
        }
        let runner = DockerRecordingRunner()
        let app = AppModel(database: AppDatabase(isStoredInMemoryOnly: true))
        app.installRuntimeClientForTesting(appTestOrchestrator(runner: runner, runtimeKind: .docker))
        await app.prepareFreeUpSpace()
        #expect(app.storageCleanupRecommended)
        #expect(Set(app.runtimePruneRequests.map(\.action)) == [.unusedImages, .unusedVolumes, .unusedNetworks])
        #expect(!(await runner.contains(["image", "prune", "--force", "--all"])))
        #expect(!(await runner.contains(["volume", "prune", "--force"])))
    }

    @Test func dockerImageCleanupRequiresConfirmationAndUsesItsNativeRoute() async {
        let runner = DockerRecordingRunner()
        let app = AppModel(database: AppDatabase(isStoredInMemoryOnly: true))
        app.installRuntimeClientForTesting(appTestOrchestrator(runner: runner, runtimeKind: .docker))
        await app.prepareStorageCleanup(.unusedImages)
        #expect(app.storageCleanupPlans.isEmpty)
        #expect(app.runtimePruneRequests.count == 1)
        #expect(!(await runner.contains(["image", "prune", "--force", "--all"])))
        await app.performStorageCleanup([], pruneRequests: app.runtimePruneRequests)
        #expect(await runner.contains(["image", "prune", "--force", "--all"]))
    }

    @Test func cleanupCannotDeleteRecoveryResourcesDuringALifecycleOperation() async {
        let runner = DockerRecordingRunner()
        let app = AppModel(database: AppDatabase(isStoredInMemoryOnly: true))
        app.installRuntimeClientForTesting(appTestOrchestrator(runner: runner, runtimeKind: .docker))
        await app.prepareStorageCleanup(.unusedImages)
        app.containers.busyIDs.insert("docker::web")
        await app.performStorageCleanup([], pruneRequests: app.runtimePruneRequests)
        #expect(!(await runner.contains(["image", "prune", "--force", "--all"])))
    }

    @Test func pendingMissingContainerRecoveryProtectsResourcesEvenAfterPreview() async {
        let runner = DockerRecordingRunner()
        let app = AppModel(database: AppDatabase(isStoredInMemoryOnly: true))
        app.installRuntimeClientForTesting(appTestOrchestrator(runner: runner, runtimeKind: .docker))
        await app.prepareStorageCleanup(.unusedImages)
        let source = Core.Container.Snapshot.placeholder(id: "missing", image: "alpine", runtimeKind: .docker)
        #expect(app.database.markContainerRecreateStarted(source: source, sourceDocument: .containerRecovery(from: source.configuration)))
        app.database.markContainerRecreateFailed(scopedID: source.scopedID)
        await app.performStorageCleanup([], pruneRequests: app.runtimePruneRequests)
        #expect(!(await runner.contains(["image", "prune", "--force", "--all"])))
        await app.prepareStorageCleanup(.unusedVolumes)
        #expect(app.runtimePruneRequests.isEmpty)
    }

    @Test func runtimePruneRemainsAvailableWithoutAppleStorageManagement() {
        let docker = Core.Runtime.Descriptor(kind: .docker, displayName: "Docker",
                                             capabilities: [.containers, .images, .volumes, .networks])
        let apple = Core.Runtime.Descriptor(kind: .appleContainer, displayName: "Apple Container",
                                            capabilities: [.storageManagement])
        for action in [Core.System.CleanupAction.stoppedContainers, .danglingImages, .unusedImages, .unusedVolumes, .unusedNetworks] {
            #expect(AppModel.cleanupRuntimes([docker], for: action) == [docker])
            #expect(AppModel.cleanupRuntimes([docker, apple], for: action) == [docker, apple])
        }
        #expect(AppModel.cleanupRuntimes([docker], for: .compactRunningContainers).isEmpty)
        #expect(AppModel.cleanupRuntimes([docker], for: .resetBuilderCache).isEmpty)
        #expect(AppModel.cleanupRuntimes([docker, apple], for: .compactRunningContainers) == [apple])
    }
}

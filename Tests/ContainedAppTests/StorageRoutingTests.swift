import Foundation
import Testing
import ContainedCore
@testable import ContainedApp

@Suite("Storage cleanup routing")
@MainActor
struct StorageRoutingTests {
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

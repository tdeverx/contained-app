import Foundation
import Observation
import Synchronization
import Testing
import ContainedCore
@testable import ContainedApp

@Suite("Resource view state")
@MainActor
struct ResourceViewStateTests {
    @Test func warmImageGroupCacheObservesInventoryChanges() throws {
        let app = AppModel(database: AppDatabase(isStoredInMemoryOnly: true))
        let initialImages = try images(reference: "example/app:latest", digest: "sha256:initial")
        app.setImages(initialImages)
        let initialGroups = app.localImageGroups()
        #expect(!initialGroups.isEmpty)

        let invalidations = Mutex(0)
        withObservationTracking {
            #expect(app.localImageGroups() == initialGroups)
        } onChange: {
            invalidations.withLock { $0 += 1 }
        }

        let updatedImages = try images(reference: "example/app:latest", digest: "sha256:updated")
        app.setImages(updatedImages)

        #expect(invalidations.withLock { $0 } == 1)
        #expect(app.localImageGroups() == Core.Image.LocalTagGroup.groups(for: updatedImages))
        #expect(app.localImageGroups() != initialGroups)
    }

    @Test func warmEmptyImageGroupCacheObservesFirstInventory() throws {
        let app = AppModel(database: AppDatabase(isStoredInMemoryOnly: true))
        #expect(app.localImageGroups().isEmpty)
        let invalidations = Mutex(0)
        withObservationTracking {
            _ = app.localImageGroups()
        } onChange: {
            invalidations.withLock { $0 += 1 }
        }

        app.setImages(try images(reference: "example/app:latest", digest: "sha256:first"))

        #expect(invalidations.withLock { $0 } == 1)
        #expect(app.localImageGroups().count == 1)
    }

    @Test func expandedContainerUsesCurrentStateAndRetainsMissingSnapshot() {
        let original = Core.Container.Snapshot.placeholder(id: "web", image: "example/app:latest",
                                                            state: .running, runtimeKind: .docker)
        let stopped = Core.Container.Snapshot.placeholder(id: "web", image: "example/app:latest",
                                                           state: .stopped, runtimeKind: .docker)
        let unrelated = Core.Container.Snapshot.placeholder(id: "web", image: "example/other:latest",
                                                             state: .running, runtimeKind: .appleContainer)
        let detail = ContainersGridView.DetailSource(snapshot: original)

        #expect(detail.currentSnapshot(in: [unrelated, stopped]) == stopped)
        #expect(detail.currentSnapshot(in: [unrelated, original]) == original)
        #expect(detail.currentSnapshot(in: [unrelated]) == original)
        #expect(detail.currentSnapshot(in: []) == original)
    }

    private func images(reference: String, digest: String) throws -> [Core.Image.Resource] {
        try Core.Container.JSON.decode([Core.Image.Resource].self,
                                       from: Data("""
                                       [{
                                         "configuration": {
                                           "name": "\(reference)",
                                           "descriptor": { "digest": "\(digest)" }
                                         },
                                         "id": "\(digest)",
                                         "variants": []
                                       }]
                                       """.utf8),
                                       runtimeKind: .docker)
    }
}

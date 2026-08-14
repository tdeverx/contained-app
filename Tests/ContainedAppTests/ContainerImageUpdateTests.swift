import Foundation
import Testing
import ContainedCore
@testable import ContainedApp

@Suite("Container image update state")
@MainActor
struct ContainerImageUpdateTests {
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
}

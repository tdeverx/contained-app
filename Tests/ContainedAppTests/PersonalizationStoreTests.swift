import Foundation
import Testing
import ContainedCore
@testable import ContainedApp

@Suite("Image personalization identity")
@MainActor
struct PersonalizationStoreTests {
    @Test func imageTagStylesUseCanonicalReferences() {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let store = PersonalizationStore(database: database)
        var style = Personalization()
        style.nickname = "Web image"

        store.setImageDefault(style, for: "nginx")

        #expect(store.imageDefault(for: "docker.io/library/nginx:latest") == style)
        #expect(database.fetch(PersonalizationRecord.self).contains {
            $0.key == "image-ref:docker.io/library/nginx:latest"
        })
    }

    @Test func digestKeyedGroupStyleMigratesThroughRetainedImageRecord() throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        var style = Personalization()
        style.nickname = "My image group"
        database.context.insert(ImageRecord(identity: "sha256:old",
                                            primaryReference: "nginx:latest",
                                            digest: "sha256:old"))
        database.context.insert(PersonalizationRecord(
            key: "image-group:sha256:old",
            scopeRaw: "personalizationImageDefaults",
            valueData: try JSONEncoder().encode(style)
        ))
        database.save()

        let store = PersonalizationStore(database: database)
        let updatedGroup = try imageGroup(reference: "docker.io/library/nginx:latest",
                                          digest: "sha256:new")

        #expect(store.imageGroupDefault(for: updatedGroup) == style)
        #expect(database.fetch(PersonalizationRecord.self).contains {
            $0.key == "image-group-ref:docker.io/library/nginx:latest"
        })
    }

    private func imageGroup(reference: String,
                            digest: String) throws -> Core.Image.LocalTagGroup {
        let images = try Core.Container.JSON.decode(
            [Core.Image.Resource].self,
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
            runtimeKind: .appleContainer
        )
        return try #require(Core.Image.LocalTagGroup.groups(for: images).first)
    }
}

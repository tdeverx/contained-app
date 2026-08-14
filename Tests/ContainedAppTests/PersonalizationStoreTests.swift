import Foundation
import Testing
import ContainedCore
@testable import ContainedApp

@Suite("Image personalization identity")
@MainActor
struct PersonalizationStoreTests {
    @Test func persistenceKeepsEveryConfiguredWidget() throws {
        var style = Personalization()
        style.widgets = (0..<8).map { index in
            WidgetConfiguration(metric: index.isMultiple(of: 2) ? .cpu : .memory)
        }

        let saved = style.normalizedForPersistence()
        let restored = try JSONDecoder().decode(Personalization.self,
                                                from: JSONEncoder().encode(saved))

        #expect(restored.widgets.count == 8)
    }

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

    @Test func containerMetadataDoesNotBlockImageAppearanceInheritance() {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let store = PersonalizationStore(database: database)
        var imageStyle = Personalization()
        imageStyle.tint = .red
        store.setImageDefault(imageStyle, for: "nginx:latest")

        var metadata = Personalization()
        metadata.nickname = "Dashboard"
        metadata.webURL = "localhost:8080/admin"
        metadata.showStatusText = false
        store.setOverride(metadata, for: "docker:web")

        let resolved = store.resolved(id: "docker:web", image: "nginx:latest")
        #expect(resolved.tint == .red)
        #expect(resolved.nickname == "Dashboard")
        #expect(resolved.webURL == "localhost:8080/admin")
        #expect(resolved.showStatusText == false)
        #expect(store.hasOverride(id: "docker:web"))
        #expect(!store.hasAppearanceOverride(id: "docker:web"))
    }

    @Test func browserDestinationFallsBackToPublishedPort() throws {
        let snapshot = try Core.Container.JSON.decode(
            Core.Container.Snapshot.self,
            from: Data("""
            {
              "configuration": {
                "id": "web",
                "image": { "reference": "nginx:latest" },
                "initProcess": {},
                "publishedPorts": [{ "containerPort": 80, "hostPort": 8080 }]
              },
              "id": "web",
              "status": { "state": "running" }
            }
            """.utf8),
            runtimeKind: .docker
        )

        #expect(ContainerWebDestination.url(customValue: "", for: snapshot)?.absoluteString
                == "http://localhost:8080")
        #expect(ContainerWebDestination.url(customValue: "example.com/admin", for: snapshot)?.absoluteString
                == "http://example.com/admin")
    }

    @Test func explicitDefaultAppearanceCanOverrideAnImageStyle() {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let store = PersonalizationStore(database: database)
        var imageStyle = Personalization()
        imageStyle.tint = .red
        store.setImageDefault(imageStyle, for: "nginx:latest")

        var containerStyle = Personalization()
        containerStyle.appearanceOverrideEnabled = true
        store.setOverride(containerStyle, for: "docker:web")

        let resolved = store.resolved(id: "docker:web", image: "nginx:latest")
        #expect(resolved.tint == .multicolor)
        #expect(store.hasAppearanceOverride(id: "docker:web"))
    }

    @Test func imageAndTagNicknamesComposeWithoutBlockingAppearanceInheritance() throws {
        let app = AppModel(database: AppDatabase(isStoredInMemoryOnly: true))
        let reference = "testing.repo/biglongnameforimageurl/othertext:biglongnamefortag"
        let group = try imageGroup(reference: reference, digest: "sha256:names")
        app.setImages(group.images)

        var imageStyle = Personalization()
        imageStyle.tint = .red
        imageStyle.nickname = "nice-image"
        app.personalization.setImageGroupDefault(imageStyle, for: group)

        var tagIdentity = Personalization()
        tagIdentity.nickname = "latest"
        app.personalization.setImageDefault(tagIdentity, for: reference)

        #expect(app.imageGroupDisplayName(for: group) == "nice-image")
        #expect(app.imageDisplayName(for: reference) == "nice-image:latest")
        #expect(app.imageStyle(for: reference).tint == .red)
        #expect(app.imageStyle(for: reference).nickname == "latest")
        #expect(!app.personalization.hasImageAppearanceOverride(for: reference))
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

import Foundation
import Testing
import ContainedCore
@testable import ContainedApp

@Suite("Registry update recovery")
@MainActor
struct RegistryUpdateRecoveryTests {
    @Test func activityCoalescesAndExplicitRetryAndCredentialChangesResetBackoff() async throws {
        let db = AppDatabase(isStoredInMemoryOnly: true)
        let app = AppModel(database: db)
        var requests = 0
        app.registryManifestLookup = { _, _ in
            requests += 1
            throw Core.Registry.ManifestError.unauthorized
        }
        await app.checkImageUpdate("ghcr.io/team/one", runtimeKind: .appleContainer, notify: false)
        await app.checkImageUpdate("ghcr.io/team/two", runtimeKind: .appleContainer, notify: false)
        await app.checkImageUpdate("ghcr.io/team/one", runtimeKind: .appleContainer, notify: false)
        #expect(requests == 2)
        #expect(db.fetch(EventRecord.self).filter { $0.kindRaw == "registry" }.count == 1)
        let entry = try #require(app.registryUpdateFailures.first)
        await app.retryRegistryUpdates(entry)
        #expect(requests == 4)
        app.registryCredentialsChanged(host: "ghcr.io", runtimeKind: .appleContainer)
        #expect(app.registryUpdateFailures.isEmpty)
        #expect(app.imageUpdates.values.allSatisfy { $0.registryHost == "ghcr.io" && $0.failureCode == "unauthorized" })
    }
}

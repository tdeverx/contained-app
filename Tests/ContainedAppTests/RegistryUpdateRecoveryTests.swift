import Foundation
import Testing
import ContainedCore
@testable import ContainedApp

@Suite("Registry update recovery")
@MainActor
struct RegistryUpdateRecoveryTests {
    @Test func backgroundRetryHonorsBackoffWithoutRepeatingHealthyChecksOrDelayingFullSweep() async throws {
        let app = AppModel(database: AppDatabase(isStoredInMemoryOnly: true))
        let reference = "ghcr.io/team/retry:latest"
        let healthy = "other.test/team/healthy:latest"
        let images = try Core.Container.JSON.decode([Core.Image.Resource].self, from: Data("""
        [
          {"configuration":{"name":"\(reference)","descriptor":{"digest":"sha256:old"}},"id":"retry","variants":[]},
          {"configuration":{"name":"\(healthy)","descriptor":{"digest":"sha256:old"}},"id":"healthy","variants":[]}
        ]
        """.utf8), runtimeKind: .appleContainer)
        app.setImages(images)
        app.settings.imageUpdateChecksEnabled = true
        let now = Date()
        app.lastImageUpdateSweep = now
        var requests: [String] = []
        app.registryManifestLookup = { reference, _ in
            requests.append(reference)
            return .init(digest: "sha256:new", authenticated: false)
        }
        app.registryRetryPolicy.failed(reference, runtimeKind: .appleContainer, kind: .network, now: now)
        #expect(app.imageUpdateNextRunDate == now.addingTimeInterval(300))
        await app.checkImageUpdatesIfNeeded(now: now.addingTimeInterval(299))
        #expect(requests.isEmpty)
        // Make the retry due for both the scheduler and actual credential request guard.
        app.registryRetryPolicy.reset(reference, runtimeKind: .appleContainer)
        app.registryRetryPolicy.failed(reference, runtimeKind: .appleContainer, kind: .network,
                                       now: now.addingTimeInterval(-301))
        app.registryRetryPolicy.failed("removed.test/team/gone", runtimeKind: .appleContainer, kind: .network,
                                       now: now.addingTimeInterval(-301))
        app.registryRetryPolicy.failed(reference, runtimeKind: .docker, kind: .network,
                                       now: now.addingTimeInterval(-301))
        app.settings.imageUpdateChecksEnabled = false
        await app.checkImageUpdatesIfNeeded(now: now)
        #expect(requests.isEmpty)
        app.settings.imageUpdateChecksEnabled = true
        await app.checkImageUpdatesIfNeeded(now: now)
        #expect(requests == [reference])
        #expect(app.lastImageUpdateSweep == now)
        #expect(app.nextLocalRegistryRetryDate == nil)
        await app.checkImageUpdatesIfNeeded(now: now.addingTimeInterval(1))
        #expect(requests == [reference])
    }

    @Test func credentialChangePreservesFailuresAsDueUntilBackgroundRetrySucceeds() async throws {
        let app = AppModel(database: AppDatabase(isStoredInMemoryOnly: true))
        let reference = "ghcr.io/team/private:latest"
        app.setImages(try Core.Container.JSON.decode([Core.Image.Resource].self, from: Data("""
        [{"configuration":{"name":"\(reference)","descriptor":{"digest":"sha256:old"}},"id":"private","variants":[]}]
        """.utf8), runtimeKind: .appleContainer))
        app.settings.imageUpdateChecksEnabled = true
        app.registryManifestLookup = { _, _ in throw Core.Registry.ManifestError.unauthorized }
        await app.checkImageUpdate(reference, runtimeKind: .appleContainer, notify: false)
        let sweep = Date()
        app.lastImageUpdateSweep = sweep
        app.registryCredentialsChanged(host: "ghcr.io", runtimeKind: .appleContainer)
        let due = try #require(app.registryUpdateFailures.first)
        #expect(due.references == [reference])
        #expect(due.retryAfter <= Date())
        #expect(due.attempts == 0)
        var requests = 0
        app.registryManifestLookup = { _, kind in
            #expect(kind == .appleContainer)
            requests += 1
            return .init(digest: "sha256:new", authenticated: true)
        }
        await app.checkImageUpdatesIfNeeded()
        #expect(requests == 1)
        #expect(app.registryUpdateFailures.isEmpty)
        #expect(app.imageUpdateStatus(for: reference, runtimeKind: .appleContainer).state == .updateAvailable)
        #expect(app.lastImageUpdateSweep == sweep)
    }

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
        #expect(app.registryUpdateFailures.allSatisfy { $0.attempts == 0 && $0.retryAfter <= Date() })
        #expect(app.imageUpdates.values.allSatisfy { $0.registryHost == "ghcr.io" && $0.failureCode == "unauthorized" })
    }
}

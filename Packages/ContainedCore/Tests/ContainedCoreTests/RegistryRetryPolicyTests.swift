import Foundation
import Testing
@testable import ContainedCore

@Suite("Registry retry policy")
struct RegistryRetryPolicyTests {
    @Test func recoveryAliasCleanupPreservesSharedRegistryBackoff() throws {
        var policy = Core.Registry.UpdateRetryPolicy()
        let alias = "ghcr.io/team/app:contained-recovery-" + String(repeating: "a", count: 64)
        let published = "ghcr.io/team/app:latest"
        let now = Date(timeIntervalSince1970: 1000)
        policy.failed(alias, runtimeKind: .appleContainer, kind: .notFound, now: now)
        policy.failed(alias, runtimeKind: .appleContainer, kind: .network, now: now)
        policy.failed(published, runtimeKind: .appleContainer, kind: .network, now: now)
        policy.failed(published, runtimeKind: .docker, kind: .unauthorized, now: now)
        var expected = policy.entries.values.filter { $0.references.contains(published) }
        for index in expected.indices { expected[index].references.removeAll { $0 == alias } }
        policy = try JSONDecoder().decode(Core.Registry.UpdateRetryPolicy.self, from: JSONEncoder().encode(policy))
        policy.removeLocalRecoveryAliases()
        #expect(policy.entries == Dictionary(uniqueKeysWithValues: expected.map { ($0.id, $0) }))
        let cleaned = policy
        policy.removeLocalRecoveryAliases()
        #expect(policy == cleaned)
    }

    @Test func authenticationCoalescesAndLeavesPublicAndUnrelatedImagesAvailable() {
        var policy = Core.Registry.UpdateRetryPolicy()
        let date = Date(timeIntervalSince1970: 1000)
        let first = policy.failed("ghcr.io/team/private:one", runtimeKind: .appleContainer, kind: .unauthorized, now: date)
        let second = policy.failed("ghcr.io/team/private:two", runtimeKind: .appleContainer, kind: .tokenUnavailable, now: date)
        #expect(first)
        #expect(!second)
        #expect(policy.entries.count == 1)
        #expect(policy.entries.values.first?.attempts == 1)
        #expect(!policy.shouldCheck("ghcr.io/team/private:one", runtimeKind: .appleContainer, now: date))
        #expect(policy.shouldCheck("ghcr.io/team/public", runtimeKind: .appleContainer, now: date))
        #expect(policy.shouldCheck("alpine", runtimeKind: .appleContainer, now: date))
        #expect(policy.shouldCheck("ghcr.io/team/private:one", runtimeKind: .docker, now: date))
        #expect(policy.shouldCheck("ghcr.io/team/private:one", runtimeKind: .appleContainer, now: date.addingTimeInterval(300)))
    }

    @Test func retryIsBoundedAndResetsAfterCredentialsOrAuthenticatedSuccess() throws {
        var policy = Core.Registry.UpdateRetryPolicy()
        var date = Date(timeIntervalSince1970: 1000)
        for _ in 0..<30 {
            policy.failed("alpine", runtimeKind: .appleContainer, kind: .unauthorized, now: date)
            let entry = try #require(policy.entries.values.first)
            #expect(entry.retryAfter.timeIntervalSince(date) <= 21_600)
            date = entry.retryAfter
        }
        policy.reset(host: "registry-1.docker.io", runtimeKind: .appleContainer)
        #expect(policy.entries.isEmpty)
        policy.failed("alpine", runtimeKind: .appleContainer, kind: .unauthorized, now: date)
        policy.succeeded("nginx", runtimeKind: .appleContainer, authenticated: false)
        #expect(!policy.entries.isEmpty)
        policy.succeeded("nginx", runtimeKind: .appleContainer, authenticated: true)
        #expect(policy.entries.isEmpty)
    }

    @Test func scheduledCredentialRetryRetainsReferencesAndOnlyResetsMatchingRuntimeHost() {
        var policy = Core.Registry.UpdateRetryPolicy()
        let now = Date(timeIntervalSince1970: 1000)
        for runtime in [Core.Runtime.Kind.appleContainer, .docker] {
            policy.failed("alpine", runtimeKind: runtime, kind: .unauthorized, now: now)
        }
        policy.failed("ghcr.io/team/app", runtimeKind: .appleContainer, kind: .unauthorized, now: now)
        let previous = policy.entries
        policy.scheduleRetry(host: "registry-1.docker.io", runtimeKind: .appleContainer, now: now)
        for entry in policy.entries.values {
            #expect(entry.references == previous[entry.id]?.references)
            if entry.host == "docker.io", entry.runtimeKind == .appleContainer {
                #expect(entry.attempts == 0)
                #expect(entry.retryAfter == now)
                #expect(policy.shouldCheck("alpine", runtimeKind: .appleContainer, now: now))
            } else {
                #expect(entry == previous[entry.id])
            }
        }
    }

    @Test func outcomeClassificationAndPrivacy() throws {
        #expect(Core.Registry.UpdateFailureKind.classify(Core.Registry.ManifestError.httpStatus(429)) == .rateLimited)
        #expect(Core.Registry.UpdateFailureKind.classify(URLError(.timedOut)) == .network)
        #expect(Core.Registry.UpdateFailureKind.classify(Core.Registry.ManifestError.notFound) == .notFound)
        #expect(Core.Registry.UpdateRetryPolicy.host(for: "secret@evil.test/image") == "docker.io")
        var policy = Core.Registry.UpdateRetryPolicy()
        policy.failed("ghcr.io/team/app", runtimeKind: .appleContainer, kind: .unauthorized)
        for unsafe in ["https://user:secret@ghcr.io/team/app", "ghcr.io/team/app:latest?token=secret", "user:secret@ghcr.io/team/app"] {
            let recorded = policy.failed(unsafe, runtimeKind: .appleContainer, kind: .unauthorized)
            #expect(!recorded)
            #expect(!policy.shouldCheck(unsafe, runtimeKind: .appleContainer))
        }
        let data = try JSONEncoder().encode(policy)
        #expect(!String(decoding: data, as: UTF8.self).contains("Authorization"))
        #expect(!String(decoding: data, as: UTF8.self).contains("secret"))
        #expect(try JSONDecoder().decode(Core.Registry.UpdateRetryPolicy.self, from: data) == policy)
    }
}

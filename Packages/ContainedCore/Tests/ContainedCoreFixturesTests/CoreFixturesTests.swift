import Testing
import ContainedCore
import ContainedCoreFixtures

@Suite("Core fixtures")
struct CoreFixturesTests {
    @Test func appleContainerFixturesAreDeterministicAndUsable() {
        #expect(Core.Fixtures.AppleContainer.webContainer.id == "preview-web")
        #expect(Core.Fixtures.AppleContainer.image.reference == "docker.io/library/nginx:latest")
        #expect(Core.Fixtures.AppleContainer.createRequest.image == Core.Fixtures.AppleContainer.image.reference)
        #expect(Core.Fixtures.AppleContainer.volume.name == "preview-data")
        #expect(Core.Fixtures.AppleContainer.network.status?.ipv4Subnet == "10.42.0.0/24")
        #expect(Core.Fixtures.AppleContainer.runtimes.map(\.kind) == [.appleContainer])
        #expect(Core.Fixtures.AppleContainer.unsupportedCapabilityError.packageErrorCode == "unsupportedRuntimeCapability")
        #expect(Core.Fixtures.AppleContainer.commandError.packageErrorContext["code"] == "42")
    }

    @Test func genericMetricFixturesAreStable() {
        #expect(!Core.Fixtures.Generic.sparklineValues.isEmpty)
        #expect(Core.Fixtures.Generic.metricHistory.count == Core.Fixtures.Generic.sparklineValues.count)
        #expect(Core.Fixtures.Generic.metricHistory.first?.cpuFraction == Core.Fixtures.Generic.sparklineValues.first)
    }
}

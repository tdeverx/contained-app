import Testing
import ContainedPreviewSupport

@Suite("Preview samples")
struct PreviewSamplesTests {
    @Test func samplesAreDeterministicAndUsable() {
        #expect(PreviewSamples.webContainer.id == "preview-web")
        #expect(PreviewSamples.image.reference == "docker.io/library/nginx:latest")
        #expect(!PreviewSamples.sparklineValues.isEmpty)
        #expect(PreviewSamples.createRequest.image == PreviewSamples.image.reference)
        #expect(PreviewSamples.volume.name == "preview-data")
        #expect(PreviewSamples.network.status?.ipv4Subnet == "10.42.0.0/24")
        #expect(PreviewSamples.metricHistory.count == PreviewSamples.sparklineValues.count)
        #expect(PreviewSamples.runtimes.map(\.kind).contains(.dockerCompatible))
        #expect(PreviewSamples.cardStyle.symbol == "shippingbox.fill")
        #expect(PreviewSamples.widgetConfigs.contains { $0.metric == .memory })
        #expect(PreviewSamples.activityEvents.contains { !$0.isRead })
        #expect(PreviewSamples.activityStatus.subjectID == PreviewSamples.image.reference)
        #expect(PreviewSamples.activityStatus.fraction == 0.62)
        #expect(PreviewSamples.unsupportedCapabilityError.packageErrorCode == "unsupportedRuntimeCapability")
        #expect(PreviewSamples.commandError.packageErrorContext["code"] == "42")
    }
}

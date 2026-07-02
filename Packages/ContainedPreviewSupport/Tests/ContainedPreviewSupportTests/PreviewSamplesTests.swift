import Testing
import ContainedPreviewSupport

@Suite("Preview samples")
struct PreviewSamplesTests {
    @Test func samplesAreDeterministicAndUsable() {
        #expect(PreviewSamples.webContainer.id == "preview-web")
        #expect(PreviewSamples.image.reference == "docker.io/library/nginx:latest")
        #expect(!PreviewSamples.sparklineValues.isEmpty)
        #expect(PreviewSamples.createRequest.image == PreviewSamples.image.reference)
    }
}

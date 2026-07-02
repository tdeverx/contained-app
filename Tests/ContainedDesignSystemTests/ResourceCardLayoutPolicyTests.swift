import Testing
@testable import ContainedDesignSystem

@Suite("Resource card layout policy")
struct ResourceCardLayoutPolicyTests {
    @Test func sizeControlsStickyAndEmbeddedCardSlots() {
        #expect(ResourceCardSize.small.keepsFooterSticky == false)
        #expect(ResourceCardSize.small.embedsFooterInBody == true)
        #expect(ResourceCardSize.small.keepsWidgetSticky == false)
        #expect(ResourceCardSize.small.embedsWidgetInBody == false)

        #expect(ResourceCardSize.medium.keepsFooterSticky == true)
        #expect(ResourceCardSize.medium.embedsFooterInBody == false)
        #expect(ResourceCardSize.medium.keepsWidgetSticky == false)
        #expect(ResourceCardSize.medium.embedsWidgetInBody == true)

        #expect(ResourceCardSize.large.keepsFooterSticky == true)
        #expect(ResourceCardSize.large.embedsFooterInBody == false)
        #expect(ResourceCardSize.large.keepsWidgetSticky == true)
        #expect(ResourceCardSize.large.embedsWidgetInBody == false)
    }
}

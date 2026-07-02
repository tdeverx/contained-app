import Testing
@testable import ContainedDesignSystem

@Suite("Design card layout policy")
struct DesignCardLayoutPolicyTests {
    @Test func sizeControlsStickyAndEmbeddedCardSlots() {
        #expect(DesignCardSize.small.keepsFooterSticky == false)
        #expect(DesignCardSize.small.embedsFooterInBody == true)
        #expect(DesignCardSize.small.keepsWidgetSticky == false)
        #expect(DesignCardSize.small.embedsWidgetInBody == false)

        #expect(DesignCardSize.medium.keepsFooterSticky == true)
        #expect(DesignCardSize.medium.embedsFooterInBody == false)
        #expect(DesignCardSize.medium.keepsWidgetSticky == false)
        #expect(DesignCardSize.medium.embedsWidgetInBody == true)

        #expect(DesignCardSize.large.keepsFooterSticky == true)
        #expect(DesignCardSize.large.embedsFooterInBody == false)
        #expect(DesignCardSize.large.keepsWidgetSticky == true)
        #expect(DesignCardSize.large.embedsWidgetInBody == false)
    }
}

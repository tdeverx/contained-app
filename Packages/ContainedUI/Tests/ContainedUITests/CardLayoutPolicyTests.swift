import Testing
@testable import ContainedUI

@Suite("Card layout layout policy")
struct CardLayoutPolicyTests {
    @Test func sizeControlsStickyAndEmbeddedCardSlots() {
        #expect(UI.Card.Size.small.keepsFooterSticky == false)
        #expect(UI.Card.Size.small.embedsFooterInBody == true)
        #expect(UI.Card.Size.small.keepsWidgetSticky == false)
        #expect(UI.Card.Size.small.embedsWidgetInBody == false)

        #expect(UI.Card.Size.medium.keepsFooterSticky == true)
        #expect(UI.Card.Size.medium.embedsFooterInBody == false)
        #expect(UI.Card.Size.medium.keepsWidgetSticky == false)
        #expect(UI.Card.Size.medium.embedsWidgetInBody == true)

        #expect(UI.Card.Size.large.keepsFooterSticky == true)
        #expect(UI.Card.Size.large.embedsFooterInBody == false)
        #expect(UI.Card.Size.large.keepsWidgetSticky == true)
        #expect(UI.Card.Size.large.embedsWidgetInBody == false)
    }

    @Test func contentSizingDeclaresExpandedHeightPolicy() {
        #expect(UI.Card.ContentSizing.fill.fillsAvailableHeight)
        #expect(!UI.Card.ContentSizing.hug.fillsAvailableHeight)
    }
}

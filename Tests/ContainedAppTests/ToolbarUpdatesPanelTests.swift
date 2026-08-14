import Testing
@testable import ContainedApp

@Suite("Images panel pages")
struct ToolbarUpdatesPanelTests {
    @Test func defaultsToUpdatesOnlyWhenUpdatesAreAvailable() {
        #expect(ToolbarUpdatesPanel.ImagePage.defaultPage(updateCount: 1) == .updates)
        #expect(ToolbarUpdatesPanel.ImagePage.defaultPage(updateCount: 0) == .images)
    }
}

import Testing
import ContainedCore
import ContainedCoreFixtures
import ContainedUI
@testable import ContainedApp

@Suite("Preview fixture mappings")
struct PreviewFixtureMappingTests {
    @Test func coreFixturesCanFeedAppOwnedPresentationState() {
        let snapshot = Core.Fixtures.AppleContainer.webContainer
        let style = Personalization.fixture(for: snapshot)

        #expect(style.nickname == snapshot.displayName)
        #expect(style.icon == "shippingbox.fill")
        #expect(style.widgets.map(\.metric) == [.cpu, .memory])
    }
}

private extension Personalization {
    static func fixture(for snapshot: Core.Container.Snapshot) -> Personalization {
        var style = Personalization()
        style.nickname = snapshot.displayName
        style.icon = "shippingbox.fill"
        style.tint = .blue
        style.fillBackground = true
        style.backgroundOpacity = 0.16
        style.gradient = true
        style.widgets = [
            WidgetConfiguration(metric: .cpu,
                                tint: .blue,
                                icon: "cpu",
                                style: .area,
                                showText: true),
            WidgetConfiguration(metric: .memory,
                                tint: .teal,
                                icon: "memorychip",
                                style: .area,
                                showText: true),
        ]
        return style
    }
}

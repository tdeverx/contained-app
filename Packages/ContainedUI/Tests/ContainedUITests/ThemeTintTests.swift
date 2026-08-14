import Foundation
import Testing
@testable import ContainedUI

@Suite("Theme tint")
struct ThemeTintTests {
    @Test func presetsMirrorTheStandardSwiftUIColorPalette() {
        #expect(UI.Theme.Tint.allCases.map(\.rawValue) == [
            "multicolor", "gray", "red", "orange", "yellow", "green", "mint", "teal",
            "cyan", "blue", "indigo", "purple", "pink", "brown", "black", "white",
        ])
    }

    @Test func legacyCuratedNamesMigrateToSystemColors() throws {
        #expect(UI.Theme.Tint(rawValue: "graphite") == .gray)
        #expect(UI.Theme.Tint(rawValue: "azure") == .blue)
        #expect(UI.Theme.Tint(rawValue: "coral") == .orange)
        #expect(UI.Theme.Tint(rawValue: "amber") == .yellow)
        #expect(try JSONDecoder().decode(UI.Theme.Tint.self, from: Data("\"azure\"".utf8)) == .blue)
    }

    @Test func customHexNormalizesAndRoundTrips() throws {
        let tint = try #require(UI.Theme.Tint(hex: " 7c3aed "))
        #expect(tint.rawValue == "#7C3AED")
        #expect(tint.isCustom)
        #expect(UI.Theme.Tint(hex: "#12345") == nil)

        let data = try JSONEncoder().encode(tint)
        #expect(try JSONDecoder().decode(UI.Theme.Tint.self, from: data) == tint)
    }
}

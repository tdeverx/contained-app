import Testing
@testable import Contained

@Suite("Palette fuzzy search")
struct PaletteSearchTests {
    @Test func exactAndPrefixBeatFuzzyMatches() {
        let exact = PaletteSearch.score(query: "settings", in: ["settings"]) ?? 0
        let prefix = PaletteSearch.score(query: "sett", in: ["Settings"]) ?? 0
        let fuzzy = PaletteSearch.score(query: "stg", in: ["Settings"]) ?? 0

        #expect(exact > prefix)
        #expect(prefix > fuzzy)
    }

    @Test func fuzzyMatchesInitialsAndSeparatedWords() {
        #expect(PaletteSearch.score(query: "dns", in: ["Default Network Settings"]) != nil)
        #expect(PaletteSearch.score(query: "rcli", in: ["Reveal CLI Previews"]) != nil)
        #expect(PaletteSearch.score(query: "zzzz", in: ["Reveal CLI Previews"]) == nil)
    }

    @Test func keywordsParticipateInScoring() {
        let score = PaletteSearch.score(query: "dockerhub", in: ["Search Docker Hub", "images", "registry pull dockerhub"])
        #expect(score != nil)
    }
}

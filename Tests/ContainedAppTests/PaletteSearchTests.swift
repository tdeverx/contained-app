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

    @Test func scoresFieldsIndependently() {
        let exactKeyword = PaletteSearch.score(query: "dockerhub", in: ["Search Docker Hub", "images", "registry pull dockerhub"]) ?? 0
        let fuzzyTitle = PaletteSearch.score(query: "dockerhub", in: ["Search Docker Hub", "images"]) ?? 0

        #expect(exactKeyword > fuzzyTitle)
    }

    @Test func wordInitialsMatchCommonPaletteQueries() {
        #expect(PaletteSearch.score(query: "dh", in: ["Search Docker Hub"]) != nil)
        #expect(PaletteSearch.score(query: "mb", in: ["Show Menu Bar Item"]) != nil)
        #expect(PaletteSearch.score(query: "cli", in: ["Reveal CLI Previews"]) != nil)
        #expect(PaletteSearch.score(query: "d hub", in: ["Search Docker Hub"]) != nil)
    }

    @Test func typoToleranceHandlesSmallSingleWordMistakes() {
        #expect(PaletteSearch.score(query: "settigns", in: ["Settings"]) != nil)
        #expect(PaletteSearch.score(query: "dockre", in: ["Docker"]) != nil)
        #expect(PaletteSearch.score(query: "zzzz", in: ["Settings"]) == nil)
    }

    @Test func rankingKeepsStrongMatchesAboveLooseMatches() {
        let prefix = PaletteSearch.score(query: "set", in: ["Settings"]) ?? 0
        let typo = PaletteSearch.score(query: "settigns", in: ["Settings"]) ?? 0
        let initials = PaletteSearch.score(query: "dh", in: ["Search Docker Hub"]) ?? 0
        let loose = PaletteSearch.score(query: "dh", in: ["Dark theme"]) ?? 0

        #expect(prefix > typo)
        #expect(initials > loose)
    }

    @Test func paletteItemsDeduplicateByDisplayedCommand() {
        let first = PaletteItem(title: "Images", subtitle: "Workloads", kind: .navigation,
                                icon: "square.stack.3d.up", tint: .secondary) {}
        let duplicate = PaletteItem(title: "Images", subtitle: "Workloads", kind: .navigation,
                                    icon: "square.stack.3d.up", tint: .secondary) {}
        let distinct = PaletteItem(title: "Images", subtitle: "Image", kind: .image,
                                   icon: "play.fill", tint: .green) {}

        let deduped = PaletteItem.deduplicated([first, duplicate, distinct])

        #expect(deduped.count == 2)
        #expect(deduped.map(\.kind) == [.navigation, .image])
    }
}

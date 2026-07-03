import SwiftUI
import ContainedUI
import ContainedCore

/// Reusable Docker Hub image search. Before the user types it offers ready-to-run **starters** and a
/// curated list of **popular** images as quick-picks; while typing it debounces and queries Hub, with
/// explicit loading and empty states. Selecting anything yields a prefilled `ContainerFormState` (the starters
/// carry a full recipe; a Hub result or popular image carries just the image reference).
///
/// Used by `CreationFlow` for the image-search entry point. Inline fuzzy matching is separate from
/// this Docker Hub lookup; Hub's own ranking handles typed queries here.
struct RegistryImageSearch: View {
    /// Called with a prefilled spec when the user picks a starter, a popular image, or a search result.
    var initialQuery = ""
    var onSelect: (ContainerFormState) -> Void

    @State private var query = ""
    @State private var appliedInitialQuery = false
    @State private var results: [Core.Registry.HubSearchResult] = []
    @State private var searching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.m) {
            searchField
            if trimmedQuery.isEmpty {
                idleSuggestions
            } else {
                resultsList
            }
        }
        .onAppear(perform: applyInitialQuery)
        .onChange(of: query) { _, _ in scheduleSearch() }
    }

    // MARK: Search field

    private var searchField: some View {
        UI.Control.SearchField(text: $query,
                          prompt: AppText.string("imageSearch.prompt", defaultValue: "Search Docker Hub..."),
                          clearLabel: AppText.clear,
                          isSearching: searching,
                          onSubmit: searchNow)
    }

    // MARK: Idle — starters + popular

    private var idleSuggestions: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.l) {
                suggestionSection("Starters") {
                    ForEach(BuiltinTemplate.all, id: \.name) { item in
                        quickPick(symbol: item.symbol, title: item.name,
                                  subtitle: Format.shortImage(item.spec.image)) {
                            onSelect(item.spec)
                        }
                    }
                }
                suggestionSection("Popular") {
                    ForEach(RecommendedImage.all) { image in
                        quickPick(symbol: image.symbol, title: image.name, subtitle: image.reference) {
                            onSelect(RecommendedImage.spec(for: image.reference))
                        }
                    }
                }
            }
            .padding(.bottom, UI.Layout.Spacing.s)
        }
    }

    private func suggestionSection<C: View>(_ title: String, @ViewBuilder content: @escaping () -> C) -> some View {
        UI.List.Section(title) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: UI.Layout.Spacing.s)],
                      spacing: UI.Layout.Spacing.s) { content() }
        }
    }

    private func quickPick(symbol: String, title: String, subtitle: String,
                           action: @escaping () -> Void) -> some View {
        choiceCard(symbol: symbol, title: title, subtitle: subtitle, action: action) {
            UI.List.RowChevron()
        }
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Results

    @ViewBuilder
    private var resultsList: some View {
        if results.isEmpty {
            if searching {
                UI.State.Loading(AppText.string("imageSearch.searching", defaultValue: "Searching Docker Hub..."))
            } else if let errorMessage {
                VStack(spacing: UI.Layout.Spacing.s) {
                    UI.State.Empty(AppText.string("imageSearch.error.title", defaultValue: "Couldn't search Docker Hub"),
                                     systemImage: "wifi.exclamationmark",
                                     description: errorMessage,
                                     tone: .warning,
                                     padding: UI.Layout.Spacing.s)
                    UI.Action.TextButton(title: AppText.string("common.retry", defaultValue: "Retry"),
                                           systemName: "arrow.clockwise") {
                        searchNow()
                    }
                }
                .padding(UI.Layout.Spacing.xl)
            } else {
                UI.State.Empty(AppText.string("imageSearch.empty", defaultValue: "No images found for \(trimmedQuery)"),
                                 systemImage: "magnifyingglass")
            }
        } else {
            ScrollView {
                LazyVStack(spacing: UI.Layout.Spacing.xs) {
                    ForEach(results) { result in
                        resultRow(result)
                            .accessibilityAddTraits(.isButton)
                    }
                }
            }
        }
    }

    private func resultRow(_ result: Core.Registry.HubSearchResult) -> some View {
        choiceCard(symbol: "shippingbox",
                   title: result.repoName,
                   subtitle: result.shortDescription?.isEmpty == false ? result.shortDescription : nil,
                   action: { onSelect(RecommendedImage.spec(for: result.pullReference)) }) {
            HStack(spacing: UI.Layout.Spacing.s) {
                if result.isOfficial {
                    UI.Symbol.Image(systemName: "checkmark.seal.fill",
                                 tone: .info,
                                 size: .caption2)
                }
                UI.State.InlineStatus("\(result.starCount)", systemImage: "star.fill")
            }
        }
    }

    private func choiceCard<Accessory: View>(symbol: String,
                                             title: String,
                                             subtitle: String?,
                                             action: @escaping () -> Void,
                                             @ViewBuilder accessory: @escaping () -> Accessory) -> some View {
        UI.Card.Scaffold(size: .small,
                     elevated: false,
                     onTap: action,
                     title: title,
                     subtitle: subtitle) {
            UI.Card.IconChip(symbol: symbol, tint: .accentColor)
        } titleAccessory: {
            EmptyView()
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            accessory()
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            EmptyView()
        } footerActions: {
            EmptyView()
        } widget: {
            EmptyView()
        }
        .contentShape(Rectangle())
    }

    // MARK: Search plumbing

    /// Debounce typing, then search. The task owns the network request so cancellation cannot leave
    /// an older query racing to overwrite the newest results.
    private func scheduleSearch() {
        searchTask?.cancel()
        errorMessage = nil
        let current = query
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, current == query else { return }
            await runSearch(current)
        }
    }

    private func searchNow() {
        searchTask?.cancel()
        let current = query
        searchTask = Task { await runSearch(current) }
    }

    private func applyInitialQuery() {
        guard !appliedInitialQuery else { return }
        appliedInitialQuery = true
        let trimmed = initialQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        query = trimmed
    }

    @MainActor
    private func runSearch(_ searchQuery: String) async {
        guard Core.Registry.HubSearch.url(query: searchQuery) != nil else {
            results = []
            searching = false
            errorMessage = nil
            return
        }
        searching = true
        errorMessage = nil
        defer { searching = false }
        do {
            let searchResults = try await Core.Registry.HubSearch.results(query: searchQuery)
            guard !Task.isCancelled, searchQuery == query else { return }
            results = searchResults
        } catch {
            guard !Task.isCancelled, searchQuery == query else { return }
            results = []
            errorMessage = error.appDisplayMessage
        }
    }
}

/// A curated list of popular images surfaced as quick-picks before the user searches. Kept small and
/// hand-picked rather than fetched, since Hub has no simple "most popular" endpoint without a query.
struct RecommendedImage: Identifiable, Hashable {
    let name: String
    let reference: String
    let symbol: String
    var id: String { reference }

    static let all: [RecommendedImage] = [
        .init(name: "Node", reference: "node:lts", symbol: "hexagon"),
        .init(name: "Python", reference: "python:3", symbol: "chevron.left.forwardslash.chevron.right"),
        .init(name: "MySQL", reference: "mysql:8", symbol: "cylinder.split.1x2"),
        .init(name: "MongoDB", reference: "mongo:7", symbol: "leaf"),
        .init(name: "Ubuntu", reference: "ubuntu:24.04", symbol: "circle.grid.cross"),
        .init(name: "Caddy", reference: "caddy:latest", symbol: "lock.shield"),
        .init(name: "RabbitMQ", reference: "rabbitmq:3", symbol: "arrow.triangle.swap"),
        .init(name: "MariaDB", reference: "mariadb:11", symbol: "cylinder.split.1x2"),
    ]

    /// Build a minimal spec that just targets `reference` — the configure form fills in the rest.
    static func spec(for reference: String) -> ContainerFormState {
        var spec = ContainerFormState()
        spec.image = reference
        return spec
    }
}

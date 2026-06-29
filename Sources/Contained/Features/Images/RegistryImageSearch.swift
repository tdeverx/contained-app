import SwiftUI
import ContainedCore

/// Reusable Docker Hub image search. Before the user types it offers ready-to-run **starters** and a
/// curated list of **popular** images as quick-picks; while typing it debounces and queries Hub, with
/// explicit loading and empty states. Selecting anything yields a prefilled `RunSpec` (the starters
/// carry a full recipe; a Hub result or popular image carries just the image reference).
///
/// Used by `CreationFlow` for the image-search entry point. Inline fuzzy matching is separate from
/// this Docker Hub lookup; Hub's own ranking handles typed queries here.
struct RegistryImageSearch: View {
    /// Called with a prefilled spec when the user picks a starter, a popular image, or a search result.
    var onSelect: (RunSpec) -> Void

    @State private var query = ""
    @State private var results: [HubSearchResult] = []
    @State private var searching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            searchField
            if trimmedQuery.isEmpty {
                idleSuggestions
            } else {
                resultsList
            }
        }
        .onChange(of: query) { _, _ in scheduleSearch() }
    }

    // MARK: Search field

    private var searchField: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search Docker Hub…", text: $query)
                .textFieldStyle(.plain)
                .onSubmit { runSearch() }
            if searching { ProgressView().controlSize(.small) }
            else if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.s)
        .glassSurface(.thin, cornerRadius: Tokens.Radius.control)
    }

    // MARK: Idle — starters + popular

    private var idleSuggestions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.l) {
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
            .padding(.bottom, Tokens.Space.s)
        }
    }

    private func suggestionSection<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: Tokens.Space.s)],
                      spacing: Tokens.Space.s) { content() }
        }
    }

    private func quickPick(symbol: String, title: String, subtitle: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            GlassListRow(symbol: symbol, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }

    // MARK: Results

    @ViewBuilder
    private var resultsList: some View {
        if results.isEmpty {
            VStack(spacing: Tokens.Space.s) {
                if searching {
                    ProgressView()
                    Text("Searching Docker Hub…").font(.callout).foregroundStyle(.secondary)
                } else if let errorMessage {
                    Image(systemName: "wifi.exclamationmark").font(.title2).foregroundStyle(.orange)
                    Text("Couldn't search Docker Hub").font(.callout.weight(.medium))
                    Text(errorMessage).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button { runSearch() } label: { Label("Retry", systemImage: "arrow.clockwise") }
                        .buttonStyle(.glass)
                } else {
                    Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(.tertiary)
                    Text("No images found for “\(trimmedQuery)”").font(.callout).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(Tokens.Space.xl)
        } else {
            ScrollView {
                LazyVStack(spacing: Tokens.Space.xs) {
                    ForEach(results) { result in
                        Button { onSelect(RecommendedImage.spec(for: result.pullReference)) } label: {
                            resultRow(result)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func resultRow(_ result: HubSearchResult) -> some View {
        GlassListRow(symbol: "shippingbox",
                     title: result.repoName,
                     subtitle: result.shortDescription?.isEmpty == false ? result.shortDescription : nil,
                     monospacedSubtitle: false) {
            HStack(spacing: Tokens.Space.s) {
                if result.isOfficial {
                    Image(systemName: "checkmark.seal.fill").font(.caption2).foregroundStyle(.blue)
                }
                Label("\(result.starCount)", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    // MARK: Search plumbing

    /// Debounce typing, then search.
    private func scheduleSearch() {
        searchTask?.cancel()
        errorMessage = nil
        let current = query
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, current == query else { return }
            runSearch()
        }
    }

    private func runSearch() {
        guard let url = HubSearch.url(query: query) else {
            results = []
            searching = false
            errorMessage = nil
            return
        }
        searching = true
        errorMessage = nil
        Task {
            defer { searching = false }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    throw URLError(.badServerResponse)
                }
                let decoded = try JSONDecoder().decode(HubSearchResponse.self, from: data)
                if !Task.isCancelled { results = decoded.results }
            } catch {
                if !Task.isCancelled {
                    results = []
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
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
    static func spec(for reference: String) -> RunSpec {
        var spec = RunSpec()
        spec.image = reference
        return spec
    }
}

import SwiftUI
import ContainedNavigation
import ContainedDesignSystem
import SwiftData
import AppKit
import ContainedCore

/// A labelled group of palette rows (a heading + its items). Title is nil for a query's flat ranked
/// list.
private struct PaletteSection: Identifiable {
    let title: String?
    let items: [PaletteItem]
    var id: String { title ?? "__results" }
}

/// A palette row paired with its stable flat index (position in the full result list), so selection
/// highlighting keys off position rather than `PaletteItem.id` (a per-evaluation UUID).
private struct IndexedPaletteRow: Identifiable {
    let index: Int
    let item: PaletteItem
    var id: Int { index }
}

private struct IndexedPaletteSection: Identifiable {
    let id: Int
    let title: String?
    let rows: [IndexedPaletteRow]
}

/// The expanded command palette content hosted inside `MorphingExpander`.
struct ToolbarCommandPalette: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @FocusState private var focused: Bool
    var onClose: () -> Void

    @State private var hubResults: [HubSearchResult] = []
    @State private var hubSearching = false
    @State private var hubError: String?

    private var isOpen: Bool { ui.activeMorph == .palette }
    private var scope: PaletteScope? { ui.paletteScope }
    private var trimmedQuery: String { ui.searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Live `@State` would normally back this, but the section model recomputes cheaply each render.
    private var sections: [PaletteSection] {
        switch scope {
        case .dockerHub:
            return [PaletteSection(title: "Docker Hub", items: PaletteItem.deduplicated(hubItems()))]
        case .localImages:
            return [PaletteSection(title: "Local images", items: PaletteItem.deduplicated(localImageItems()))]
        case nil:
            if trimmedQuery.isEmpty {
                return browseSections()
            }
            return [PaletteSection(title: nil,
                                   items: PaletteItem.deduplicated(PaletteItem.filtered(trimmedQuery,
                                                                                       app: app,
                                                                                       ui: ui)))]
        }
    }

    private var flatItems: [PaletteItem] { sections.flatMap(\.items) }

    private var localImageMatches: Int {
        guard !trimmedQuery.isEmpty else { return app.images.count }
        return app.images.filter {
            PaletteSearch.score(query: trimmedQuery, in: [$0.reference, Format.shortImage($0.reference)]) != nil
        }.count
    }

    /// Key for the inline Docker Hub search task — changes (and so re-runs, debounced) whenever the
    /// scope toggles to/from Docker Hub or the query changes.
    private var hubSearchKey: String { "\(scope == .dockerHub)|\(trimmedQuery)" }

    var body: some View {
        MorphPanelScaffold(width: Tokens.PanelSize.palette.width, scrolls: false) {
            VStack(spacing: 0) {
                VStack(spacing: Tokens.Space.xs) {
                    fieldRow
                .frame(height: Tokens.Toolbar.searchOpenHeaderHeight)
                    inlineSearchRow
                }
                .padding(.bottom, Tokens.Space.s)
                Divider()
            }
        } content: {
            resultsList
        } footer: {
            footerBar
        }
        .morphPanelSize(Tokens.PanelSize.palette)
        .morphPanelPlacement(.anchored)
        .onAppear {
            ui.paletteIndex = 0
        }
        .task(id: isOpen) { await focusSearchField() }
        .task(id: hubSearchKey) { await runHubSearch() }
        .onChange(of: ui.searchText) { _, _ in ui.paletteIndex = 0 }
        .onChange(of: ui.paletteScope) { _, _ in ui.paletteIndex = 0 }
        .onChange(of: flatItems.count) { _, _ in clampSelection() }
    }

    private var fieldRow: some View {
        @Bindable var ui = ui
        return HStack(spacing: Tokens.Toolbar.searchIconGap) {
            Image(systemName: scope?.symbol ?? "magnifyingglass")
                .font(.body)
                .foregroundStyle(scope == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.accentColor))
            if let scope {
                scopeChip(scope)
            }
            TextField(scope?.placeholder ?? "Search or run a command…", text: $ui.searchText)
                .textFieldStyle(.plain)
                .font(.body).fontWeight(.medium)
                .focused($focused)
                .onSubmit { onSubmit() }
                .onKeyPress(.downArrow) { guard isOpen else { return .ignored }; move(1); return .handled }
                .onKeyPress(.upArrow) { guard isOpen else { return .ignored }; move(-1); return .handled }
                .onKeyPress(.escape) { guard isOpen else { return .ignored }; escape(); return .handled }
                // Backspace on an empty field pops the active scope chip (like removing a token).
                .onKeyPress(.delete) {
                    guard isOpen, scope != nil, ui.searchText.isEmpty else { return .ignored }
                    ui.paletteScope = nil
                    return .handled
                }
            if !ui.searchText.isEmpty {
                Button { ui.searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help(AppText.clearSearch).accessibilityLabel(AppText.clearSearch)
            } else {
                Text("esc").font(.caption2).fontWeight(.medium).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, Tokens.Space.l)
    }

    /// The pinned scope token shown in the search field.
    private func scopeChip(_ scope: PaletteScope) -> some View {
        Button { ui.paletteScope = nil } label: {
            DesignScopeChipLabel(symbol: scope.symbol, title: scope.title)
        }
        .buttonStyle(.plain)
        .help("Remove \(scope.title) scope")
        .accessibilityLabel(AppText.removeScopeAccessibility(scope.title))
        .fixedSize()
    }

    private var inlineSearchRow: some View {
        HStack(spacing: Tokens.Space.s) {
            if let scope {
                ResourceBadgeText(text: scopeCountText(scope))
                Spacer()
                Button { ui.paletteScope = nil } label: {
                    Label("Commands", systemImage: "command")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .help("Back to commands")
            } else {
                ResourceBadgeText(text: "\(flatItems.count) match\(flatItems.count == 1 ? "" : "es")")
                ResourceBadgeText(text: "\(localImageMatches) local image\(localImageMatches == 1 ? "" : "s")")
                Spacer()
                if !trimmedQuery.isEmpty {
                    // "Hit search on a search entry" — pins the Docker Hub scope and keeps the typed
                    // query, searching in-place inside the same panel area.
                    Button { ui.paletteScope = .dockerHub } label: {
                        Label("Search Docker Hub", systemImage: "globe")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .help("Search Docker Hub for \(trimmedQuery)")
                }
            }
        }
        .padding(.horizontal, Tokens.Space.l)
    }

    private func scopeCountText(_ scope: PaletteScope) -> String {
        switch scope {
        case .dockerHub:
            if hubSearching { return "Searching…" }
            if hubError != nil { return "Couldn't reach Docker Hub" }
            if trimmedQuery.isEmpty { return "Popular images" }
            let n = hubResults.count
            return "\(n) result\(n == 1 ? "" : "s")"
        case .localImages:
            let n = flatItems.count
            return "\(n) image\(n == 1 ? "" : "s")"
        }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
                    let indexed = indexedSections   // one evaluation → stable positional indices
                    if indexed.isEmpty {
                        emptyState
                    } else {
                        ForEach(indexed) { section in
                            if let title = section.title {
                                sectionHeader(title)
                            }
                            ForEach(section.rows) { row in
                                PaletteResultCard(item: row.item,
                                                  selected: row.index == ui.paletteIndex,
                                                  action: { ui.paletteIndex = row.index; run(row.item) })
                                .id(row.index)
                                .contentShape(Rectangle())
                            }
                        }
                    }
                }
                .padding(Tokens.Space.s)
            }
            .onChange(of: ui.paletteIndex) { _, new in proxy.scrollTo(new, anchor: .center) }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, Tokens.Space.xs)
            .padding(.top, Tokens.Space.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var emptyState: some View {
        if scope == .dockerHub {
            dockerHubPlaceholder
        } else {
            DesignContentSurface(minHeight: 260) {
                ContentUnavailableView {
                    Label("No matches", systemImage: "magnifyingglass")
                } description: {
                    Text("Try a setting, image, container, network, or action.")
                }
            }
        }
    }

    private var dockerHubPlaceholder: some View {
        DesignContentSurface(minHeight: 260) {
            LazyVStack(spacing: Tokens.Space.s) {
                if hubSearching {
                    ProgressView()
                    Text("Searching Docker Hub…").font(.callout).foregroundStyle(.secondary)
                } else if let hubError {
                    Image(systemName: "wifi.exclamationmark").font(.title2).foregroundStyle(.orange)
                    Text("Couldn't search Docker Hub").font(.callout.weight(.medium))
                    Text(hubError).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                } else {
                    Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(.tertiary)
                    Text(trimmedQuery.isEmpty ? "Type to search Docker Hub" : "No images found for “\(trimmedQuery)”")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var footerBar: some View {
        HStack(spacing: Tokens.Space.m) {
            keyboardHint("↑↓", "Select")
            keyboardHint("return", "Run")
            keyboardHint("esc", scope == nil ? "Close" : "Clear scope")
            Spacer()
            if let selected = selectedItem {
                ResourceBadgeText(text: selected.kind.rawValue)
            }
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.vertical, Tokens.Space.s)
    }

    private var selectedItem: PaletteItem? {
        guard flatItems.indices.contains(ui.paletteIndex) else { return nil }
        return flatItems[ui.paletteIndex]
    }

    /// The sections evaluated once with a running flat index per row. Rendering from this (rather than
    /// re-deriving an index from `PaletteItem.id`, which is a fresh UUID per evaluation) guarantees only
    /// the row at `paletteIndex` is highlighted.
    private var indexedSections: [IndexedPaletteSection] {
        var flat = 0
        return sections.enumerated().map { offset, section in
            let rows = section.items.map { item -> IndexedPaletteRow in
                defer { flat += 1 }
                return IndexedPaletteRow(index: flat, item: item)
            }
            return IndexedPaletteSection(id: offset, title: section.title, rows: rows)
        }
    }

    private func keyboardHint(_ key: String, _ label: String) -> some View {
        DesignKeyboardHint(key, label)
    }

    // MARK: Sections

    /// Group the full command set into labelled, ordered sections for the no-query browse view.
    private func browseSections() -> [PaletteSection] {
        let all = PaletteItem.all(app: app, ui: ui)
        let grouped = Dictionary(grouping: all) { $0.kind.section.title }
        let orderByTitle = Dictionary(all.map { ($0.kind.section.title, $0.kind.section.order) },
                                      uniquingKeysWith: { a, _ in a })
        return grouped.keys
            .sorted { (orderByTitle[$0] ?? 0) < (orderByTitle[$1] ?? 0) }
            .map { PaletteSection(title: $0, items: PaletteItem.deduplicated(grouped[$0] ?? [])) }
    }

    private func hubItems() -> [PaletteItem] {
        if trimmedQuery.isEmpty {
            return RecommendedImage.all.map { rec in
                PaletteItem(title: "Run \(rec.name)", subtitle: rec.reference,
                            keywords: [rec.reference], kind: .image,
                            icon: rec.symbol, tint: .accentColor) {
                    ui.runImage(rec.reference, returningTo: .search)
                }
            }
        }
        let query = trimmedQuery
        return hubResults.map { result in
            let subtitle = result.shortDescription?.isEmpty == false
                ? result.shortDescription
                : (result.isOfficial ? "Official image" : "Docker Hub")
            return PaletteItem(title: result.repoName,
                               subtitle: subtitle,
                               keywords: [result.repoName],
                               kind: .image,
                               icon: result.isOfficial ? "checkmark.seal.fill" : "shippingbox",
                               tint: .accentColor) {
                ui.runImage(result.pullReference, returningTo: .search, searchQuery: query)
            }
        }
    }

    private func localImageItems() -> [PaletteItem] {
        let groups = app.localImageGroups()
        let matched = trimmedQuery.isEmpty ? groups : groups.filter {
            PaletteSearch.score(query: trimmedQuery, in: $0.references + [Format.shortImage($0.primaryReference)]) != nil
        }
        return matched.map { group in
            PaletteItem(title: "Run \(Format.shortImage(group.primaryReference))",
                        subtitle: "\(group.references.count) tag\(group.references.count == 1 ? "" : "s")",
                        keywords: group.references,
                        kind: .image,
                        visual: .imageGroup(group),
                        icon: "play.fill", tint: .green) {
                ui.runImage(group.primaryReference, returningTo: .chooser)
            }
        }
    }

    // MARK: Behavior

    private func onSubmit() {
        runSelected()
    }

    private func move(_ delta: Int) {
        guard !flatItems.isEmpty else { return }
        ui.paletteIndex = min(max(0, ui.paletteIndex + delta), flatItems.count - 1)
    }

    private func clampSelection() {
        if flatItems.isEmpty {
            ui.paletteIndex = 0
        } else {
            ui.paletteIndex = min(max(0, ui.paletteIndex), flatItems.count - 1)
        }
    }

    private func runSelected() {
        guard flatItems.indices.contains(ui.paletteIndex) else { return }
        run(flatItems[ui.paletteIndex])
    }

    private func run(_ item: PaletteItem) {
        if !item.keepsPaletteOpen { close() }
        item.action()
    }

    /// Escape pops the scope first (one level), then closes the palette.
    private func escape() {
        if scope != nil {
            ui.paletteScope = nil
        } else {
            close()
        }
    }

    private func close() {
        ui.paletteScope = nil
        onClose()
    }

    /// Debounced inline Docker Hub search, driven by `hubSearchKey`. Cancels automatically when the
    /// key changes (scope toggled or query edited).
    @MainActor
    private func runHubSearch() async {
        guard scope == .dockerHub, !trimmedQuery.isEmpty else {
            hubResults = []; hubSearching = false; hubError = nil
            return
        }
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        hubSearching = true
        hubError = nil
        defer { hubSearching = false }
        do {
            let results = try await HubSearch.results(query: trimmedQuery)
            guard !Task.isCancelled else { return }
            hubResults = results
        } catch {
            guard !Task.isCancelled else { return }
            hubResults = []
            hubError = error.appDisplayMessage
        }
    }

    @MainActor
    private func focusSearchField() async {
        guard isOpen else { return }
        focused = true
        await Task.yield()
        focused = true
        try? await Task.sleep(nanoseconds: 120_000_000)
        if isOpen {
            focused = true
        }
    }
}

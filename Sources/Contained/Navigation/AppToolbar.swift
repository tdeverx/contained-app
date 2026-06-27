import SwiftUI

/// The app-wide, custom (non-native) toolbar that lives in the title-bar band of the hidden-title-bar
/// window. Three compact glass groups — add menu (leading), search + command palette (center),
/// updates + notifications (trailing) — stay **constant across pages** (high-level, not per-section).
///
/// Mounted as a top overlay over the **detail column** in `RootView` (never over the sidebar): the
/// band sits in the title-bar region, the rest of the area is hit-transparent until a control opens.
/// The add `+` grows a `MorphingExpander` panel from its slot; the center search field is a single
/// item that expands *in place* into the command palette (one field, no separate panel). Control
/// sizing comes from `Tokens.Toolbar` / `ToolbarControls`.
struct AppToolbar: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.appSafeAreas) private var safeAreas

    @State private var slots: [UIState.ToolbarMorph: CGRect] = [:]
    @State private var addSoftDismiss: (() -> Void)?

    static let space = "appToolbar"
    /// Title-bar band height. The toolbar lives in the detail column (no traffic lights there), so the
    /// leading inset is just normal padding. Sourced from `Tokens.Toolbar` so the band, the safe-area
    /// manager, and the controls all agree.
    static let bandHeight: CGFloat = Tokens.Toolbar.band

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                toolbarRow
                    .frame(height: Tokens.Toolbar.controlHeight)
                    .padding(.top, rowTopInset)   // centered on the traffic-light line
                Spacer(minLength: 0)            // empty + hit-transparent below the band
                    .allowsHitTesting(false)
            }
            addMorphLayer
            // The center search/command-palette is a single element that expands in place; it lives in
            // its own full-area layer so its open state can float over the page with a backdrop.
            ToolbarCommandPalette(insets: morphTargetInsets)
        }
        .coordinateSpace(.named(Self.space))
        .onPreferenceChange(ToolbarSlotKey.self) { slots = $0 }
    }

    // MARK: Row

    private var toolbarRow: some View {
        HStack(spacing: Tokens.Toolbar.groupSpacing) {
            leadingZone
            Spacer(minLength: Tokens.Space.m)
            toolbarGroup { trailingZone }
        }
        .padding(.horizontal, Tokens.Toolbar.outerPadding)
        .frame(maxWidth: .infinity)
    }

    // The add control is a standalone circle (single action); the trailing updates/notifications are a
    // grouped capsule.
    private var leadingZone: some View {
        ToolbarIconButton(systemName: "plus", help: "Add") { ui.toggleMorph(.add) }
            .frame(width: Tokens.Toolbar.controlHeight, height: Tokens.Toolbar.controlHeight)
            .glassEffect(.regular.interactive(), in: Circle())
            .opacity(ui.activeMorph == .add ? 0 : 1)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ToolbarSlotKey.self,
                                           value: [.add: proxy.frame(in: .named(Self.space))])
                }
            )
    }

    private var trailingZone: some View {
        HStack(spacing: Tokens.Toolbar.groupSpacing) {
            // Placeholder surfaces — wired in a later pass (updates → #10 Phase 6, notifications later).
            ToolbarIconButton(systemName: "arrow.down.circle", help: "Updates (coming soon)") {}
                .disabled(true).opacity(0.45)
            ToolbarIconButton(systemName: "bell", help: "Notifications (coming soon)") {}
                .disabled(true).opacity(0.45)
        }
    }

    /// A grouped capsule of related buttons (e.g. updates + notifications).
    private func toolbarGroup<C: View>(@ViewBuilder content: () -> C) -> some View {
        HStack(spacing: Tokens.Toolbar.groupSpacing) { content() }
            .padding(.horizontal, Tokens.Toolbar.groupPaddingH)
            .frame(height: Tokens.Toolbar.controlHeight)
            .toolbarControlGlass()
    }

    // MARK: Add morph layer

    @ViewBuilder
    private var addMorphLayer: some View {
        if ui.activeMorph == .add {
            MorphingExpander(isPresented: addMorphBinding, originFrame: slots[.add] ?? .zero,
                             panelSize: CGSize(width: 440, height: 300),   // initial; flow resizes per page
                             placement: .anchored,
                             targetInsets: morphTargetInsets,
                             onBackdropTap: addSoftDismiss) {
                CreationFlow(start: .menu,
                             onClose: {
                                 addSoftDismiss = nil
                                 ui.activeMorph = nil
                             },
                             onSoftDismissChange: { addSoftDismiss = $0 })
            }
        }
    }

    private var addMorphBinding: Binding<Bool> {
        Binding(get: { ui.activeMorph == .add }, set: {
            if !$0 { addSoftDismiss = nil; ui.activeMorph = nil }
        })
    }

    private var morphTargetInsets: EdgeInsets {
        safeAreas.morphInsets(.includingToolbar)
    }

    private var rowTopInset: CGFloat { Tokens.Toolbar.topPadding }
}

/// The toolbar's center element: a single search field that filters the current page live
/// (`ui.searchText`) and **expands in place** into the full command palette (it doesn't hide behind a
/// separate panel — the same field stays as the header, the results list drops below it). Opens on ⌘K,
/// on submit, or automatically when an in-page search comes up empty.
private struct ToolbarCommandPalette: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @FocusState private var focused: Bool
    let insets: EdgeInsets

    private var isOpen: Bool { ui.activeMorph == .palette }
    private var items: [PaletteItem] { PaletteItem.filtered(ui.searchText, app: app, ui: ui) }
    private var spring: Animation { .spring(response: 0.42, dampingFraction: 0.86) }

    /// Visual open state, animated explicitly off `isOpen` so the grow plays for every trigger
    /// (⌘K, submit, escalation) — implicit `.animation(value:)` wasn't firing for the size change.
    @State private var expanded = false

    private let collapsedWidth: CGFloat = Tokens.Toolbar.searchMaxWidth
    private let openWidth: CGFloat = 560
    private let openHeightCap: CGFloat = 480
    private var topInset: CGFloat { Tokens.Toolbar.topPadding }

    var body: some View {
        GeometryReader { geo in
            let openHeight = max(Tokens.Toolbar.controlHeight,
                                 min(openHeightCap, geo.size.height - topInset - insets.bottom))
            ZStack(alignment: .top) {
                if expanded {
                    Rectangle()
                        .fill(.black.opacity(0.28))
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { close() }
                        .transition(.opacity)
                }
                panel(openHeight: openHeight)
                    .frame(maxWidth: .infinity, alignment: .top)   // centered in the detail area
            }
        }
        .onChange(of: ui.searchText) { _, _ in escalateIfEmpty() }
        .onChange(of: ui.pageResultCount) { _, _ in escalateIfEmpty() }
        .onChange(of: isOpen) { _, open in
            if open { ui.paletteIndex = 0 }
            focused = open
            withAnimation(spring) { expanded = open }
        }
        // ⌘S focuses the page-search field (without opening the palette).
        .onChange(of: ui.searchFocusToken) { _, _ in focused = true }
    }

    private func panel(openHeight: CGFloat) -> some View {
        // Drive visuals off `expanded` (animated), keeping the list mounted but faded + clipped when
        // collapsed so the height interpolates smoothly instead of the content popping in/out.
        let radius = expanded ? Tokens.Radius.sheet : Tokens.Toolbar.controlHeight / 2
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return VStack(spacing: 0) {
            fieldRow
                .frame(height: expanded ? Tokens.Toolbar.searchOpenHeaderHeight : Tokens.Toolbar.controlHeight)
            Divider().opacity(expanded ? 0.5 : 0)
            resultsList.opacity(expanded ? 1 : 0)
        }
        .frame(width: expanded ? openWidth : collapsedWidth,
               height: expanded ? openHeight : Tokens.Toolbar.controlHeight,
               alignment: .top)
        // Same surface as the add-button morph (floatingPanelMaterial: shadow .24/24/12, border .18) so
        // both toolbar morphs read as the one gesture.
        .background { Color.clear.glassEffect(.regular.interactive(), in: shape) }
        .clipShape(shape)
        .overlay { if expanded { shape.strokeBorder(.white.opacity(0.18), lineWidth: 1) } }
        .shadow(color: .black.opacity(expanded ? 0.24 : 0), radius: expanded ? 24 : 0, y: expanded ? 12 : 0)
        .padding(.top, topInset)
    }

    private var fieldRow: some View {
        @Bindable var ui = ui
        return HStack(spacing: Tokens.Toolbar.searchIconGap) {
            Image(systemName: "magnifyingglass")
                .font(.body)                       // scales with the field text (Dynamic Type), like the buttons
                .foregroundStyle(.secondary)
            TextField(isOpen ? "Search or run a command…" : "Search this page, or ⌘K for commands",
                      text: $ui.searchText)
                .textFieldStyle(.plain)
                .font(.body).fontWeight(.medium)   // 13pt medium on macOS, Dynamic-Type scalable
                .focused($focused)
                .onSubmit { onSubmit() }
                .onKeyPress(.downArrow) { guard isOpen else { return .ignored }; move(1); return .handled }
                .onKeyPress(.upArrow) { guard isOpen else { return .ignored }; move(-1); return .handled }
                .onKeyPress(.escape) { guard isOpen else { return .ignored }; close(); return .handled }
            if !ui.searchText.isEmpty {
                Button { ui.searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("Clear search").accessibilityLabel("Clear search")
            } else {
                Text(isOpen ? "esc" : "⌘K").font(.caption2).fontWeight(.medium).foregroundStyle(.tertiary)
            }
        }
        // Roomier horizontal inset once expanded so the field breathes inside the larger panel.
        .padding(.horizontal, expanded ? Tokens.Space.l : Tokens.Toolbar.searchInnerPadding)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        row(item, selected: index == ui.paletteIndex)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture { run(item) }
                    }
                }
                .padding(.horizontal, Tokens.Space.m)   // roomier results gutter, matched to the open field
                .padding(.vertical, Tokens.Space.s)
            }
            .onChange(of: ui.paletteIndex) { _, new in proxy.scrollTo(new, anchor: .center) }
        }
    }

    private func row(_ item: PaletteItem, selected: Bool) -> some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: item.icon).foregroundStyle(item.tint).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                if let subtitle = item.subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if selected { Image(systemName: "return").font(.caption).foregroundStyle(.tertiary) }
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Behavior

    private func onSubmit() {
        if isOpen { runSelected() } else { ui.toggleMorph(.palette) }
    }

    /// Escalate an in-page search into the palette when a query (≥2 chars) finds nothing on a page that
    /// reports a count. Guards on `activeMorph == nil` so it only escalates once.
    private func escalateIfEmpty() {
        guard ui.activeMorph == nil else { return }
        let q = ui.searchText.trimmingCharacters(in: .whitespaces)
        if q.count >= 2, ui.pageResultCount == 0 { ui.activeMorph = .palette }
    }

    private func move(_ delta: Int) {
        guard !items.isEmpty else { return }
        ui.paletteIndex = min(max(0, ui.paletteIndex + delta), items.count - 1)
    }

    private func runSelected() {
        guard items.indices.contains(ui.paletteIndex) else { return }
        run(items[ui.paletteIndex])
    }

    private func run(_ item: PaletteItem) {
        close()
        item.action()
    }

    private func close() {
        ui.activeMorph = nil
        ui.searchText = ""
    }
}

/// Collects toolbar button slot frames (in the toolbar coordinate space) so a morph can grow from the
/// exact button that opened it.
private struct ToolbarSlotKey: PreferenceKey {
    static let defaultValue: [UIState.ToolbarMorph: CGRect] = [:]
    static func reduce(value: inout [UIState.ToolbarMorph: CGRect],
                       nextValue: () -> [UIState.ToolbarMorph: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

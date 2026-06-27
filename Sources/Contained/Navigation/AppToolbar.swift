import SwiftUI

/// The app-wide, custom (non-native) toolbar that lives in the title-bar band of the hidden-title-bar
/// window. Three compact glass groups — add menu (leading), search + command palette (center),
/// updates + notifications (trailing) — stay **constant across pages** (high-level, not per-section).
///
/// Mounted as a window-spanning top overlay in `RootView`: the band sits at the top, the rest of the
/// area is hit-transparent until a button morphs open, at which point `MorphingExpander` grows a
/// centered panel from that button's slot (the same grow the container cards use).
struct AppToolbar: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.appSafeAreas) private var safeAreas

    @State private var slots: [UIState.ToolbarMorph: CGRect] = [:]
    @State private var addSoftDismiss: (() -> Void)?

    static let space = "appToolbar"
    /// Title-bar band height. The toolbar lives in the detail column (no traffic lights there), so the
    /// leading inset is just normal padding.
    static let bandHeight: CGFloat = 48

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                toolbarRow
                    .frame(height: Self.bandHeight)
                Spacer(minLength: 0)            // empty + hit-transparent below the band
                    .allowsHitTesting(false)
            }
            morphLayer
        }
        .coordinateSpace(.named(Self.space))
        .onPreferenceChange(ToolbarSlotKey.self) { slots = $0 }
    }

    // MARK: Row

    private var toolbarRow: some View {
        HStack(spacing: Tokens.Space.s) {
            leadingZone
            Spacer(minLength: Tokens.Space.m)
            centerZone
            Spacer(minLength: Tokens.Space.m)
            toolbarGroup { trailingZone }
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.top, 4)
        .frame(maxWidth: .infinity)
    }

    private var leadingZone: some View {
        toolbarGroup(slot: .add) {
            toolbarIcon(systemName: "plus", help: "Add") { ui.toggleMorph(.add) }
        }
    }

    private var centerZone: some View {
        ToolbarSearchField()
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ToolbarSlotKey.self,
                                           value: [.palette: proxy.frame(in: .named(Self.space))])
                }
            )
    }

    private var trailingZone: some View {
        HStack(spacing: 2) {
            // Placeholder surfaces — wired in a later pass (updates → #10 Phase 6, notifications later).
            toolbarIcon(systemName: "arrow.down.circle", help: "Updates (coming soon)") {}
                .disabled(true).opacity(0.45)
            toolbarIcon(systemName: "bell", help: "Notifications (coming soon)") {}
                .disabled(true).opacity(0.45)
        }
    }

    private func toolbarGroup<C: View>(slot: UIState.ToolbarMorph? = nil,
                                       @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 2) { content() }
            .padding(4)
            .glassSurface(.thin, cornerRadius: 18, glass: .regular)
            .opacity(slot == ui.activeMorph ? 0 : 1)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ToolbarSlotKey.self,
                        value: slot.map { [$0: proxy.frame(in: .named(Self.space))] } ?? [:]
                    )
                }
            )
    }

    private func toolbarIcon(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 26, height: 26)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .help(help)
        .accessibilityLabel(help)
    }

    // MARK: Morph layer

    @ViewBuilder
    private var morphLayer: some View {
        if let morph = ui.activeMorph {
            MorphingExpander(isPresented: morphBinding, originFrame: slots[morph] ?? .zero,
                             panelSize: panelSize(morph),
                             placement: morph == .add ? .anchored : .centered,
                             targetInsets: morphTargetInsets,
                             onBackdropTap: morph == .add ? addSoftDismiss : nil) {
                panel(morph)
            }
        }
    }

    private var morphBinding: Binding<Bool> {
        Binding(get: { ui.activeMorph != nil }, set: {
            if !$0 {
                if ui.activeMorph == .palette { ui.searchText = "" }
                if ui.activeMorph == .add { addSoftDismiss = nil }
                ui.activeMorph = nil
            }
        })
    }

    private func panelSize(_ morph: UIState.ToolbarMorph) -> CGSize {
        switch morph {
        case .add:     return CGSize(width: 440, height: 300)   // initial; the flow resizes per page
        case .palette: return CGSize(width: 560, height: 480)
        }
    }

    private var morphTargetInsets: EdgeInsets {
        safeAreas.morphInsets(.includingToolbar)
    }

    @ViewBuilder
    private func panel(_ morph: UIState.ToolbarMorph) -> some View {
        switch morph {
        case .add:
            CreationFlow(start: .menu,
                         onClose: {
                             addSoftDismiss = nil
                             ui.activeMorph = nil
                         },
                         onSoftDismissChange: { addSoftDismiss = $0 })
        case .palette:
            CommandPalette(onClose: {
                ui.activeMorph = nil
                ui.searchText = ""
            })
        }
    }
}

/// The toolbar's center field: an in-window page search that filters the current section live
/// (`ui.searchText`). When a query comes up empty on the page it escalates into the full command
/// palette (the same panel ⌘K opens), carrying the typed text over.
private struct ToolbarSearchField: View {
    @Environment(UIState.self) private var ui
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var ui = ui
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.secondary)
            TextField("Search this page, or ⌘K for commands", text: $ui.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($focused)
                .onSubmit { ui.toggleMorph(.palette) }
            if !ui.searchText.isEmpty {
                Button { ui.searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            } else {
                Text("⌘K").font(.system(size: 10, weight: .medium)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .frame(maxWidth: 330)
        .glassSurface(.thin, cornerRadius: 15, glass: .regular)
        .opacity(ui.activeMorph == .palette ? 0 : 1)
        .onChange(of: ui.searchText) { _, _ in escalateIfEmpty() }
        .onChange(of: ui.pageResultCount) { _, _ in escalateIfEmpty() }
    }

    /// Morph into the command palette when an in-page search (≥2 chars) finds nothing on a page that
    /// reports a count. Guards on `activeMorph == nil` so it only escalates once.
    private func escalateIfEmpty() {
        guard ui.activeMorph == nil else { return }
        let q = ui.searchText.trimmingCharacters(in: .whitespaces)
        if q.count >= 2, ui.pageResultCount == 0 {
            ui.activeMorph = .palette
        }
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

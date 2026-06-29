import SwiftUI
import SwiftData
import AppKit
import ContainedCore

struct ToolbarSearchSource: View {
    @Environment(UIState.self) private var ui
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var ui = ui
        return GlassButton(singleItem: true) {
            GlassButtonInputItem {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .foregroundStyle(.secondary)
                TextField("Search this page, or ⌘K for commands", text: $ui.searchText)
                    .textFieldStyle(.plain)
                    .font(.body).fontWeight(.medium)
                    .focused($focused)
                    .onSubmit { ui.activeMorph = .palette }
                if !ui.searchText.isEmpty {
                    Button { ui.searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Clear search")
                        .accessibilityLabel("Clear search")
                } else {
                    Text("⌘K")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .contentShape(Capsule(style: .continuous))
        .simultaneousGesture(TapGesture().onEnded { focused = true })
        .onChange(of: ui.searchText) { _, _ in escalateIfEmpty() }
        .onChange(of: ui.pageResultCount) { _, _ in escalateIfEmpty() }
        .onChange(of: ui.searchFocusToken) { _, _ in focused = true }
        .onChange(of: ui.activeMorph) { _, morph in
            if morph != nil { focused = false }
        }
        .onExitCommand { focused = false }
        .onKeyPress(.escape) {
            focused = false
            return .handled
        }
    }

    private func escalateIfEmpty() {
        guard ui.activeMorph == nil else { return }
        let query = ui.searchText.trimmingCharacters(in: .whitespaces)
        if query.count >= 2, ui.pageResultCount == 0 {
            ui.activeMorph = .palette
        }
    }
}

/// The expanded command palette content hosted inside `MorphingExpander`.
struct ToolbarCommandPalette: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @FocusState private var focused: Bool
    var onClose: () -> Void

    private var isOpen: Bool { ui.activeMorph == .palette }
    private var items: [PaletteItem] { PaletteItem.filtered(ui.searchText, app: app, ui: ui) }

    var body: some View {
        VStack(spacing: 0) {
            fieldRow
                .frame(height: Tokens.Toolbar.searchOpenHeaderHeight)
            Divider().opacity(0.5)
            resultsList
        }
        .morphPanelSize(Tokens.PanelSize.palette)
        .morphPanelPlacement(.anchored)
        .onAppear {
            ui.paletteIndex = 0
            focused = true
        }
    }

    private var fieldRow: some View {
        @Bindable var ui = ui
        return HStack(spacing: Tokens.Toolbar.searchIconGap) {
            Image(systemName: "magnifyingglass")
                .font(.body)                       // scales with the field text (Dynamic Type), like the buttons
                .foregroundStyle(.secondary)
            TextField("Search or run a command…", text: $ui.searchText)
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
                Text("esc").font(.caption2).fontWeight(.medium).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, Tokens.Space.l)
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
        runSelected()
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
        onClose()
    }
}

/// Collects toolbar button slot frames (in the toolbar coordinate space) so a morph can grow from the
/// exact button that opened it.

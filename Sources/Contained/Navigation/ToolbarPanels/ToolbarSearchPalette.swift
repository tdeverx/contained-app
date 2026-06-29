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
        MorphPanelScaffold(width: Tokens.PanelSize.palette.width, scrolls: false) {
            VStack(spacing: 0) {
                PanelHeader(symbol: "command",
                            title: "Command Palette",
                            subtitle: "\(items.count) match\(items.count == 1 ? "" : "es")") {
                    GlassButton(singleItem: true) {
                        GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true, action: close)
                    }
                }
                fieldRow
                    .frame(height: Tokens.Toolbar.searchOpenHeaderHeight)
                Divider().opacity(0.5)
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
            focused = true
        }
        .onChange(of: ui.searchText) { _, _ in ui.paletteIndex = 0 }
        .onChange(of: items.count) { _, _ in clampSelection() }
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
                LazyVStack(spacing: Tokens.Space.s) {
                    if items.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            PaletteResultCard(item: item,
                                              selected: index == ui.paletteIndex,
                                              action: { ui.paletteIndex = index; run(item) })
                            .id(index)
                            .contentShape(Rectangle())
                        }
                    }
                }
                .padding(Tokens.Space.m)
            }
            .onChange(of: ui.paletteIndex) { _, new in proxy.scrollTo(new, anchor: .center) }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No matches", systemImage: "magnifyingglass")
        } description: {
            Text("Try a setting, image, container, network, or action.")
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .glassSurface(.regular, cornerRadius: Tokens.Radius.card, shadow: false)
    }

    private var footerBar: some View {
        HStack(spacing: Tokens.Space.m) {
            keyboardHint("↑↓", "Select")
            keyboardHint("return", "Run")
            keyboardHint("esc", "Close")
            Spacer()
            if let selected = selectedItem {
                ResourceBadgeText(text: selected.kind.rawValue)
            }
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.vertical, Tokens.Space.s)
    }

    private var selectedItem: PaletteItem? {
        guard items.indices.contains(ui.paletteIndex) else { return nil }
        return items[ui.paletteIndex]
    }

    private func keyboardHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: Tokens.Space.xs) {
            Text(key)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Behavior

    private func onSubmit() {
        runSelected()
    }

    private func move(_ delta: Int) {
        guard !items.isEmpty else { return }
        ui.paletteIndex = min(max(0, ui.paletteIndex + delta), items.count - 1)
    }

    private func clampSelection() {
        if items.isEmpty {
            ui.paletteIndex = 0
        } else {
            ui.paletteIndex = min(max(0, ui.paletteIndex), items.count - 1)
        }
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

private struct PaletteResultCard: View {
    let item: PaletteItem
    let selected: Bool
    var action: () -> Void

    var body: some View {
        ResourceGlassCard(size: .small,
                          isSelected: selected,
                          fill: selected ? Color.accentColor : nil,
                          fillOpacity: selected ? 0.10 : 0.18,
                          elevated: false,
                          onTap: action) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: item.icon, tint: item.tint, backgroundOpacity: selected ? 0.24 : 0.16)
            } content: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Tokens.Space.s) {
                        ResourceCardTitleText(text: item.title)
                        ResourceBadgeText(text: item.kind.rawValue,
                                          font: .caption2.weight(.semibold),
                                          foreground: selected ? .accentColor : .secondary)
                    }
                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        ResourceCardSubtitleText(text: subtitle)
                    }
                }
            } trailing: {
                accessory
            }
        } footerLeading: {
            EmptyView()
        } footerActions: {
            EmptyView()
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var accessory: some View {
        switch item.accessory {
        case .run:
            if selected {
                Image(systemName: "return")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
            } else {
                GlassListRowChevron()
                    .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
            }
        case .toggle(let isOn, let set):
            Toggle("", isOn: Binding {
                isOn()
            } set: { newValue in
                set(newValue)
            })
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

/// Collects toolbar button slot frames (in the toolbar coordinate space) so a morph can grow from the
/// exact button that opened it.

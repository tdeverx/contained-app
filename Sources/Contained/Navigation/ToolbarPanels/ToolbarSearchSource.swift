import SwiftUI
import ContainedDesignSystem

struct ToolbarSearchSource: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @FocusState private var focused: Bool

    /// The toolbar search field escalates into the command palette only when that experimental
    /// feature is enabled; otherwise it stays a plain page filter.
    private var paletteEnabled: Bool { app.settings.commandPaletteEnabled && ui.panelNavigationEnabled }

    var body: some View {
        @Bindable var ui = ui
        return GlassButton(singleItem: true) {
            GlassButtonInputItem {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .foregroundStyle(.secondary)
                TextField(paletteEnabled ? "Search this page, or ⌘K for commands" : "Search this page",
                          text: $ui.searchText)
                    .textFieldStyle(.plain)
                    .font(.body).fontWeight(.medium)
                    .focused($focused)
                    .onSubmit { if paletteEnabled { ui.activeMorph = .palette } }
                if !ui.searchText.isEmpty {
                    Button { ui.searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Clear search")
                        .accessibilityLabel("Clear search")
                } else if paletteEnabled {
                    Text("⌘K")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .toolbarControlContentShape()
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
        guard paletteEnabled, ui.activeMorph == nil else { return }
        let query = ui.searchText.trimmingCharacters(in: .whitespaces)
        if query.count >= 2, ui.pageResultCount == 0 {
            ui.activeMorph = .palette
        }
    }
}

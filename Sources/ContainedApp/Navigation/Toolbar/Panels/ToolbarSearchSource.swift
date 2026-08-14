import SwiftUI
import ContainedUI

struct ToolbarSearchSource: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @FocusState private var focused: Bool

    /// The toolbar search field escalates into the command palette only when that experimental
    /// feature is enabled; otherwise it stays a plain page filter.
    private var paletteEnabled: Bool { app.settings.commandPaletteEnabled }

    var body: some View {
        @Bindable var ui = ui
        return UI.Toolbar.SearchField(text: $ui.search.text,
                                        prompt: paletteEnabled
                                            ? "Search this page, or ⌘K for commands"
                                            : "Search this page",
                                        clearSearchLabel: AppText.clearSearch,
                                        focused: $focused,
                                        onSubmit: { if paletteEnabled { ui.toolbar.activeMorph = .palette } },
                                        onClear: { ui.search.text = "" }) {
            if paletteEnabled {
                UI.Control.KeyCap("⌘K")
            }
        }
        .onChange(of: ui.search.text) { _, _ in escalateIfEmpty() }
        .onChange(of: ui.search.pageResultCount) { _, _ in escalateIfEmpty() }
        .onChange(of: ui.search.focusToken) { _, _ in focused = true }
        .onChange(of: ui.toolbar.activeMorph) { _, morph in
            if morph != nil { focused = false }
        }
        .onExitCommand { focused = false }
        .onKeyPress(.escape) {
            focused = false
            return .handled
        }
    }

    private func escalateIfEmpty() {
        guard paletteEnabled, ui.toolbar.activeMorph == nil else { return }
        let query = ui.search.text.trimmingCharacters(in: .whitespaces)
        if query.count >= 2, ui.search.pageResultCount == 0 {
            ui.toolbar.activeMorph = .palette
        }
    }
}

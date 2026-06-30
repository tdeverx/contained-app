import SwiftUI

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

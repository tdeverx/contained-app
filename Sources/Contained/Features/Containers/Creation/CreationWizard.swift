import SwiftUI

/// Sheet host for the creation flow — the entry point used away from the toolbar (empty state,
/// File ▸ New, ⌘K, menu bar). It presents the same paged `CreationFlow` the toolbar `+` shows, just in
/// a fixed-size modal instead of a resizing morph panel. Starts at the chooser (the toolbar's add
/// menu — Container/Network/Volume — is the toolbar-only entry that precedes it).
struct CreationWizard: View {
    @Environment(\.dismiss) private var dismiss
    let entry: UIState.CreationEntry
    let prefill: RunSpec?

    init(entry: UIState.CreationEntry = .chooser, prefill: RunSpec? = nil) {
        self.entry = entry
        self.prefill = prefill
    }

    var body: some View {
        CreationFlow(start: CreationFlow.Start(entry), onClose: { dismiss() }, prefill: prefill)
            .frame(Tokens.SheetSize.form)
            .sheetMaterial()
    }
}

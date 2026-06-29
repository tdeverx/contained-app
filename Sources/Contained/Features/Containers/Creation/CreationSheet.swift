import SwiftUI

/// Modal host for `CreationFlow` — used by File ▸ New, the command palette, and menu-bar actions.
/// The toolbar `+` hosts the same flow in a resizing morph panel; this variant gives it a fixed sheet
/// frame for entry points that are not anchored to a toolbar button.
struct CreationSheet: View {
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

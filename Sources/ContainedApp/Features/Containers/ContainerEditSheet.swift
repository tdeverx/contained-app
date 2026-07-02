import SwiftUI
import ContainedDesignSystem
import ContainedCore

/// The container Create/Edit form presented as a modal sheet. The form body lives in the shared
/// `ContainerConfigureView` (also used by the paged `CreationFlow` in the toolbar); this wrapper just
/// supplies the sheet chrome and a cancel control. Mode `.new` creates; mode `.edit` prefills from an
/// existing container and, on Save, tears it down and re-runs the edited spec in its place.
struct ContainerEditSheet: View {
    enum Mode {
        case new(prefill: RunSpec?)
        case edit(ContainerSnapshot, onComplete: () -> Void)
    }

    @Environment(\.dismiss) private var dismiss
    let mode: Mode

    var body: some View {
        ContainerConfigureView(mode: mode, leading: .cancel { dismiss() }, onFinished: { dismiss() })
            .frame(DesignTokens.SheetSize.form)
            .sheetMaterial()
    }
}

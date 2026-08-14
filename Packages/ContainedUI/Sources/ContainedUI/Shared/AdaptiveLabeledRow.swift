import SwiftUI

/// Keeps ordinary settings rows horizontal, then moves the control beneath the label when both
/// cannot retain their useful intrinsic widths. Callers keep ownership of label and control styling.
struct SharedAdaptiveLabeledRow<Label: View, Trailing: View>: View {
    @ViewBuilder var label: () -> Label
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: UI.Tokens.Space.m) {
                label()
                    .layoutPriority(1)
                Spacer(minLength: UI.Tokens.Space.m)
                trailing()
            }

            VStack(alignment: .leading, spacing: UI.Tokens.Space.s) {
                label()
                trailing()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

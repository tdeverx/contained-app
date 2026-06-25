import SwiftUI

/// A row of colored swatches for picking an `AppTint` — each shows its actual color, the selected
/// one gets a ring.
struct TintSelector: View {
    @Binding var selection: AppTint

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            ForEach(AppTint.allCases) { tint in
                Button { selection = tint } label: { swatch(tint) }
                    .buttonStyle(.plain)
                    .help(tint.displayName)
                    .accessibilityLabel(tint.displayName)
                    .accessibilityAddTraits(selection == tint ? .isSelected : [])
            }
        }
    }

    private func swatch(_ tint: AppTint) -> some View {
        ZStack {
            Circle().fill(tint.color).frame(width: 22, height: 22)
            Circle()
                .strokeBorder(selection == tint ? Color.primary : Color.secondary.opacity(0.35),
                              lineWidth: selection == tint ? 2 : 1)
                .frame(width: 24, height: 24)
        }
        .frame(width: 26, height: 26)
    }
}

import SwiftUI

/// A row of colored swatches for picking an `AppTint` — each shows its actual color, the selected
/// one gets a ring.
public struct TintSelector: View {
    private let selection: Binding<AppTint?>
    private let automaticLabel: String?
    private let labelForTint: (AppTint) -> String

    public init(selection: Binding<AppTint>,
                labelForTint: @escaping (AppTint) -> String) {
        self.selection = Binding<AppTint?>(
            get: { selection.wrappedValue },
            set: { if let newValue = $0 { selection.wrappedValue = newValue } }
        )
        self.automaticLabel = nil
        self.labelForTint = labelForTint
    }

    public init(optionalSelection: Binding<AppTint?>,
                automaticLabel: String,
                labelForTint: @escaping (AppTint) -> String) {
        self.selection = optionalSelection
        self.automaticLabel = automaticLabel
        self.labelForTint = labelForTint
    }

    public var body: some View {
        HStack(spacing: Tokens.Space.s) {
            if let automaticLabel {
                Button { selection.wrappedValue = nil } label: { automaticSwatch }
                    .buttonStyle(.plain)
                    .help(automaticLabel)
                    .accessibilityLabel(automaticLabel)
                    .accessibilityAddTraits(selection.wrappedValue == nil ? .isSelected : [])
            }
            ForEach(AppTint.allCases) { tint in
                let label = labelForTint(tint)
                Button { selection.wrappedValue = tint } label: { swatch(tint) }
                    .buttonStyle(.plain)
                    .help(label)
                    .accessibilityLabel(label)
                    .accessibilityAddTraits(selection.wrappedValue == tint ? .isSelected : [])
            }
        }
    }

    private var automaticSwatch: some View {
        ZStack {
            Circle().fill(Color.secondary.opacity(0.18)).frame(width: 22, height: 22)
            Image(systemName: "rectangle.on.rectangle")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Circle()
                .strokeBorder(selection.wrappedValue == nil ? Color.primary : Color.secondary.opacity(0.35),
                              lineWidth: selection.wrappedValue == nil ? 2 : 1)
                .frame(width: 24, height: 24)
        }
        .frame(width: 26, height: 26)
    }

    private func swatch(_ tint: AppTint) -> some View {
        ZStack {
            Circle().fill(tint.color).frame(width: 22, height: 22)
            // Mark the "follow the app accent" option so it reads as automatic, not a fixed color.
            if tint.followsAppAccent {
                Image(systemName: "link")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
            Circle()
                .strokeBorder(selection.wrappedValue == tint ? Color.primary : Color.secondary.opacity(0.35),
                              lineWidth: selection.wrappedValue == tint ? 2 : 1)
                .frame(width: 24, height: 24)
        }
        .frame(width: 26, height: 26)
    }
}

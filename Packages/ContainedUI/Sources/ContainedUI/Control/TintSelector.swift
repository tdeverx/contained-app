import SwiftUI

/// A row of colored swatches for picking a `UI.Theme.Tint` — each shows its actual color, the selected
/// one gets a ring.
public extension UI.Control {
    struct TintSelector: View {
        private let selection: Binding<UI.Theme.Tint?>
        private let automaticLabel: String?
        private let labelForTint: (UI.Theme.Tint) -> String

        public init(selection: Binding<UI.Theme.Tint>,
                    labelForTint: @escaping (UI.Theme.Tint) -> String) {
            self.selection = Binding<UI.Theme.Tint?>(
                get: { selection.wrappedValue },
                set: { if let newValue = $0 { selection.wrappedValue = newValue } }
            )
            self.automaticLabel = nil
            self.labelForTint = labelForTint
        }

        public init(optionalSelection: Binding<UI.Theme.Tint?>,
                    automaticLabel: String,
                    labelForTint: @escaping (UI.Theme.Tint) -> String) {
            self.selection = optionalSelection
            self.automaticLabel = automaticLabel
            self.labelForTint = labelForTint
        }

        public var body: some View {
            HStack(spacing: UI.Tokens.Space.s) {
                if let automaticLabel {
                    Button { selection.wrappedValue = nil } label: { automaticSwatch }
                        .buttonStyle(.plain)
                        .help(automaticLabel)
                        .accessibilityLabel(automaticLabel)
                        .accessibilityAddTraits(selection.wrappedValue == nil ? .isSelected : [])
                }
                ForEach(UI.Theme.Tint.allCases) { tint in
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

        private func swatch(_ tint: UI.Theme.Tint) -> some View {
            ZStack {
                Circle().fill(tint.color).frame(width: 22, height: 22)
                // Mark the "follow the host accent" option so it reads as automatic, not a fixed color.
                if tint.followsAccent {
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
}

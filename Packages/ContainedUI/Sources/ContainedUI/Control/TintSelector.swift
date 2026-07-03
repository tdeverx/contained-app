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
            SharedTintSwatchMark(color: Color.secondary.opacity(0.18),
                                 markerSystemName: "rectangle.on.rectangle",
                                 markerForeground: .secondary,
                                 selected: selection.wrappedValue == nil)
        }

        private func swatch(_ tint: UI.Theme.Tint) -> some View {
            SharedTintSwatchMark(color: tint.color,
                                 markerSystemName: tint.followsAccent ? "link" : nil,
                                 selected: selection.wrappedValue == tint)
        }
    }
}

#Preview("Tint Selector") {
    TintSelectorPreview()
        .padding(UI.Tokens.Space.xl)
}

private struct TintSelectorPreview: View {
    @State private var tint: UI.Theme.Tint? = .azure

    var body: some View {
        UI.Control.TintSelector(optionalSelection: $tint,
                                automaticLabel: "Automatic",
                                labelForTint: { $0.rawValue.capitalized })
    }
}

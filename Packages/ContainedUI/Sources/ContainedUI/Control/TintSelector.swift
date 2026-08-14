import SwiftUI

/// A horizontally scrolling row of system-color swatches. Pair it with `HexTintField` in a sibling
/// form or panel row so the editor follows the host page's normal label alignment.
public extension UI.Control {
    struct TintSelector: View {
        private enum Choice: Identifiable {
            case automatic
            case tint(UI.Theme.Tint)
            case custom

            var id: String {
                switch self {
                case .automatic: "automatic"
                case .tint(let tint): "tint:\(tint.id)"
                case .custom: "custom"
                }
            }
        }

        private let selection: Binding<UI.Theme.Tint?>
        private let automaticLabel: String?
        private let customLabel: String
        private let inheritedAccentColor: Color?
        private let labelForTint: (UI.Theme.Tint) -> String
        @Environment(\.designSystemAccentColor) private var appAccentColor
        @State private var canScrollForward = true

        public init(selection: Binding<UI.Theme.Tint>,
                    customLabel: String,
                    inheritedAccentColor: Color? = nil,
                    labelForTint: @escaping (UI.Theme.Tint) -> String) {
            self.selection = Binding<UI.Theme.Tint?>(
                get: { selection.wrappedValue },
                set: { if let newValue = $0 { selection.wrappedValue = newValue } }
            )
            self.automaticLabel = nil
            self.customLabel = customLabel
            self.inheritedAccentColor = inheritedAccentColor
            self.labelForTint = labelForTint
        }

        public init(optionalSelection: Binding<UI.Theme.Tint?>,
                    automaticLabel: String,
                    customLabel: String,
                    inheritedAccentColor: Color? = nil,
                    labelForTint: @escaping (UI.Theme.Tint) -> String) {
            self.selection = optionalSelection
            self.automaticLabel = automaticLabel
            self.customLabel = customLabel
            self.inheritedAccentColor = inheritedAccentColor
            self.labelForTint = labelForTint
        }

        public var body: some View {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: UI.Tokens.Space.s) {
                        ForEach(choices) { choice in
                            choiceButton(choice)
                                .id(choice.id)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .frame(minWidth: UI.Tokens.FormWidth.tintColorHex,
                       idealWidth: UI.Tokens.FormWidth.tintSelector,
                       maxWidth: .infinity,
                       minHeight: UI.Tokens.IconSize.control,
                       maxHeight: UI.Tokens.IconSize.control)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.x + geometry.containerSize.width
                        < geometry.contentSize.width - 1
                } action: { _, canScrollForward in
                    self.canScrollForward = canScrollForward
                }
                .mask {
                    HStack(spacing: 0) {
                        Rectangle().fill(.white)
                        if canScrollForward {
                            LinearGradient(colors: [.white, .clear],
                                           startPoint: .leading,
                                           endPoint: .trailing)
                                .frame(width: UI.Tokens.TintSelector.trailingFadeWidth)
                        }
                    }
                }
                .onAppear { scrollToSelection(proxy) }
                .onChange(of: selection.wrappedValue) { _, _ in scrollToSelection(proxy) }
            }
        }

        private var choices: [Choice] {
            var choices: [Choice] = [.tint(.multicolor), .custom]
            if automaticLabel != nil {
                choices.append(.automatic)
            }
            choices.append(contentsOf: UI.Theme.Tint.allCases
                .filter { $0 != .multicolor }
                .map(Choice.tint))
            return choices
        }

        @ViewBuilder
        private func choiceButton(_ choice: Choice) -> some View {
            switch choice {
            case .automatic:
                if let automaticLabel {
                    Button {
                        selection.wrappedValue = nil
                    } label: { automaticSwatch }
                        .buttonStyle(.plain)
                        .help(automaticLabel)
                        .accessibilityLabel(automaticLabel)
                        .accessibilityAddTraits(selection.wrappedValue == nil ? .isSelected : [])
                }
            case .tint(let tint):
                let label = labelForTint(tint)
                Button {
                    selection.wrappedValue = tint
                } label: { swatch(tint) }
                    .buttonStyle(.plain)
                    .help(label)
                    .accessibilityLabel(label)
                    .accessibilityAddTraits(selection.wrappedValue == tint ? .isSelected : [])
            case .custom:
                Button {
                    if selection.wrappedValue?.isCustom != true {
                        selection.wrappedValue = UI.Theme.Tint(hex: HexTintField.defaultExample)
                    }
                } label: { customSwatch }
                    .buttonStyle(.plain)
                    .help(customLabel)
                    .accessibilityLabel(customLabel)
                    .accessibilityAddTraits(selection.wrappedValue?.isCustom == true ? .isSelected : [])
            }
        }

        private var automaticSwatch: some View {
            SharedTintSwatchMark(color: Color.secondary.opacity(0.18),
                                 markerSystemName: "rectangle.on.rectangle",
                                 markerForeground: .secondary,
                                 selected: selection.wrappedValue == nil)
        }

        private func swatch(_ tint: UI.Theme.Tint) -> some View {
            SharedTintSwatchMark(color: tint.followsAccent ? inheritedAccentColor ?? appAccentColor : tint.color,
                                 markerSystemName: tint.followsAccent ? "link" : nil,
                                 selected: selection.wrappedValue == tint)
        }

        private var customSwatch: some View {
            let customTint = selection.wrappedValue.flatMap { $0.isCustom ? $0 : nil }
            return SharedTintSwatchMark(color: customTint?.color ?? Color.secondary.opacity(0.18),
                                        markerSystemName: "number",
                                        markerForeground: customTint?.contrastingColor ?? .secondary,
                                        selected: selection.wrappedValue?.isCustom == true)
        }

        private func scrollToSelection(_ proxy: ScrollViewProxy) {
            let id: String
            if let tint = selection.wrappedValue {
                id = tint.isCustom ? "custom" : "tint:\(tint.id)"
            } else {
                id = "automatic"
            }
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }

    /// The text-field half of a tint picker. Hosts place this in their normal sibling row so its
    /// label and field align with the rest of that form or panel.
    struct HexTintField: View {
        public static let defaultExample = "#007AFF"

        private let selection: Binding<UI.Theme.Tint?>
        private let example: String
        @State private var text = ""

        public init(selection: Binding<UI.Theme.Tint>, example: String = defaultExample) {
            self.selection = Binding<UI.Theme.Tint?>(
                get: { selection.wrappedValue },
                set: { if let newValue = $0 { selection.wrappedValue = newValue } }
            )
            self.example = example
        }

        public init(optionalSelection: Binding<UI.Theme.Tint?>, example: String = defaultExample) {
            self.selection = optionalSelection
            self.example = example
        }

        public var body: some View {
            TextField("", text: $text, prompt: Text(example))
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
                .foregroundStyle(isInvalid ? Color.red : Color.primary)
                .frame(width: UI.Tokens.FormWidth.tintColorHex)
                .disabled(!isCustom)
                .onAppear { synchronizeText() }
                .onChange(of: selection.wrappedValue) { _, _ in synchronizeText() }
                .onChange(of: text) { _, value in
                    guard isCustom, let tint = UI.Theme.Tint(hex: value) else { return }
                    selection.wrappedValue = tint
                }
        }

        private var isCustom: Bool { selection.wrappedValue?.isCustom == true }

        private var isInvalid: Bool {
            isCustom && !text.isEmpty && UI.Theme.Tint.normalizedHex(text) == nil
        }

        private func synchronizeText() {
            text = selection.wrappedValue?.hexValue ?? ""
        }
    }
}

#Preview("Tint Selector") {
    TintSelectorPreview()
        .padding(UI.Tokens.Space.xl)
}

private struct TintSelectorPreview: View {
    @State private var tint: UI.Theme.Tint? = .blue

    var body: some View {
        VStack {
            UI.Control.TintSelector(optionalSelection: $tint,
                                    automaticLabel: "Automatic",
                                    customLabel: "Custom",
                                    labelForTint: { $0.rawValue.capitalized })
            if tint?.isCustom == true {
                UI.Control.HexTintField(optionalSelection: $tint)
            }
        }
    }
}

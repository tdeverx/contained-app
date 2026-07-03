import SwiftUI

public extension UI.Control {
struct KeyCap: View {
    public var text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, UI.Tokens.Keyboard.keyHorizontalPadding)
            .padding(.vertical, UI.Tokens.Keyboard.keyVerticalPadding)
            .background(.quaternary,
                        in: RoundedRectangle(cornerRadius: UI.Tokens.Radius.keyCap,
                                             style: .continuous))
    }
}

struct KeyboardHint: View {
    public var key: String
    public var label: String

    public init(_ key: String, _ label: String) {
        self.key = key
        self.label = label
    }

    public var body: some View {
        HStack(spacing: UI.Tokens.Space.xs) {
            UI.Control.KeyCap(key)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
}

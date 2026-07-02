import SwiftUI

public struct ScopeChipLabel: View {
    public var symbol: String
    public var title: String

    public init(symbol: String, title: String) {
        self.symbol = symbol
        self.title = title
    }

    public var body: some View {
        HStack(spacing: UI.Tokens.Space.xs) {
            Image(systemName: symbol)
                .font(.caption2)
            Text(title)
                .font(.caption.weight(.semibold))
            Image(systemName: "xmark")
                .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, UI.Tokens.Space.s)
        .padding(.vertical, UI.Tokens.Badge.scopeVerticalPadding)
        .background(Color.accentColor.opacity(UI.Tokens.Badge.accentOpacity),
                    in: Capsule(style: .continuous))
        .foregroundStyle(Color.accentColor)
    }
}

public struct TintSwatch: View {
    public var color: Color
    public var followsAccent: Bool

    public init(color: Color, followsAccent: Bool = false) {
        self.color = color
        self.followsAccent = followsAccent
    }

    public var body: some View {
        ZStack {
            Circle().fill(color)
            if followsAccent {
                Image(systemName: "link")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: UI.Tokens.IconSize.chip, height: UI.Tokens.IconSize.chip)
    }
}

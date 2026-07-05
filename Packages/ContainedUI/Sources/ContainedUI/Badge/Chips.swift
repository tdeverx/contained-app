import SwiftUI

public extension UI.Badge {
struct ScopeLabel: View {
    public var symbol: String
    public var title: String

    public init(symbol: String, title: String) {
        self.symbol = symbol
        self.title = title
    }

    public var body: some View {
        SharedCapsuleLabel(horizontalPadding: UI.Tokens.Space.s,
                           verticalPadding: UI.Tokens.Badge.scopeVerticalPadding,
                           foreground: AnyShapeStyle(Color.accentColor),
                           fill: AnyShapeStyle(Color.accentColor.opacity(UI.Tokens.Badge.accentOpacity))) {
            HStack(spacing: UI.Tokens.Space.xs) {
            Image(systemName: symbol)
                .font(.caption2)
            SwiftUI.Text(title)
                .font(.caption.weight(.semibold))
            Image(systemName: "xmark")
                .font(.caption2.weight(.bold))
            }
        }
    }
}
}

public extension UI.Control {
struct TintSwatch: View {
    public var color: Color
    public var followsAccent: Bool

    public init(color: Color, followsAccent: Bool = false) {
        self.color = color
        self.followsAccent = followsAccent
    }

    public var body: some View {
        SharedTintSwatchMark(color: color,
                             markerSystemName: followsAccent ? "link" : nil,
                             size: UI.Tokens.IconSize.chip,
                             fillSize: UI.Tokens.IconSize.chip,
                             ringSize: UI.Tokens.IconSize.chip)
    }
}
}

#Preview("Chips") {
    HStack(spacing: UI.Tokens.Space.m) {
        UI.Badge.ScopeLabel(symbol: "shippingbox", title: "Containers")
        UI.Control.TintSwatch(color: .accentColor, followsAccent: true)
        UI.Control.TintSwatch(color: .teal)
    }
    .padding(UI.Tokens.Space.xl)
}

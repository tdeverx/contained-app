import SwiftUI

/// A package-owned content surface for empty states and grouped panel content.
public struct ContentSurface<Content: View>: View {
    public var elevated: Bool
    public var minHeight: CGFloat?
    public var alignment: Alignment
    public var padding: CGFloat
    @ViewBuilder public var content: () -> Content

    public init(elevated: Bool = false,
                minHeight: CGFloat? = nil,
                alignment: Alignment = .center,
                padding: CGFloat = UI.Tokens.Space.s,
                @ViewBuilder content: @escaping () -> Content) {
        self.elevated = elevated
        self.minHeight = minHeight
        self.alignment = alignment
        self.padding = padding
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: alignment)
            .materialSurface(.regular, cornerRadius: UI.Tokens.Radius.card, shadow: elevated)
    }
}

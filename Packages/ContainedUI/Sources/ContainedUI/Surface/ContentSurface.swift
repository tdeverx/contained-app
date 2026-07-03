import SwiftUI

/// A package-owned content surface for empty states and grouped panel content.
public extension UI.Surface {
struct Content<ContentView: View>: View {
    public var elevated: Bool
    public var minHeight: CGFloat?
    public var alignment: Alignment
    public var padding: CGFloat
    @ViewBuilder public var content: () -> ContentView

    public init(elevated: Bool = false,
                minHeight: CGFloat? = nil,
                alignment: Alignment = .center,
                padding: CGFloat = UI.Tokens.Space.s,
                @ViewBuilder content: @escaping () -> ContentView) {
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
}

#Preview("Content Surface") {
    UI.Surface.Content(elevated: true, minHeight: 140) {
        UI.State.Empty("No results",
                       systemImage: "magnifyingglass",
                       description: "Try another search term.")
    }
    .padding(UI.Tokens.Space.xl)
    .frame(width: 420)
}

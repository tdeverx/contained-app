import SwiftUI

/// A package-owned surface for compact inline controls such as search fields and text editors.
public struct InputSurface<Content: View>: View {
    public var horizontalPadding: CGFloat
    public var verticalPadding: CGFloat
    public var minHeight: CGFloat?
    @ViewBuilder public var content: () -> Content

    public init(horizontalPadding: CGFloat = UI.Tokens.Space.m,
                verticalPadding: CGFloat = UI.Tokens.Space.s,
                minHeight: CGFloat? = nil,
                @ViewBuilder content: @escaping () -> Content) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.minHeight = minHeight
        self.content = content
    }

    public var body: some View {
        content()
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .materialSurface(.thin, cornerRadius: UI.Tokens.Radius.control)
    }
}

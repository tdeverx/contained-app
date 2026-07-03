import SwiftUI

/// A package-owned surface for compact inline controls such as search fields and text editors.
public extension UI.Surface {
struct Input<Content: View>: View {
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
}

#Preview("Input Surface") {
    UI.Surface.Input {
        HStack {
            Image(systemName: "terminal")
                .foregroundStyle(.secondary)
            Text("container run nginx")
                .font(.system(.caption, design: .monospaced))
        }
    }
    .padding(UI.Tokens.Space.xl)
    .frame(width: 420)
}

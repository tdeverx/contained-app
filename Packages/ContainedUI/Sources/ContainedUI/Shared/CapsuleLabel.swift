import SwiftUI

struct SharedCapsuleLabel<Content: View>: View {
    var horizontalPadding: CGFloat
    var verticalPadding: CGFloat
    var foreground: AnyShapeStyle?
    var fill: AnyShapeStyle
    @ViewBuilder var content: () -> Content

    init(horizontalPadding: CGFloat,
         verticalPadding: CGFloat,
         foreground: AnyShapeStyle? = nil,
         fill: AnyShapeStyle,
         @ViewBuilder content: @escaping () -> Content) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.foreground = foreground
        self.fill = fill
        self.content = content
    }

    var body: some View {
        styledContent
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(fill, in: Capsule(style: .continuous))
    }

    @ViewBuilder
    private var styledContent: some View {
        if let foreground {
            content().foregroundStyle(foreground)
        } else {
            content()
        }
    }
}

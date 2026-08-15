import SwiftUI

/// A horizontally scrolling content lane that bleeds through its caller's standard inset while
/// keeping the first and last items aligned to that inset at rest.
public extension UI.Surface {
struct HorizontalScrollLane<Content: View>: View {
    public var inset: CGFloat
    @ViewBuilder public var content: () -> Content

    public init(inset: CGFloat = UI.Tokens.Space.s,
                @ViewBuilder content: @escaping () -> Content) {
        self.inset = inset
        self.content = content
    }

    public var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: inset) {
                content()
            }
            .padding(.horizontal, inset)
        }
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .horizontal)
        .padding(.horizontal, -inset)
    }
}
}

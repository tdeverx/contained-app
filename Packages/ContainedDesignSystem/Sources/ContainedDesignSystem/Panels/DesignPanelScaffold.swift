import SwiftUI

/// A reusable panel body: fixed chrome above a scrollable content area and an optional pinned footer.
///
/// The panel fills the fixed size its presentation host gives it (for example,
/// `DesignTokens.PanelSize.*`). The inner `ScrollView` fills that area and scrolls; it does not measure
/// its content. This matters for performance: an earlier version measured the scroll content's natural
/// height, which forced long lazy lists to realize on open.
///
/// Pass `scrolls: false` for content that brings **its own** scroll view (search results, build
/// workspace, the paged run form). In that mode the scaffold doesn't wrap the content in a `ScrollView`,
/// so scroll views are not double-nested.
public struct DesignPanelScaffold<Chrome: View, Content: View, Footer: View>: View {
    /// The expected host width. The scaffold still expands to the width assigned by its presentation host.
    public var width: CGFloat
    public var scrollEdgeStyle: ScrollEdgeEffectStyle = .soft
    public var scrolls: Bool = true
    /// Fixed chrome pinned above the scroll area (header, divider, segmented pickers).
    @ViewBuilder var chrome: () -> Chrome
    /// Scrollable content — supplied without a `ScrollView`; the scaffold provides it (unless `scrolls`
    /// is false, in which case the content is placed directly and owns its own scrolling).
    @ViewBuilder var content: () -> Content
    /// Optional fixed chrome pinned below the scroll area (submit bars, command preview).
    @ViewBuilder var footer: () -> Footer

    public init(width: CGFloat,
                scrollEdgeStyle: ScrollEdgeEffectStyle = .soft,
                scrolls: Bool = true,
                @ViewBuilder chrome: @escaping () -> Chrome,
                @ViewBuilder content: @escaping () -> Content,
                @ViewBuilder footer: @escaping () -> Footer) {
        self.width = width
        self.scrollEdgeStyle = scrollEdgeStyle
        self.scrolls = scrolls
        self.chrome = chrome
        self.content = content
        self.footer = footer
    }

    public var body: some View {
        VStack(spacing: 0) {
            chrome()
            if scrolls {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        content()
                            .frame(maxWidth: .infinity)
                    }
                }
                .scrollEdgeEffectStyle(scrollEdgeStyle, for: .all)
            } else {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            footer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

public extension DesignPanelScaffold where Footer == EmptyView {
    init(width: CGFloat,
         scrollEdgeStyle: ScrollEdgeEffectStyle = .soft,
         scrolls: Bool = true,
         @ViewBuilder chrome: @escaping () -> Chrome,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(width: width, scrollEdgeStyle: scrollEdgeStyle, scrolls: scrolls,
                  chrome: chrome, content: content, footer: { EmptyView() })
    }
}

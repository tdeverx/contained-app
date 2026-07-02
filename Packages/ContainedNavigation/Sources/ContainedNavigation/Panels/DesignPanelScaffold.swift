import SwiftUI
import ContainedDesignSystem

/// A toolbar morph-panel body: fixed chrome (header, segmented pickers) above a scrollable content area
/// and an optional pinned footer.
///
/// The panel takes the **fixed size** its host hands the `MorphingExpander` (e.g. `DesignTokens.PanelSize.*`).
/// The inner `ScrollView` simply fills that area and scrolls; it does **not** measure its content. This
/// matters for performance: an earlier version measured the scroll content's natural height (to make the
/// panel hug it), which forced the whole `LazyVStack` to realize on open. Filling a definite height
/// keeps long lists lazy (only visible rows render).
///
/// Pass `scrolls: false` for content that brings **its own** scroll view (search results, build
/// workspace, the paged run form). In that mode the scaffold doesn't wrap the content in a `ScrollView`,
/// so scroll views aren't double-nested; the host (e.g. `CreationFlow`) supplies the size via
/// `morphPanelSize`.
public struct DesignPanelScaffold<Chrome: View, Content: View, Footer: View>: View {
    /// Retained for call-site compatibility; the panel's width comes from the host's morph target.
    public var width: CGFloat
    public var placement: MorphPanelPlacement = .anchored
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
                placement: MorphPanelPlacement = .anchored,
                scrollEdgeStyle: ScrollEdgeEffectStyle = .soft,
                scrolls: Bool = true,
                @ViewBuilder chrome: @escaping () -> Chrome,
                @ViewBuilder content: @escaping () -> Content,
                @ViewBuilder footer: @escaping () -> Footer) {
        self.width = width
        self.placement = placement
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
         placement: MorphPanelPlacement = .anchored,
         scrollEdgeStyle: ScrollEdgeEffectStyle = .soft,
         scrolls: Bool = true,
         @ViewBuilder chrome: @escaping () -> Chrome,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(width: width, placement: placement, scrollEdgeStyle: scrollEdgeStyle, scrolls: scrolls,
                  chrome: chrome, content: content, footer: { EmptyView() })
    }
}

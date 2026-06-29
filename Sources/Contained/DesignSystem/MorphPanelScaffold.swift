import SwiftUI

/// A toolbar morph-panel body that **hugs its content vertically**. It measures the natural height of
/// its fixed chrome (header, segmented pickers), its scrollable content, and any pinned footer, and
/// reports the sum as the panel size — so the panel collapses toward its content (down to
/// `Tokens.PanelSize.minHeight`) and grows with it.
///
/// The enclosing `MorphingExpander` clamps the reported height to the available window area, so when the
/// content is taller than the window the inner `ScrollView` scrolls instead of the panel overflowing.
/// The content height is measured from the scroll *content* (independent of the `ScrollView`'s own
/// frame), so there is no layout feedback loop.
///
/// Pass `scrolls: false` for content that brings **its own** scroll view (search results, build
/// workspace, the run form's sub-lists). In that mode the scaffold does not wrap the content in a
/// `ScrollView` and does not report a hugging size — the host supplies a fixed `morphPanelSize` — so the
/// chrome stays unified without double-nesting scroll views.
struct MorphPanelScaffold<Chrome: View, Content: View, Footer: View>: View {
    var width: CGFloat
    var placement: MorphPanelPlacement = .anchored
    var scrollEdgeStyle: ScrollEdgeEffectStyle = .soft
    var scrolls: Bool = true
    /// Fixed chrome pinned above the scroll area (header, divider, segmented pickers).
    @ViewBuilder var chrome: () -> Chrome
    /// Scrollable content — supplied without a `ScrollView`; the scaffold provides it (unless `scrolls`
    /// is false, in which case the content is placed directly and owns its own scrolling).
    @ViewBuilder var content: () -> Content
    /// Optional fixed chrome pinned below the scroll area (submit bars, command preview).
    @ViewBuilder var footer: () -> Footer

    @State private var chromeHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0

    private var reportedHeight: CGFloat {
        max(Tokens.PanelSize.minHeight, chromeHeight + contentHeight + footerHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            chrome()
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { chromeHeight = $0 })
            if scrolls {
                ScrollView {
                    content()
                        .frame(maxWidth: .infinity)
                        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { contentHeight = $0 })
                }
                .scrollEdgeEffectStyle(scrollEdgeStyle, for: .all)
            } else {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            footer()
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { footerHeight = $0 })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .reportPanelSize(scrolls ? CGSize(width: width, height: reportedHeight) : nil, placement: placement)
    }
}

private extension View {
    /// Report a hugging panel size + placement only when the scaffold is in scrolling mode; non-scrolling
    /// pages are sized by their host (e.g. the paged `CreationFlow`).
    @ViewBuilder
    func reportPanelSize(_ size: CGSize?, placement: MorphPanelPlacement) -> some View {
        if let size {
            self.morphPanelSize(size).morphPanelPlacement(placement)
        } else {
            self
        }
    }
}

extension MorphPanelScaffold where Footer == EmptyView {
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

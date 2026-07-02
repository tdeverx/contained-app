import SwiftUI

public extension EnvironmentValues {
    @Entry var pageScaffoldUsesToolbarChrome = false
    @Entry var pageScaffoldBottomClearance: CGFloat = 0
}

public struct PageScaffold<Actions: View, Content: View>: View {
    public let symbol: String
    public let title: String
    public let subtitle: String
    public var scrolls = true
    @ViewBuilder var actions: () -> Actions
    @ViewBuilder var content: () -> Content
    @Environment(\.pageScaffoldUsesToolbarChrome) private var usesToolbarChrome
    @Environment(\.pageScaffoldBottomClearance) private var bottomClearance

    public init(symbol: String,
                title: String,
                subtitle: String,
                scrolls: Bool = true,
                @ViewBuilder actions: @escaping () -> Actions,
                @ViewBuilder content: @escaping () -> Content) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self.scrolls = scrolls
        self.actions = actions
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            if !usesToolbarChrome {
                PanelHeader(symbol: symbol, title: title, subtitle: subtitle) {
                    actions()
                }
                Divider()
            }
            if scrolls {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        content()
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(usesToolbarChrome ? DesignTokens.Space.s : DesignTokens.Space.l)
                        if usesToolbarChrome && bottomClearance > 0 {
                            Color.clear
                                .frame(height: bottomClearance)
                        }
                    }
                }
                .scrollEdgeEffectStyle(.soft, for: .all)
            } else {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

public extension PageScaffold where Actions == EmptyView {
    init(symbol: String,
         title: String,
         subtitle: String,
         scrolls: Bool = true,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(symbol: symbol, title: title, subtitle: subtitle, scrolls: scrolls,
                  actions: { EmptyView() }, content: content)
    }
}

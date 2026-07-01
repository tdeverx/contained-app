import SwiftUI

struct PageScaffold<Actions: View, Content: View>: View {
    @Environment(UIState.self) private var ui
    let symbol: String
    let title: String
    let subtitle: String
    var scrolls = true
    @ViewBuilder var actions: () -> Actions
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            if !ui.toolbarUIEnabled {
                PanelHeader(symbol: symbol, title: title, subtitle: subtitle) {
                    actions()
                }
                Divider()
            }
            if scrolls {
                ScrollView {
                    VStack(spacing: 0) {
                        content()
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(ui.toolbarUIEnabled ? Tokens.Space.s : Tokens.Space.l)
                        if ui.toolbarUIEnabled {
                            Color.clear
                                .frame(height: AppToolbar.bandHeight)
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

extension PageScaffold where Actions == EmptyView {
    init(symbol: String,
         title: String,
         subtitle: String,
         scrolls: Bool = true,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(symbol: symbol, title: title, subtitle: subtitle, scrolls: scrolls,
                  actions: { EmptyView() }, content: content)
    }
}

import SwiftUI
import ContainedDesignSystem

#Preview("Morph Panel") {
    NavigationPreview()
        .frame(width: 720, height: 520)
        .environment(\.morphSafeAreas,
                      MorphSafeAreaManager(topToolbarHeight: DesignTokens.Toolbar.band,
                                           bottomToolbarHeight: DesignTokens.Toolbar.band))
        .environment(\.buttonMaterial, .glassClear)
}

private struct NavigationPreview: View {
    @State private var isPresented = true

    private let origin = CGRect(x: 24,
                                y: 24,
                                width: DesignTokens.Toolbar.buttonGroupHeight,
                                height: DesignTokens.Toolbar.buttonGroupHeight)

    var body: some View {
        ZStack(alignment: .topLeading) {
            DesignActionGroup(DesignAction(systemName: "plus", help: "Open") {
                isPresented = true
            })
            .padding(DesignTokens.Space.l)

            MorphingExpander(isPresented: $isPresented,
                             originFrame: origin,
                             target: .centered(size: DesignTokens.PanelSize.add)) {
                DesignPanelScaffold(width: DesignTokens.PanelSize.add.width) {
                    PanelHeader(symbol: "plus",
                                title: "Preview panel",
                                subtitle: "Reusable morph layout") {
                        DesignActionGroup(DesignAction(systemName: "xmark",
                                                       help: "Close",
                                                       isCancel: true) {
                            isPresented = false
                        })
                    }
                } content: {
                    VStack(spacing: DesignTokens.Space.s) {
                        GlassOptionTile(symbol: "shippingbox",
                                        title: "Container",
                                        subtitle: "Start from an image") {}
                        GlassOptionTile(symbol: "square.stack.3d.up",
                                        title: "Image",
                                        subtitle: "Use a local image") {}
                    }
                    .padding(DesignTokens.Space.s)
                }
            }
        }
    }
}

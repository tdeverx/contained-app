#if CONTAINED_UX_PREVIEWS
import SwiftUI
import ContainedUI

#Preview("Morph Panel") {
    NavigationPreview()
        .frame(width: 720, height: 520)
        .environment(\.morphSafeAreaManager,
                      UX.SafeArea.Manager(topToolbarHeight: UI.Toolbar.Size.band,
                                           bottomToolbarHeight: UI.Toolbar.Size.band))
        .environment(\.buttonMaterial, .glassClear)
}

private struct NavigationPreview: View {
    @State private var isPresented = true

    private let origin = CGRect(x: 24,
                                y: 24,
                                width: UI.Toolbar.Size.buttonGroupHeight,
                                height: UI.Toolbar.Size.buttonGroupHeight)

    var body: some View {
        ZStack(alignment: .topLeading) {
            UI.Action.Group(UI.Action.Item(systemName: "plus", help: "Open") {
                isPresented = true
            })
            .padding(UI.Layout.Spacing.l)

            UX.Morph.Expander(isPresented: $isPresented,
                             originFrame: origin,
                             target: .centered(size: UI.Panel.Size.add)) {
                UI.Panel.Scaffold(width: UI.Panel.Size.add.width) {
                    UI.Panel.Header(symbol: "plus",
                                title: "Preview panel",
                                subtitle: "Reusable morph layout") {
                        UI.Action.Group(UI.Action.Item(systemName: "xmark",
                                                       help: "Close",
                                                       isCancel: true) {
                            isPresented = false
                        })
                    }
                } content: {
                    VStack(spacing: UI.Layout.Spacing.s) {
                        UI.Control.OptionTile(symbol: "shippingbox",
                                        title: "Primary item",
                                        subtitle: "Start from a template") {}
                        UI.Control.OptionTile(symbol: "square.stack.3d.up",
                                        title: "Image",
                                        subtitle: "Use a local image") {}
                    }
                    .padding(UI.Layout.Spacing.s)
                }
            }
        }
    }
}
#endif

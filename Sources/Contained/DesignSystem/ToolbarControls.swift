import SwiftUI

/// Design-system controls for the app toolbar band, sized from `Tokens.Toolbar` to macOS 26 Liquid
/// Glass toolbar proportions. Centralizing them here keeps the toolbar, the creation tiles
/// (`GlassOptionTile`), and any future band controls visually consistent and on one source of truth.

/// A toolbar-styled menu trigger that uses the same icon sizing as `GlassButtonItem` but keeps
/// the actual menu behavior native.
struct ToolbarMenuButton<Content: View>: View {
    let systemName: String
    var help: String = ""
    @ViewBuilder var content: () -> Content

    var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: systemName)
                .font(.body.weight(.medium))
                .padding(Tokens.Toolbar.iconInnerPadding)
                .frame(height: Tokens.Toolbar.buttonItemHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .help(help)
        .accessibilityLabel(help)
    }
}

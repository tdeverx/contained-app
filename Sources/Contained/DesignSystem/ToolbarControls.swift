import SwiftUI

/// Design-system controls for the app toolbar band, sized from `Tokens.Toolbar` to macOS 26 Liquid
/// Glass toolbar proportions. Centralizing them here keeps the toolbar, the creation tiles
/// (`GlassOptionTile`), and any future band controls visually consistent and on one source of truth.

/// A single icon button for the toolbar band — a borderless SF Symbol in a circular hit target.
struct ToolbarIconButton: View {
    let systemName: String
    var help: String = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline)             // 13pt semibold (weight) → Dynamic-Type scalable
                .imageScale(.large)          // bumps the glyph up to toolbar size (headline == body size)
                .padding(Tokens.Toolbar.iconInnerPadding)
                .frame(width: Tokens.Toolbar.controlHeight, height: Tokens.Toolbar.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .background {
            Circle().fill(.clear).glassEffect(.regular.interactive(), in: Circle())
        }
        .clipShape(Circle())
        .help(help)
        .accessibilityLabel(help)
    }
}

extension View {
    /// The capsule Liquid Glass background shared by toolbar control groups and the search field —
    /// interactive `.regular` glass in a concentric capsule, padded so grouped buttons sit on one
    /// baseline. Matches the interactive glass used by `GlassOptionTile`.
    func toolbarControlGlass() -> some View {
        clipShape(Capsule())
    }
}

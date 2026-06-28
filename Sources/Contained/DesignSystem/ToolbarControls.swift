import SwiftUI

/// Design-system controls for the app toolbar band, sized from `Tokens.Toolbar` to macOS 26 Liquid
/// Glass toolbar proportions. Centralizing them here keeps the toolbar, the creation tiles
/// (`GlassOptionTile`), and any future band controls visually consistent and on one source of truth.

/// A single icon button for the toolbar band — a borderless SF Symbol in a circular hit target.
/// Standalone, it carries its own circular glass; placed inside a `ToolbarButtonCluster`, pass
/// `showsBackground: false` so the cluster's shared capsule provides the glass instead.
struct ToolbarIconButton: View {
    let systemName: String
    var help: String = ""
    /// When false, the button draws no glass of its own (the enclosing cluster supplies it).
    var showsBackground = true
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
            if showsBackground {
                Circle().fill(.clear).glassEffect(.regular.interactive(), in: Circle())
            }
        }
        .clipShape(Circle())
        .help(help)
        .accessibilityLabel(help)
    }
}

/// A pill that groups related toolbar buttons under one shared interactive-glass capsule (e.g.
/// Images + Activity). Place bare `ToolbarIconButton`s (`showsBackground: false`) inside; the cluster
/// owns the capsule glass, so the group reads as a single control — and its frame is what a morph
/// grows out of (see `AppToolbar`).
struct ToolbarButtonCluster<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: Tokens.Toolbar.groupSpacing) { content() }
            .padding(.horizontal, Tokens.Toolbar.groupPaddingH)
            .frame(height: Tokens.Toolbar.controlHeight)
            .glassEffect(.regular.interactive(), in: Capsule())
    }
}

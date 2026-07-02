import SwiftUI

/// Design-system controls for the app toolbar band, sized from `Tokens.Toolbar` to macOS 26 Liquid
/// Glass toolbar proportions. Centralizing them here keeps the toolbar, the creation tiles
/// (`GlassOptionTile`), and any future band controls visually consistent and on one source of truth.

/// A toolbar-styled menu trigger that uses the same icon sizing as `GlassButtonItem` but keeps
/// the actual menu behavior native.
public struct ToolbarMenuButton<Content: View>: View {
    public let systemName: String
    public var help: String
    @ViewBuilder public var content: () -> Content

    public init(systemName: String, help: String = "", @ViewBuilder content: @escaping () -> Content) {
        self.systemName = systemName
        self.help = help
        self.content = content
    }

    public var body: some View {
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

/// Shared two-line toolbar label used by page switchers and filter menus.
/// The second line is always secondary so status/filter copy stays visually subordinate.
public struct ToolbarTitleSubtitleLabel: View {
    public let symbol: String
    public let title: String
    public let subtitle: String
    public var showsChevron: Bool

    public init(symbol: String, title: String, subtitle: String, showsChevron: Bool = true) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self.showsChevron = showsChevron
    }

    public var body: some View {
        HStack(spacing: Tokens.Toolbar.searchIconGap) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: Tokens.Toolbar.buttonItemHeight - Tokens.Toolbar.iconInnerPadding * 2)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .lineLimit(1)
        .padding(.trailing, Tokens.Toolbar.iconInnerPadding * 2)
        .frame(height: Tokens.Toolbar.buttonGroupHeight)
        .contentShape(Rectangle())
    }
}

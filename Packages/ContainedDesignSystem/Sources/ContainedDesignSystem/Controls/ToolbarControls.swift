import SwiftUI

/// Design-system controls for the app toolbar band, sized from `DesignTokens.Toolbar` to macOS 26
/// toolbar proportions. Centralizing them here keeps the toolbar, creation tiles
/// (`DesignOptionTile`), and future band controls visually consistent.

public struct DesignMenuButton<LabelContent: View, MenuContent: View>: View {
    @ViewBuilder public var menuContent: () -> MenuContent
    @ViewBuilder public var labelContent: () -> LabelContent

    public init(@ViewBuilder menuContent: @escaping () -> MenuContent,
                @ViewBuilder labelContent: @escaping () -> LabelContent) {
        self.menuContent = menuContent
        self.labelContent = labelContent
    }

    public var body: some View {
        Menu {
            menuContent()
        } label: {
            GlassButton(singleItem: true) {
                labelContent()
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: true, vertical: false)
    }
}

public struct DesignToolbarSearchField<Trailing: View>: View {
    @Binding public var text: String
    public var prompt: String
    public var clearSearchLabel: String
    public var focused: FocusState<Bool>.Binding
    public var onSubmit: () -> Void
    public var onClear: () -> Void
    @ViewBuilder public var trailing: () -> Trailing

    public init(text: Binding<String>,
                prompt: String,
                clearSearchLabel: String,
                focused: FocusState<Bool>.Binding,
                onSubmit: @escaping () -> Void = {},
                onClear: @escaping () -> Void,
                @ViewBuilder trailing: @escaping () -> Trailing) {
        self._text = text
        self.prompt = prompt
        self.clearSearchLabel = clearSearchLabel
        self.focused = focused
        self.onSubmit = onSubmit
        self.onClear = onClear
        self.trailing = trailing
    }

    public var body: some View {
        GlassButton(singleItem: true) {
            GlassButtonInputItem {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .foregroundStyle(.secondary)
                TextField(prompt, text: $text)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .fontWeight(.medium)
                    .focused(focused)
                    .onSubmit(onSubmit)
                if !text.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(clearSearchLabel)
                    .accessibilityLabel(clearSearchLabel)
                } else {
                    trailing()
                }
            }
        }
        .toolbarControlContentShape()
        .simultaneousGesture(TapGesture().onEnded { focused.wrappedValue = true })
    }
}

/// Package-owned empty toolbar slot for stable morph origins and vanity chrome.
public struct DesignToolbarVanitySlot<Content: View>: View {
    public var minWidth: CGFloat
    public var interactive: Bool
    @ViewBuilder public var content: () -> Content

    public init(minWidth: CGFloat = DesignTokens.Toolbar.trafficLightsWidth,
                interactive: Bool = false,
                @ViewBuilder content: @escaping () -> Content = { Color.clear }) {
        self.minWidth = minWidth
        self.interactive = interactive
        self.content = content
    }

    public var body: some View {
        GlassButton(minWidth: minWidth, singleItem: true, interactive: interactive) {
            content()
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// Package-owned toolbar button for custom status content.
public struct DesignToolbarStatusButton<Content: View>: View {
    public var help: String
    public var action: () -> Void
    @ViewBuilder public var content: () -> Content

    public init(help: String,
                action: @escaping () -> Void,
                @ViewBuilder content: @escaping () -> Content) {
        self.help = help
        self.action = action
        self.content = content
    }

    public var body: some View {
        GlassButton(singleItem: true) {
            GlassButtonItem(help: help, action: action) {
                content()
            }
        }
    }
}

/// Package-owned glass shell for toolbar clusters that mix action items and status/menu items.
public struct DesignToolbarActionCluster<Content: View>: View {
    public var spacing: CGFloat
    @ViewBuilder public var content: () -> Content

    public init(spacing: CGFloat = 0,
                @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        GlassButton(spacing: spacing) {
            content()
        }
    }
}

/// A toolbar-styled menu trigger that uses the shared toolbar icon lane while keeping native menu
/// behavior.
public struct DesignToolbarMenuButton<Content: View>: View {
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
                .padding(DesignTokens.Toolbar.iconInnerPadding)
                .frame(height: DesignTokens.Toolbar.buttonItemHeight)
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
        HStack(spacing: DesignTokens.Toolbar.searchIconGap) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: DesignTokens.Toolbar.buttonItemHeight - DesignTokens.Toolbar.iconInnerPadding * 2)
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
        .padding(.trailing, DesignTokens.Toolbar.iconInnerPadding * 2)
        .frame(height: DesignTokens.Toolbar.buttonGroupHeight)
        .contentShape(Rectangle())
    }
}

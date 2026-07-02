import SwiftUI

/// A reusable three-part card header: leading accessory, fill/truncate text block, and trailing
/// button rail. This keeps the container/image cards using the same top-aligned chrome structure.
public struct ResourceCardHeader<Leading: View, Content: View, Trailing: View>: View {
    public var spacing: CGFloat
    public var padding: CGFloat
    @ViewBuilder public var leading: () -> Leading
    @ViewBuilder public var content: () -> Content
    @ViewBuilder public var trailing: () -> Trailing

    public init(spacing: CGFloat = Tokens.ResourceCard.padding,
                padding: CGFloat = Tokens.ResourceCard.padding,
                @ViewBuilder leading: @escaping () -> Leading,
                @ViewBuilder content: @escaping () -> Content,
                @ViewBuilder trailing: @escaping () -> Trailing) {
        self.spacing = spacing
        self.padding = padding
        self.leading = leading
        self.content = content
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            leading()
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(padding)
    }
}

/// A small reusable footer mini: optional icon + optional text, aligned on one baseline.
public struct ResourceCardFooterMini<Icon: View, TextContent: View>: View {
    public var spacing: CGFloat
    @ViewBuilder public var icon: () -> Icon
    @ViewBuilder public var text: () -> TextContent

    public init(spacing: CGFloat = Tokens.Space.xs,
                @ViewBuilder icon: @escaping () -> Icon,
                @ViewBuilder text: @escaping () -> TextContent) {
        self.spacing = spacing
        self.icon = icon
        self.text = text
    }

    public var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            icon()
            text()
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// A flat inset section for content that lives inside an expanded `ResourceGlassCard`.
///
/// Use this for charts, process lists, read-only fields, and terminal overlays inside a card body.
/// It intentionally avoids creating a second card-shaped glass surface inside the parent card.
public struct ResourceCardInsetSection<Content: View>: View {
    public var title: String?
    public var alignment: HorizontalAlignment
    public var spacing: CGFloat
    public var padding: CGFloat
    @ViewBuilder public var content: () -> Content

    public init(title: String? = nil,
                alignment: HorizontalAlignment = .leading,
                spacing: CGFloat = Tokens.Space.s,
                padding: CGFloat = Tokens.Space.s,
                @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.alignment = alignment
        self.spacing = spacing
        self.padding = padding
        self.content = content
    }

    public var body: some View {
        VStack(alignment: alignment, spacing: Tokens.Space.s) {
            if let title {
                Text(title)
                    .font(.headline)
                    .padding(.leading, Tokens.Space.xs)
            }
            LazyVStack(alignment: alignment, spacing: spacing) {
                content()
            }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
            .background(AppMaterial.toolbarHoverFill,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.control,
                                             style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }
}

/// A selectable footer chip for card widgets, filters, and compact tab-like metadata.
public struct ResourceCardFooterChip<Icon: View, TextContent: View>: View {
    public var isSelected: Bool
    public var tint: Color
    public var help: String
    public var action: () -> Void
    @ViewBuilder public var icon: () -> Icon
    @ViewBuilder public var text: () -> TextContent

    public init(isSelected: Bool,
                tint: Color,
                help: String,
                action: @escaping () -> Void,
                @ViewBuilder icon: @escaping () -> Icon,
                @ViewBuilder text: @escaping () -> TextContent) {
        self.isSelected = isSelected
        self.tint = tint
        self.help = help
        self.action = action
        self.icon = icon
        self.text = text
    }

    public var body: some View {
        Button(action: action) {
            ResourceCardFooterMini {
                icon()
            } text: {
                text()
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Shared icon-only action used by resource-card footers.
public struct ResourceCardFooterButton: View {
    public var systemName: String
    public var help: String
    public var tint: Color?
    public var role: ButtonRole?
    public var action: () -> Void

    public init(systemName: String,
                help: String,
                tint: Color? = nil,
                role: ButtonRole? = nil,
                action: @escaping () -> Void) {
        self.systemName = systemName
        self.help = help
        self.tint = tint
        self.role = role
        self.action = action
    }

    public var body: some View {
        Button(role: role, action: action) {
            ResourceCardFooterMini {
                Image(systemName: systemName).font(.body)
            } text: {
                EmptyView()
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(foregroundStyle)
        .help(help)
        .accessibilityLabel(help)
    }

    private var foregroundStyle: AnyShapeStyle {
        if role == .destructive { return AnyShapeStyle(Color.red) }
        if let tint { return AnyShapeStyle(tint) }
        return AnyShapeStyle(.secondary)
    }
}

public struct ResourceCardPageControlItem<ID: Hashable>: Identifiable, Hashable {
    public var id: ID
    public var title: String
    public var systemImage: String

    public init(id: ID, title: String, systemImage: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}

/// Shared expanded-card page rail with page icons plus a close affordance.
public struct ResourceCardPageControls<ID: Hashable>: View {
    public var items: [ResourceCardPageControlItem<ID>]
    public var selection: ID
    public var tint: Color
    public var controlsReveal: Double
    public var onSelect: (ID) -> Void
    public var onClose: () -> Void

    public init(items: [ResourceCardPageControlItem<ID>],
                selection: ID,
                tint: Color,
                controlsReveal: Double = 1,
                onSelect: @escaping (ID) -> Void,
                onClose: @escaping () -> Void) {
        self.items = items
        self.selection = selection
        self.tint = tint
        self.controlsReveal = controlsReveal
        self.onSelect = onSelect
        self.onClose = onClose
    }

    public var body: some View {
        GlassButton(singleItem: false) {
            ForEach(items) { item in
                GlassButtonItem(tint: selection == item.id ? tint : nil,
                                help: item.title,
                                isIcon: true,
                                action: { onSelect(item.id) }) {
                    Image(systemName: item.systemImage)
                        .opacity(selection == item.id ? 1 : 0.62)
                }
            }
            GlassButtonItem(systemName: "xmark", help: "Close", action: onClose)
        }
        .opacity(controlsReveal)
        .allowsHitTesting(controlsReveal > 0.01)
        .animation(.easeOut(duration: 0.18), value: controlsReveal)
    }
}

/// A reusable footer item band that hugs its content and anchors either left or right.
public struct ResourceCardFooterGroup<Content: View>: View {
    public enum Alignment {
        case leading, trailing
    }

    public var alignment: Alignment
    public var spacing: CGFloat
    @ViewBuilder public var content: () -> Content

    public init(alignment: Alignment = .leading,
                spacing: CGFloat = Tokens.ResourceCard.padding,
                @ViewBuilder content: @escaping () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        HStack(spacing: spacing) { content() }
            .frame(maxWidth: .infinity,
                   alignment: alignment == .leading ? .leading : .trailing)
    }
}

/// A horizontal group for content in a card widget band.
public struct ResourceCardWidgetGroup<Content: View>: View {
    public var spacing: CGFloat
    @ViewBuilder public var content: () -> Content

    public init(spacing: CGFloat = Tokens.ResourceCard.padding,
                @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        HStack(spacing: spacing) {
            content()
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A reusable footer band with a left group, right group, and optional widget stacked above them.
public struct ResourceCardFooter<Leading: View, Trailing: View, Widget: View>: View {
    public var showWidget: Bool
    public var actionsVisible: Bool
    public var spacing: CGFloat
    public var horizontalPadding: CGFloat
    public var topPadding: CGFloat
    public var bottomPadding: CGFloat
    @ViewBuilder public var leading: () -> Leading
    @ViewBuilder public var trailing: () -> Trailing
    @ViewBuilder public var widget: () -> Widget

    public init(showWidget: Bool = false,
                actionsVisible: Bool = true,
                spacing: CGFloat = Tokens.ResourceCard.padding,
                horizontalPadding: CGFloat = Tokens.ResourceCard.padding,
                topPadding: CGFloat = 0,
                bottomPadding: CGFloat = Tokens.ResourceCard.padding,
                @ViewBuilder leading: @escaping () -> Leading,
                @ViewBuilder trailing: @escaping () -> Trailing,
                @ViewBuilder widget: @escaping () -> Widget) {
        self.showWidget = showWidget
        self.actionsVisible = actionsVisible
        self.spacing = spacing
        self.horizontalPadding = horizontalPadding
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.leading = leading
        self.trailing = trailing
        self.widget = widget
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showWidget {
                widget()
            }
            HStack(spacing: spacing) {
                ResourceCardFooterGroup(alignment: .leading, spacing: spacing) {
                    leading()
                }
                ResourceCardFooterGroup(alignment: .trailing, spacing: spacing) {
                    trailing()
                }
                .opacity(actionsVisible ? 1 : 0)
                .allowsHitTesting(actionsVisible)
                .animation(.easeOut(duration: 0.18), value: actionsVisible)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct ResourceCardTitleText: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.callout.weight(.medium))
            .lineLimit(1)
    }
}

public struct ResourceCardSubtitleText: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

public struct ResourceCardMonospacedSubtitleText: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

public struct ResourceCardMonospacedTitleText: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.system(.callout, design: .monospaced).weight(.medium))
            .lineLimit(1)
    }
}

public struct ResourceCardIconChip: View {
    public var symbol: String
    public var tint: Color
    public var symbolFont: Font
    public var backgroundOpacity: Double

    public init(symbol: String,
                tint: Color = .secondary,
                symbolFont: Font = .title3,
                backgroundOpacity: Double = Tokens.ResourceCard.iconBackgroundOpacity) {
        self.symbol = symbol
        self.tint = tint
        self.symbolFont = symbolFont
        self.backgroundOpacity = backgroundOpacity
    }

    public var body: some View {
        Image(systemName: symbol)
            .font(symbolFont)
            .foregroundStyle(tint)
            .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
            .background(tint.opacity(backgroundOpacity),
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.iconChip, style: .continuous))
    }
}

/// Small capsule count/state badge used in section headers and compact metadata rows.
public struct ResourceBadgeText: View {
    public let text: String
    public var font: Font
    public var foreground: Color

    public init(text: String,
                font: Font = .caption.weight(.medium),
                foreground: Color = .secondary) {
        self.text = text
        self.font = font
        self.foreground = foreground
    }

    public var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(foreground)
            .padding(.horizontal, Tokens.Space.s)
            .padding(.vertical, Tokens.Badge.verticalPadding)
            .background(.quaternary, in: Capsule())
    }
}

/// Flat glass row for selectable lists inside panels and sheets.
public struct GlassListRow<Accessory: View>: View {
    public var symbol: String
    public var tint: Color
    public var title: String
    public var subtitle: String?
    public var monospacedSubtitle: Bool
    @ViewBuilder public var accessory: () -> Accessory

    public init(symbol: String,
                tint: Color = .accentColor,
                title: String,
                subtitle: String?,
                monospacedSubtitle: Bool = true,
                @ViewBuilder accessory: @escaping () -> Accessory) {
        self.symbol = symbol
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.monospacedSubtitle = monospacedSubtitle
        self.accessory = accessory
    }

    public var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: symbol)
                .font(.callout)
                .foregroundStyle(tint)
                .frame(width: Tokens.IconSize.rowMenu)
            VStack(alignment: .leading, spacing: Tokens.ResourceCard.compactTextSpacing) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(monospacedSubtitle ? .system(.caption, design: .monospaced) : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Tokens.Space.s)
            accessory()
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .glassSurface(.ultraThin, cornerRadius: Tokens.Radius.control)
    }
}

public struct GlassListRowChevron: View {
    public init() {}

    public var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
}

public extension GlassListRow where Accessory == GlassListRowChevron {
    init(symbol: String, tint: Color = .accentColor, title: String, subtitle: String?,
         monospacedSubtitle: Bool = true) {
        self.init(symbol: symbol,
                  tint: tint,
                  title: title,
                  subtitle: subtitle,
                  monospacedSubtitle: monospacedSubtitle) {
            GlassListRowChevron()
        }
    }
}

public struct ResourceCardMetricText: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}

public extension View {
    @ViewBuilder
    func resourceCardFloatingControls<Controls: View>(
        when isVisible: Bool,
        @ViewBuilder controls: @escaping () -> Controls
    ) -> some View {
        overlay(alignment: .topTrailing) {
            if isVisible {
                controls()
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(Tokens.Space.s)
                    .zIndex(1)
            }
        }
    }

    @ViewBuilder
    func resourceCardProgressOverlay(when isBusy: Bool) -> some View {
        overlay {
            if isBusy {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}

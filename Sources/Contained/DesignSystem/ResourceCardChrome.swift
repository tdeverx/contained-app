import SwiftUI

/// A reusable three-part card header: leading accessory, fill/truncate text block, and trailing
/// button rail. This keeps the container/image cards using the same top-aligned chrome structure.
struct ResourceCardHeader<Leading: View, Content: View, Trailing: View>: View {
    var spacing: CGFloat = 10
    var padding: CGFloat = 10
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var content: () -> Content
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
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
struct ResourceCardFooterMini<Icon: View, TextContent: View>: View {
    var spacing: CGFloat = 4
    @ViewBuilder var icon: () -> Icon
    @ViewBuilder var text: () -> TextContent

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            icon()
            text()
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// A reusable footer item band that hugs its content and anchors either left or right.
struct ResourceCardFooterGroup<Content: View>: View {
    enum Alignment {
        case leading, trailing
    }

    var alignment: Alignment = .leading
    var spacing: CGFloat = 10
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: spacing) { content() }
            .frame(maxWidth: .infinity,
                   alignment: alignment == .leading ? .leading : .trailing)
    }
}

/// A reusable footer band with a left group, right group, and optional widget stacked above them.
struct ResourceCardFooter<Leading: View, Trailing: View, Widget: View>: View {
    var showWidget: Bool = false
    var actionsVisible: Bool = true
    var spacing: CGFloat = 10
    var horizontalPadding: CGFloat = 10
    var topPadding: CGFloat = 0
    var bottomPadding: CGFloat = 10
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var widget: () -> Widget

    var body: some View {
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
    }
}

struct ResourceCardTitleText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout.weight(.medium))
            .lineLimit(1)
    }
}

struct ResourceCardSubtitleText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

struct ResourceCardMonospacedSubtitleText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

struct ResourceCardMonospacedTitleText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.callout, design: .monospaced).weight(.medium))
            .lineLimit(1)
    }
}

struct ResourceCardIconChip: View {
    var symbol: String
    var tint: Color = .secondary
    var symbolFont: Font = .title3
    var backgroundOpacity: Double = 0.16

    var body: some View {
        Image(systemName: symbol)
            .font(symbolFont)
            .foregroundStyle(tint)
            .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
            .background(tint.opacity(backgroundOpacity), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// Small capsule count/state badge used in section headers and compact metadata rows.
struct ResourceBadgeText: View {
    let text: String
    var font: Font = .caption.weight(.medium)
    var foreground: Color = .secondary

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(foreground)
            .padding(.horizontal, Tokens.Space.s)
            .padding(.vertical, Tokens.Space.xs / 2)
            .background(.quaternary, in: Capsule())
    }
}

/// Flat glass row for selectable lists inside panels and sheets.
struct GlassListRow<Accessory: View>: View {
    var symbol: String
    var tint: Color = .accentColor
    var title: String
    var subtitle: String?
    var monospacedSubtitle = true
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: symbol)
                .font(.callout)
                .foregroundStyle(tint)
                .frame(width: Tokens.IconSize.rowMenu)
            VStack(alignment: .leading, spacing: 1) {
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

struct GlassListRowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
}

extension GlassListRow where Accessory == GlassListRowChevron {
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

struct ResourceCardMetricText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .monospacedDigit()
    }
}

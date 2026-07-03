import SwiftUI

/// A reusable three-part card header: leading accessory, fill/truncate text block, and trailing
/// button rail. This keeps the container/image cards using the same top-aligned chrome structure.
struct CardHeader<Leading: View, Content: View, Trailing: View>: View {
    var spacing: CGFloat
    var padding: CGFloat
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var content: () -> Content
    @ViewBuilder var trailing: () -> Trailing

    init(spacing: CGFloat = UI.Tokens.Card.padding,
         padding: CGFloat = UI.Tokens.Card.padding,
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
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .transaction { transaction in
                    transaction.animation = nil
                }
            trailing()
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
        }
        .padding(padding)
    }
}

/// Stable title/subtitle lane for `CardHeader`.
///
/// Use this for card header text so the title and metadata stay anchored to the leading chip while
/// expanded-card controls appear, disappear, or change page selection.
struct CardHeaderTextBlock<Title: View, Subtitle: View>: View {
    var spacing: CGFloat
    @ViewBuilder var title: () -> Title
    @ViewBuilder var subtitle: () -> Subtitle

    init(spacing: CGFloat = UI.Tokens.Card.compactTextSpacing,
         @ViewBuilder title: @escaping () -> Title,
         @ViewBuilder subtitle: @escaping () -> Subtitle) {
        self.spacing = spacing
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            title()
            subtitle()
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}

extension CardHeaderTextBlock where Subtitle == EmptyView {
    init(spacing: CGFloat = UI.Tokens.Card.compactTextSpacing,
         @ViewBuilder title: @escaping () -> Title) {
        self.init(spacing: spacing, title: title) {
            EmptyView()
        }
    }
}

public extension UI.Card {
/// A small reusable footer mini: optional icon + optional text, aligned on one baseline.
struct FooterMini<Icon: View, TextContent: View>: View {
    public var spacing: CGFloat
    @ViewBuilder public var icon: () -> Icon
    @ViewBuilder public var text: () -> TextContent

    public init(spacing: CGFloat = UI.Tokens.Space.xs,
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

/// A flat inset section for content that lives inside an expanded `UI.Card.Scaffold`.
///
/// Use this for charts, process lists, read-only fields, and terminal overlays inside a card body.
/// It intentionally avoids creating a second card-shaped glass surface inside the parent card.
struct InsetSection<Content: View>: View {
    public var title: String?
    public var alignment: HorizontalAlignment
    public var spacing: CGFloat
    public var padding: CGFloat
    @ViewBuilder public var content: () -> Content

    public init(title: String? = nil,
                alignment: HorizontalAlignment = .leading,
                spacing: CGFloat = UI.Tokens.Space.s,
                padding: CGFloat = UI.Tokens.Space.s,
                @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.alignment = alignment
        self.spacing = spacing
        self.padding = padding
        self.content = content
    }

    public var body: some View {
        VStack(alignment: alignment, spacing: UI.Tokens.Space.s) {
            if let title {
                Text(title)
                    .font(.headline)
                    .padding(.leading, UI.Tokens.Space.xs)
            }
            LazyVStack(alignment: alignment, spacing: spacing) {
                content()
            }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
            .background(UI.Theme.Material.toolbarHoverFill,
                        in: RoundedRectangle(cornerRadius: UI.Tokens.Radius.control,
                                             style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }
}

/// A selectable footer chip for card widgets, filters, and compact tab-like metadata.
struct FooterChip<Icon: View, TextContent: View>: View {
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
            FooterMini {
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

/// Shared icon-only action used by design-card footers.
struct FooterButton: View {
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
            FooterMini {
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

struct Page<ID: Hashable>: Identifiable, Hashable {
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
struct CardPageControls<ID: Hashable>: View {
    var items: [Page<ID>]
    var selection: ID
    var tint: Color
    var controlsReveal: Double
    var closeLabel: String
    var onSelect: (ID) -> Void
    var onClose: () -> Void

    init(items: [Page<ID>],
         selection: ID,
         tint: Color,
         controlsReveal: Double = 1,
         closeLabel: String,
         onSelect: @escaping (ID) -> Void,
         onClose: @escaping () -> Void) {
        self.items = items
        self.selection = selection
        self.tint = tint
        self.controlsReveal = controlsReveal
        self.closeLabel = closeLabel
        self.onSelect = onSelect
        self.onClose = onClose
    }

    public var body: some View {
        MaterialButton(singleItem: false) {
            ForEach(items) { item in
                MaterialButtonItem(tint: selection == item.id ? tint : nil,
                                help: item.title,
                                isIcon: true,
                                action: { onSelect(item.id) }) {
                    Image(systemName: item.systemImage)
                        .opacity(selection == item.id ? 1 : 0.62)
                }
            }
            MaterialButtonItem(systemName: "xmark", help: closeLabel, action: onClose)
        }
        .opacity(controlsReveal)
        .allowsHitTesting(controlsReveal > 0.01)
        .animation(.easeOut(duration: 0.18), value: controlsReveal)
    }
}

/// A reusable footer item band that hugs its content and anchors either left or right.
struct FooterGroup<Content: View>: View {
    public enum Alignment {
        case leading, trailing
    }

    public var alignment: Alignment
    public var spacing: CGFloat
    @ViewBuilder public var content: () -> Content

    public init(alignment: Alignment = .leading,
                spacing: CGFloat = UI.Tokens.Card.padding,
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
struct WidgetGroup<Content: View>: View {
    public var spacing: CGFloat
    @ViewBuilder public var content: () -> Content

    public init(spacing: CGFloat = UI.Tokens.Card.padding,
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
struct CardFooter<Leading: View, Trailing: View, Widget: View>: View {
    var showWidget: Bool
    var actionsVisible: Bool
    var spacing: CGFloat
    var horizontalPadding: CGFloat
    var topPadding: CGFloat
    var bottomPadding: CGFloat
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var widget: () -> Widget

    init(showWidget: Bool = false,
         actionsVisible: Bool = true,
         spacing: CGFloat = UI.Tokens.Card.padding,
         horizontalPadding: CGFloat = UI.Tokens.Card.padding,
         topPadding: CGFloat = 0,
         bottomPadding: CGFloat = UI.Tokens.Card.padding,
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
                FooterGroup(alignment: .leading, spacing: spacing) {
                    leading()
                }
                FooterGroup(alignment: .trailing, spacing: spacing) {
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

struct TitleText: View {
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

struct SubtitleText: View {
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

struct MonospacedSubtitleText: View {
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

struct MonospacedTitleText: View {
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

struct IconChip: View {
    public var symbol: String
    public var tint: Color
    public var symbolFont: Font
    public var backgroundOpacity: Double

    public init(symbol: String,
                tint: Color = .secondary,
                symbolFont: Font = .title3,
                backgroundOpacity: Double = UI.Tokens.Card.iconBackgroundOpacity) {
        self.symbol = symbol
        self.tint = tint
        self.symbolFont = symbolFont
        self.backgroundOpacity = backgroundOpacity
    }

    public var body: some View {
        Image(systemName: symbol)
            .font(symbolFont)
            .foregroundStyle(tint)
            .frame(width: UI.Tokens.IconSize.chip, height: UI.Tokens.IconSize.chip)
            .background(tint.opacity(backgroundOpacity),
                        in: RoundedRectangle(cornerRadius: UI.Tokens.Radius.iconChip, style: .continuous))
    }
}
}

/// Small capsule count/state badge used in section headers and compact metadata rows.
public extension UI.Badge {
struct Text: View {
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
        SharedCapsuleLabel(horizontalPadding: UI.Tokens.Space.s,
                           verticalPadding: UI.Tokens.Badge.verticalPadding,
                           foreground: AnyShapeStyle(foreground),
                           fill: AnyShapeStyle(.quaternary)) {
            SwiftUI.Text(text)
                .font(font)
        }
    }
}
}

/// Flat selectable row for lists inside panels and sheets.
public extension UI.List {
struct Row<Accessory: View>: View {
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
        SharedIconTextRow(systemImage: symbol,
                          tint: tint,
                          iconWidth: UI.Tokens.IconSize.rowMenu,
                          rowSpacing: UI.Tokens.Space.s,
                          subtitle: subtitle,
                          subtitleMonospaced: monospacedSubtitle,
                          horizontalPadding: UI.Tokens.Space.m,
                          fillsWidth: true) {
            Text(title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
        } accessory: {
            accessory()
        }
        .materialSurface(.ultraThin, cornerRadius: UI.Tokens.Radius.control)
    }
}

struct RowChevron: View {
    public init() {}

    public var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
}
}

public extension UI.List.Row where Accessory == UI.List.RowChevron {
    init(symbol: String, tint: Color = .accentColor, title: String, subtitle: String?,
         monospacedSubtitle: Bool = true) {
        self.init(symbol: symbol,
                  tint: tint,
                  title: title,
                  subtitle: subtitle,
                  monospacedSubtitle: monospacedSubtitle) {
            UI.List.RowChevron()
        }
    }
}

public extension UI.Card {
struct MetricText: View {
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
}

public extension View {
    @ViewBuilder
    func designCardFloatingControls<Controls: View>(
        when isVisible: Bool,
        @ViewBuilder controls: @escaping () -> Controls
    ) -> some View {
        overlay(alignment: .topTrailing) {
            if isVisible {
                controls()
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(UI.Tokens.Space.s)
                    .zIndex(1)
            }
        }
    }

    @ViewBuilder
    func designCardProgressOverlay(when isBusy: Bool) -> some View {
        overlay {
            if isBusy {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}

#Preview("Card Chrome") {
    VStack(alignment: .leading, spacing: UI.Tokens.Space.l) {
        CardHeader {
            UI.Card.IconChip(symbol: "shippingbox.fill", tint: .accentColor)
        } content: {
            CardHeaderTextBlock {
                UI.Card.TitleText(text: "preview-web")
            } subtitle: {
                UI.Card.MonospacedSubtitleText(text: "sha256:preview")
            }
        } trailing: {
            UI.Card.CardPageControls(items: [
                UI.Card.Page(id: "overview", title: "Overview", systemImage: "rectangle.grid.1x2"),
                UI.Card.Page(id: "logs", title: "Logs", systemImage: "doc.text"),
            ],
            selection: "overview",
            tint: .accentColor,
            closeLabel: "Close",
            onSelect: { _ in },
            onClose: {})
        }
        .materialSurface(.regular, cornerRadius: UI.Tokens.Radius.card)

        UI.Card.InsetSection(title: "Metadata") {
            UI.List.Row(symbol: "network",
                        tint: .teal,
                        title: "bridge",
                        subtitle: "10.42.0.0/24")
        }

        UI.Card.CardFooter {
            UI.Card.FooterChip(isSelected: true, tint: .accentColor, help: "CPU", action: {}) {
                Image(systemName: "cpu")
            } text: {
                UI.Card.MetricText(text: "42%")
            }
        } trailing: {
            UI.Card.FooterButton(systemName: "stop.fill", help: "Stop", tint: .red) {}
        } widget: {
            UI.Card.WidgetGroup {
                UI.Card.FooterMini {
                    Image(systemName: "memorychip")
                } text: {
                    UI.Card.MetricText(text: "420 MB")
                }
            }
            .padding(.horizontal, UI.Tokens.Card.padding)
        }
        .materialSurface(.regular, cornerRadius: UI.Tokens.Radius.card)
    }
    .padding(UI.Tokens.Space.xl)
    .frame(width: 520)
    .environment(\.buttonMaterial, .glassClear)
}

import SwiftUI

public extension UI.Card {
/// Text rendering style for the built-in `UI.Card.Scaffold` title and subtitle lanes.
enum TextStyle {
    case standard
    case monospaced
}

/// Sentinel page type used by `UI.Card.Scaffold` when a card has no page controls.
enum NoPage: Hashable {
    case none
}

/// Typed page-control configuration for `UI.Card.Scaffold`.
struct Pages<ID: Hashable> {
    public var items: [UI.Card.Page<ID>]
    public var selection: ID
    public var tint: Color
    public var controlsReveal: Double
    public var closeLabel: String
    public var onSelect: (ID) -> Void
    public var onClose: () -> Void

    public init(items: [UI.Card.Page<ID>],
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
}

/// Source-of-truth design card API.
///
/// Feature code supplies semantic title/subtitle data plus optional slots; this view owns how those
/// inputs become sticky header chrome, expanded body content, widgets, and footer controls.
struct Scaffold<Icon: View, TitleAccessory: View, SubtitleAccessory: View,
                HeaderAccessory: View, BodyContent: View, FooterLeading: View,
                FooterActions: View, Widget: View, PageID: Hashable>: View {
    public var size: UI.Card.Size
    public var isExpanded: Bool
    public var expansionPresented: Bool?
    public var contentSizing: UI.Card.ContentSizing
    public var cornerRadiusOverride: CGFloat?
    public var headerAlignment: VerticalAlignment
    public var headerPadding: CGFloat
    public var overlaysHeaderTrailing: Bool?
    public var headerTrailingOverlayPadding: CGFloat?
    public var controlsVisible: Bool
    public var isSelected: Bool
    public var showsFooter: Bool
    public var showsWidget: Bool
    public var fill: Color?
    public var fillOpacity: Double
    public var gradient: Bool
    public var gradientAngle: Double
    public var blendMode: UI.Theme.ColorBlendMode
    public var elevated: Bool
    public var onTap: () -> Void
    public var title: String
    public var subtitle: String?
    public var titleStyle: UI.Card.TextStyle
    public var subtitleStyle: UI.Card.TextStyle
    public var pages: UI.Card.Pages<PageID>?
    @ViewBuilder public var icon: () -> Icon
    @ViewBuilder public var titleAccessory: () -> TitleAccessory
    @ViewBuilder public var subtitleAccessory: () -> SubtitleAccessory
    @ViewBuilder public var headerAccessory: () -> HeaderAccessory
    @ViewBuilder public var bodyContent: () -> BodyContent
    @ViewBuilder public var footerLeading: () -> FooterLeading
    @ViewBuilder public var footerActions: () -> FooterActions
    @ViewBuilder public var widget: () -> Widget
    public var persistentFooterActions: AnyView?

    private var usesSelectionFill = false
    private var usesCompactMutedPresentation = false

    public init(size: UI.Card.Size = .small,
                isExpanded: Bool = false,
                expansionPresented: Bool? = nil,
                contentSizing: UI.Card.ContentSizing = .fill,
                cornerRadiusOverride: CGFloat? = nil,
                headerAlignment: VerticalAlignment = .top,
                headerPadding: CGFloat = UI.Card.Padding.content,
                overlaysHeaderTrailing: Bool? = nil,
                headerTrailingOverlayPadding: CGFloat? = nil,
                controlsVisible: Bool = true,
                isSelected: Bool = false,
                showsFooter: Bool = true,
                showsWidget: Bool = true,
                fill: Color? = nil,
                fillOpacity: Double = 0.18,
                gradient: Bool = false,
                gradientAngle: Double = 135,
                blendMode: UI.Theme.ColorBlendMode = .softLight,
                elevated: Bool = true,
                onTap: @escaping () -> Void = {},
                persistentFooterActions: AnyView? = nil,
                title: String,
                subtitle: String? = nil,
                titleStyle: UI.Card.TextStyle = .standard,
                subtitleStyle: UI.Card.TextStyle = .standard,
                pages: UI.Card.Pages<PageID>?,
                @ViewBuilder icon: @escaping () -> Icon,
                @ViewBuilder titleAccessory: @escaping () -> TitleAccessory,
                @ViewBuilder subtitleAccessory: @escaping () -> SubtitleAccessory,
                @ViewBuilder headerAccessory: @escaping () -> HeaderAccessory,
                @ViewBuilder bodyContent: @escaping () -> BodyContent,
                @ViewBuilder footerLeading: @escaping () -> FooterLeading,
                @ViewBuilder footerActions: @escaping () -> FooterActions,
                @ViewBuilder widget: @escaping () -> Widget) {
        self.size = size
        self.isExpanded = isExpanded
        self.expansionPresented = expansionPresented
        self.contentSizing = contentSizing
        self.cornerRadiusOverride = cornerRadiusOverride
        self.headerAlignment = headerAlignment
        self.headerPadding = headerPadding
        self.overlaysHeaderTrailing = overlaysHeaderTrailing
        self.headerTrailingOverlayPadding = headerTrailingOverlayPadding
        self.controlsVisible = controlsVisible
        self.isSelected = isSelected
        self.showsFooter = showsFooter
        self.showsWidget = showsWidget
        self.fill = fill
        self.fillOpacity = fillOpacity
        self.gradient = gradient
        self.gradientAngle = gradientAngle
        self.blendMode = blendMode
        self.elevated = elevated
        self.onTap = onTap
        self.persistentFooterActions = persistentFooterActions
        self.title = title
        self.subtitle = subtitle
        self.titleStyle = titleStyle
        self.subtitleStyle = subtitleStyle
        self.pages = pages
        self.icon = icon
        self.titleAccessory = titleAccessory
        self.subtitleAccessory = subtitleAccessory
        self.headerAccessory = headerAccessory
        self.bodyContent = bodyContent
        self.footerLeading = footerLeading
        self.footerActions = footerActions
        self.widget = widget
    }

    public func selectionFill(_ on: Bool = true) -> Self {
        var copy = self
        copy.usesSelectionFill = on
        return copy
    }

    /// Desaturate and soften compact card contents until hover. Expanded cards always render at
    /// full emphasis, keeping detail content readable regardless of the supplied state.
    public func compactMuted(_ on: Bool = true) -> Self {
        var copy = self
        copy.usesCompactMutedPresentation = on
        return copy
    }

    public var body: some View {
        CardSurface(size: size,
                          isExpanded: isExpanded,
                          expansionPresented: expansionPresented,
                          contentSizing: contentSizing,
                          cornerRadiusOverride: cornerRadiusOverride,
                          controlsVisible: controlsVisible,
                          isSelected: isSelected,
                          compactMuted: usesCompactMutedPresentation,
                          showsFooter: showsFooter,
                          showsWidget: showsWidget,
                          fill: fill,
                          fillOpacity: fillOpacity,
                          gradient: gradient,
                          gradientAngle: gradientAngle,
                          blendMode: blendMode,
                          elevated: elevated,
                          onTap: onTap,
                          persistentFooterActions: persistentFooterActions) {
            header
        } bodyContent: {
            bodyContent()
        } footerLeading: {
            footerLeading()
        } footerActions: {
            footerActions()
        } widget: {
            widget()
        }
        .selectionFill(usesSelectionFill)
    }

    private var header: some View {
        CardHeader(alignment: headerAlignment,
                   padding: headerPadding,
                   overlaysTrailing: overlaysHeaderTrailing ?? isExpanded,
                   trailingOverlayPadding: headerTrailingOverlayPadding ?? expandedHeaderOverlayPadding) {
            icon()
        } content: {
            CardHeaderTextBlock {
                HStack(spacing: UI.Tokens.Space.s) {
                    titleText
                    titleAccessory()
                }
            } subtitle: {
                if hasSubtitleRow {
                    HStack(spacing: UI.Tokens.Space.xs) {
                        subtitleAccessory()
                        if let subtitle, !subtitle.isEmpty {
                            subtitleText(subtitle)
                        }
                    }
                }
            }
        } trailing: {
            HStack(spacing: UI.Tokens.Space.s) {
                if let pages {
                    CardPageControls(items: pages.items,
                                             selection: pages.selection,
                                             tint: pages.tint,
                                             controlsReveal: pages.controlsReveal,
                                             closeLabel: pages.closeLabel,
                                             onSelect: pages.onSelect,
                                             onClose: pages.onClose)
                }
                headerAccessory()
            }
        }
    }

    @ViewBuilder
    private var titleText: some View {
        switch titleStyle {
        case .standard:
            UI.Card.TitleText(text: title)
        case .monospaced:
            UI.Card.MonospacedTitleText(text: title)
        }
    }

    @ViewBuilder
    private func subtitleText(_ text: String) -> some View {
        switch subtitleStyle {
        case .standard:
            UI.Card.SubtitleText(text: text)
        case .monospaced:
            UI.Card.MonospacedSubtitleText(text: text)
        }
    }

    private var hasSubtitleRow: Bool {
        (subtitle?.isEmpty == false) || SubtitleAccessory.self != EmptyView.self
    }

    private var expandedHeaderOverlayPadding: CGFloat? {
        isExpanded ? UI.Panel.Padding.compact : nil
    }
}
}

public extension UI.Card.Scaffold where PageID == UI.Card.NoPage {
    init(size: UI.Card.Size = .small,
         isExpanded: Bool = false,
         expansionPresented: Bool? = nil,
         contentSizing: UI.Card.ContentSizing = .fill,
         cornerRadiusOverride: CGFloat? = nil,
         headerAlignment: VerticalAlignment = .top,
         headerPadding: CGFloat = UI.Card.Padding.content,
         overlaysHeaderTrailing: Bool? = nil,
         headerTrailingOverlayPadding: CGFloat? = nil,
         controlsVisible: Bool = true,
         isSelected: Bool = false,
         showsFooter: Bool = true,
         showsWidget: Bool = true,
         fill: Color? = nil,
         fillOpacity: Double = 0.18,
         gradient: Bool = false,
         gradientAngle: Double = 135,
         blendMode: UI.Theme.ColorBlendMode = .softLight,
         elevated: Bool = true,
         onTap: @escaping () -> Void = {},
         persistentFooterActions: AnyView? = nil,
         title: String,
         subtitle: String? = nil,
         titleStyle: UI.Card.TextStyle = .standard,
         subtitleStyle: UI.Card.TextStyle = .standard,
         @ViewBuilder icon: @escaping () -> Icon,
         @ViewBuilder titleAccessory: @escaping () -> TitleAccessory,
         @ViewBuilder subtitleAccessory: @escaping () -> SubtitleAccessory,
         @ViewBuilder headerAccessory: @escaping () -> HeaderAccessory,
         @ViewBuilder bodyContent: @escaping () -> BodyContent,
         @ViewBuilder footerLeading: @escaping () -> FooterLeading,
         @ViewBuilder footerActions: @escaping () -> FooterActions,
         @ViewBuilder widget: @escaping () -> Widget) {
        self.init(size: size,
                  isExpanded: isExpanded,
                  expansionPresented: expansionPresented,
                  contentSizing: contentSizing,
                  cornerRadiusOverride: cornerRadiusOverride,
                  headerAlignment: headerAlignment,
                  headerPadding: headerPadding,
                  overlaysHeaderTrailing: overlaysHeaderTrailing,
                  headerTrailingOverlayPadding: headerTrailingOverlayPadding,
                  controlsVisible: controlsVisible,
                  isSelected: isSelected,
                  showsFooter: showsFooter,
                  showsWidget: showsWidget,
                  fill: fill,
                  fillOpacity: fillOpacity,
                  gradient: gradient,
                  gradientAngle: gradientAngle,
                  blendMode: blendMode,
                  elevated: elevated,
                  onTap: onTap,
                  persistentFooterActions: persistentFooterActions,
                  title: title,
                  subtitle: subtitle,
                  titleStyle: titleStyle,
                  subtitleStyle: subtitleStyle,
                  pages: nil,
                  icon: icon,
                  titleAccessory: titleAccessory,
                  subtitleAccessory: subtitleAccessory,
                  headerAccessory: headerAccessory,
                  bodyContent: bodyContent,
                  footerLeading: footerLeading,
                  footerActions: footerActions,
                  widget: widget)
    }
}

#Preview("Card Scaffold") {
    DesignCardScaffoldPreview()
        .padding(UI.Tokens.Space.xl)
        .frame(width: 420)
        .environment(\.cardMaterial, .glassRegular)
        .environment(\.buttonMaterial, .glassClear)
}

private struct DesignCardScaffoldPreview: View {
    @State private var page = "overview"

    private let pages = [
        UI.Card.Page(id: "overview", title: "Overview", systemImage: "rectangle.grid.1x2"),
        UI.Card.Page(id: "stats", title: "Stats", systemImage: "chart.xyaxis.line"),
    ]

    var body: some View {
        UI.Card.Scaffold(size: .large,
                         isExpanded: true,
                         title: "preview-web",
                         subtitle: "docker.io/library/nginx:latest",
                         pages: UI.Card.Pages(items: pages,
                                              selection: page,
                                              tint: .accentColor,
                                              closeLabel: "Close",
                                              onSelect: { page = $0 },
                                              onClose: {})) {
            UI.Card.IconChip(symbol: "shippingbox.fill", tint: .accentColor)
        } titleAccessory: {
            UI.Badge.Text(text: "Running")
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            EmptyView()
        } bodyContent: {
            UI.Card.InsetSection(title: "Live") {
                UI.Chart.Sparkline(samples: [0.1, 0.2, 0.18, 0.4, 0.34, 0.55],
                                   color: .accentColor,
                                   scale: .fraction)
                    .frame(height: UI.Tokens.Card.sparklineHeight)
            }
        } footerLeading: {
            UI.Card.FooterChip(isSelected: true, tint: .accentColor, help: "CPU", action: {}) {
                Image(systemName: "cpu")
            } text: {
                UI.Card.MetricText(text: "42%")
            }
        } footerActions: {
            UI.Card.FooterButton(systemName: "play.fill", help: "Start", tint: .accentColor) {}
        } widget: {
            UI.Card.WidgetGroup {
                UI.Card.FooterMini {
                    Image(systemName: "memorychip")
                } text: {
                    UI.Card.MetricText(text: "420 MB")
                }
            }
        }
    }
}

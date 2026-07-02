import SwiftUI

/// Text rendering style for the built-in `ResourceCard` title and subtitle lanes.
public enum ResourceCardTextStyle {
    case standard
    case monospaced
}

/// Sentinel page type used by `ResourceCard` when a card has no page controls.
public enum ResourceCardNoPage: Hashable {
    case none
}

/// Typed page-control configuration for `ResourceCard`.
public struct ResourceCardPages<ID: Hashable> {
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
}

/// Source-of-truth resource card API.
///
/// Feature code supplies semantic title/subtitle data plus optional slots; this view owns how those
/// inputs become sticky header chrome, expanded body content, widgets, and footer controls.
public struct ResourceCard<Icon: View, TitleAccessory: View, SubtitleAccessory: View,
                           HeaderAccessory: View, BodyContent: View, FooterLeading: View,
                           FooterActions: View, Widget: View, PageID: Hashable>: View {
    public var size: ResourceCardSize
    public var isExpanded: Bool
    public var cornerRadiusOverride: CGFloat?
    public var controlsVisible: Bool
    public var isSelected: Bool
    public var showsFooter: Bool
    public var showsWidget: Bool
    public var fill: Color?
    public var fillOpacity: Double
    public var gradient: Bool
    public var gradientAngle: Double
    public var blendMode: ColorLayerBlendMode
    public var elevated: Bool
    public var onTap: () -> Void
    public var title: String
    public var subtitle: String?
    public var titleStyle: ResourceCardTextStyle
    public var subtitleStyle: ResourceCardTextStyle
    public var pages: ResourceCardPages<PageID>?
    @ViewBuilder public var icon: () -> Icon
    @ViewBuilder public var titleAccessory: () -> TitleAccessory
    @ViewBuilder public var subtitleAccessory: () -> SubtitleAccessory
    @ViewBuilder public var headerAccessory: () -> HeaderAccessory
    @ViewBuilder public var bodyContent: () -> BodyContent
    @ViewBuilder public var footerLeading: () -> FooterLeading
    @ViewBuilder public var footerActions: () -> FooterActions
    @ViewBuilder public var widget: () -> Widget

    private var usesSelectionFill = false

    public init(size: ResourceCardSize = .small,
                isExpanded: Bool = false,
                cornerRadiusOverride: CGFloat? = nil,
                controlsVisible: Bool = true,
                isSelected: Bool = false,
                showsFooter: Bool = true,
                showsWidget: Bool = true,
                fill: Color? = nil,
                fillOpacity: Double = 0.18,
                gradient: Bool = false,
                gradientAngle: Double = 135,
                blendMode: ColorLayerBlendMode = .softLight,
                elevated: Bool = true,
                onTap: @escaping () -> Void = {},
                title: String,
                subtitle: String? = nil,
                titleStyle: ResourceCardTextStyle = .standard,
                subtitleStyle: ResourceCardTextStyle = .standard,
                pages: ResourceCardPages<PageID>?,
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
        self.cornerRadiusOverride = cornerRadiusOverride
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

    public var body: some View {
        ResourceGlassCard(size: size,
                          isExpanded: isExpanded,
                          cornerRadiusOverride: cornerRadiusOverride,
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
                          onTap: onTap) {
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
        ResourceCardHeader {
            icon()
        } content: {
            ResourceCardHeaderTextBlock {
                HStack(spacing: Tokens.Space.s) {
                    titleText
                    titleAccessory()
                }
            } subtitle: {
                if hasSubtitleRow {
                    HStack(spacing: Tokens.Space.xs) {
                        subtitleAccessory()
                        if let subtitle, !subtitle.isEmpty {
                            subtitleText(subtitle)
                        }
                    }
                }
            }
        } trailing: {
            HStack(spacing: Tokens.Space.s) {
                if let pages {
                    ResourceCardPageControls(items: pages.items,
                                             selection: pages.selection,
                                             tint: pages.tint,
                                             controlsReveal: pages.controlsReveal,
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
            ResourceCardTitleText(text: title)
        case .monospaced:
            ResourceCardMonospacedTitleText(text: title)
        }
    }

    @ViewBuilder
    private func subtitleText(_ text: String) -> some View {
        switch subtitleStyle {
        case .standard:
            ResourceCardSubtitleText(text: text)
        case .monospaced:
            ResourceCardMonospacedSubtitleText(text: text)
        }
    }

    private var hasSubtitleRow: Bool {
        (subtitle?.isEmpty == false) || SubtitleAccessory.self != EmptyView.self
    }
}

public extension ResourceCard where PageID == ResourceCardNoPage {
    init(size: ResourceCardSize = .small,
         isExpanded: Bool = false,
         cornerRadiusOverride: CGFloat? = nil,
         controlsVisible: Bool = true,
         isSelected: Bool = false,
         showsFooter: Bool = true,
         showsWidget: Bool = true,
         fill: Color? = nil,
         fillOpacity: Double = 0.18,
         gradient: Bool = false,
         gradientAngle: Double = 135,
         blendMode: ColorLayerBlendMode = .softLight,
         elevated: Bool = true,
         onTap: @escaping () -> Void = {},
         title: String,
         subtitle: String? = nil,
         titleStyle: ResourceCardTextStyle = .standard,
         subtitleStyle: ResourceCardTextStyle = .standard,
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
                  cornerRadiusOverride: cornerRadiusOverride,
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

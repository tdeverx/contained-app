import SwiftUI

public extension UI.Card {
enum Size {
    case small, medium, large

    /// Footer actions stay visible in compact/expanded chrome for medium and large cards.
    /// Small cards move footer content into the expanded body so the closed card remains header-only.
    public var keepsFooterSticky: Bool { self != .small }
    /// Widgets stay visible as card chrome only for large cards. Medium cards keep the widget as
    /// part of the expanded body, preserving the simpler closed-card silhouette.
    public var keepsWidgetSticky: Bool { self == .large }
    public var embedsFooterInBody: Bool { self == .small }
    public var embedsWidgetInBody: Bool { self == .medium }

    public var showsFooter: Bool { keepsFooterSticky }
    public var showsWidget: Bool { keepsWidgetSticky }
}

enum ExpandedMetrics {
    public static let maxWidth: CGFloat = 760
}

struct SizePicker: View {
    @Binding var selection: UI.Card.Density
    public var title: String
    public var labelForDensity: (UI.Card.Density) -> String

    public init(selection: Binding<UI.Card.Density>,
                title: String,
                labelForDensity: @escaping (UI.Card.Density) -> String) {
        self._selection = selection
        self.title = title
        self.labelForDensity = labelForDensity
    }

    public var body: some View {
        Picker(title, selection: $selection) {
            ForEach(UI.Card.Density.allCases) { density in
                Text(labelForDensity(density)).tag(density)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 230)
    }
}
}

struct CardSurface<Header: View, BodyContent: View, FooterLeading: View,
                         FooterActions: View, Widget: View>: View {
    var size: UI.Card.Size
    var isExpanded = false
    var cornerRadiusOverride: CGFloat?
    var controlsVisible = true
    var isSelected = false
    var showsFooter = true
    var showsWidget = true
    /// When set, the selected state reads as a soft `white.opacity` wash (matching a hovered glass
    /// button) instead of the 2.5pt accent stroke, useful for dense action rows.
    var usesSelectionFill = false
    var fill: Color?
    var fillOpacity: Double = 0.18
    var gradient: Bool = false
    var gradientAngle: Double = 135
    var blendMode: UI.Theme.ColorBlendMode = .softLight
    /// Lift the card with a shadow. Pass `false` for flat tiles inside an already-elevated panel.
    var elevated: Bool = true
    var onTap: () -> Void = {}
    @ViewBuilder var header: () -> Header
    @ViewBuilder var bodyContent: () -> BodyContent
    @ViewBuilder var footerLeading: () -> FooterLeading
    @ViewBuilder var footerActions: () -> FooterActions
    @ViewBuilder var widget: () -> Widget
    var persistentFooterActions: AnyView?

    @State private var hovering = false
    @Environment(\.cardMaterial) private var cardMaterial

    /// Render the selected state as a soft fill wash instead of the accent stroke.
    func selectionFill(_ on: Bool = true) -> Self {
        var copy = self
        copy.usesSelectionFill = on
        return copy
    }

    init(size: UI.Card.Size,
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
         blendMode: UI.Theme.ColorBlendMode = .softLight,
         elevated: Bool = true,
         onTap: @escaping () -> Void = {},
         persistentFooterActions: AnyView? = nil,
         @ViewBuilder header: @escaping () -> Header,
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
        self.persistentFooterActions = persistentFooterActions
        self.header = header
        self.bodyContent = bodyContent
        self.footerLeading = footerLeading
        self.footerActions = footerActions
        self.widget = widget
    }

    var body: some View {
        surface
            .contentShape(Rectangle())
            .onTapGesture { if !isExpanded { onTap() } }
            .onHover { hovering = $0 }
    }

    private var surface: some View {
        let cornerRadius = cornerRadiusOverride ?? (isExpanded ? UI.Tokens.Radius.sheet : UI.Tokens.Radius.card)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return cardContent
            .frame(maxWidth: isExpanded ? UI.Card.ExpandedMetrics.maxWidth : .infinity,
                   alignment: .leading)
            .clipShape(shape)
            .designCardMaterial(cardMaterial,
                                  cornerRadius: cornerRadius,
                                  shadow: elevated,
                                  fill: fill,
                                  fillOpacity: fillOpacity,
                                  gradient: gradient,
                                  gradientAngle: gradientAngle,
                                  blendMode: blendMode)
            .overlay {
                if isSelected {
                    if usesSelectionFill {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(UI.Theme.Material.toolbarHoverFill)
                    } else {
                        RoundedRectangle(cornerRadius: UI.Tokens.Radius.inset(from: cornerRadius, by: 1),
                                         style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: 2.5)
                            .padding(1)
                    }
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isExpanded)
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: cornerRadiusOverride)
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            stickyHeader
                .layoutPriority(1)
            if isExpanded {
                expandedBody
                    .layoutPriority(0)
            }
            if shouldShowStickyWidget {
                stickyWidget
                    .layoutPriority(1)
            }
            if shouldShowStickyFooter {
                stickyFooter(showActions: isExpanded ? controlsVisible : hovering)
                    .layoutPriority(1)
            }
        }
    }

    private var stickyHeader: some View {
        header()
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            bodyContent()
                .frame(maxWidth: .infinity, alignment: .leading)
            if shouldEmbedWidgetInBody {
                embeddedWidget
            }
            if shouldEmbedFooterInBody {
                stickyFooter(showActions: controlsVisible)
                    .layoutPriority(1)
            }
        }
    }

    private var stickyWidget: some View {
        widgetBand
    }

    private var embeddedWidget: some View {
        widgetBand
    }

    private func stickyFooter(showActions: Bool) -> some View {
        UI.Card.CardFooter(actionsVisible: showActions,
                           persistentTrailing: persistentFooterActions) {
            footerLeading()
        } trailing: {
            footerActions()
        } widget: {
            EmptyView()
        }
    }

    private var widgetBand: some View {
        widget()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, UI.Tokens.Card.padding)
            .padding(.bottom, UI.Tokens.Card.padding)
    }

    private var shouldShowStickyWidget: Bool {
        showsWidget && hasWidgetSlot && size.keepsWidgetSticky
    }

    private var shouldEmbedWidgetInBody: Bool {
        showsWidget && hasWidgetSlot && size.embedsWidgetInBody
    }

    private var shouldShowStickyFooter: Bool {
        showsFooter && hasFooterSlot && size.keepsFooterSticky
    }

    private var shouldEmbedFooterInBody: Bool {
        showsFooter && hasFooterSlot && size.embedsFooterInBody
    }

    private var hasWidgetSlot: Bool {
        Widget.self != EmptyView.self
    }

    private var hasFooterSlot: Bool {
        FooterLeading.self != EmptyView.self
            || FooterActions.self != EmptyView.self
            || persistentFooterActions != nil
    }
}

private struct CardMaterialSurface: ViewModifier {
    var material: UI.Theme.WindowMaterial
    var cornerRadius: CGFloat
    var shadow: Bool
    var fill: Color?
    var fillOpacity: Double
    var gradient: Bool
    var gradientAngle: Double
    var blendMode: UI.Theme.ColorBlendMode
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .clipShape(shape)
            .background {
                if shadow {
                    ExteriorShadow(cornerRadius: cornerRadius,
                                   color: shadowColor,
                                   radius: shadowRadius,
                                   y: shadowY)
                }
            }
            .background {
                ZStack {
                    if let glass = material.glass {
                        Color.clear.glassEffect(glass, in: shape)
                    } else {
                        VisualEffectBackground(material: material, blendingMode: .withinWindow)
                    }

                    fillLayer(shape)
                }
                .clipShape(shape)
                .compositingGroup()
            }
    }

    @ViewBuilder
    private func fillLayer(_ shape: RoundedRectangle) -> some View {
        if let fill {
            shape.fill(SharedSurfaceRendering.fillStyle(color: fill,
                                                        opacity: fillOpacity,
                                                        gradient: gradient,
                                                        gradientAngle: gradientAngle))
                .blendMode(blendMode.blendMode)
                .clipShape(shape)
        }
    }

    private var shadowColor: Color { SharedSurfaceRendering.shadowColor(for: colorScheme) }
    private var shadowRadius: CGFloat { 10 }
    private var shadowY: CGFloat { 4 }
}

public extension View {
    @ViewBuilder
    func designCardSelectionOverlay(when isSelected: Bool) -> some View {
        overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: UI.Tokens.Radius.card, style: .continuous)
                    .fill(UI.Theme.Material.toolbarHoverFill)
                    .allowsHitTesting(false)
            }
        }
    }
}

private extension View {
    func designCardMaterial(_ material: UI.Theme.WindowMaterial,
                              cornerRadius: CGFloat,
                              shadow: Bool,
                              fill: Color?,
                              fillOpacity: Double,
                              gradient: Bool,
                              gradientAngle: Double,
                              blendMode: UI.Theme.ColorBlendMode) -> some View {
        modifier(CardMaterialSurface(material: material,
                                             cornerRadius: cornerRadius,
                                             shadow: shadow,
                                             fill: fill,
                                             fillOpacity: fillOpacity,
                                             gradient: gradient,
                                             gradientAngle: gradientAngle,
                                             blendMode: blendMode))
    }
}

extension CardSurface where BodyContent == EmptyView, FooterLeading == EmptyView,
                                FooterActions == EmptyView, Widget == EmptyView {
    init(size: UI.Card.Size = .small,
         isSelected: Bool = false,
         fill: Color? = nil,
         fillOpacity: Double = 0.18,
         gradient: Bool = false,
         gradientAngle: Double = 135,
         blendMode: UI.Theme.ColorBlendMode = .softLight,
         elevated: Bool = true,
         onTap: @escaping () -> Void = {},
         @ViewBuilder header: @escaping () -> Header) {
        self.init(size: size,
                  isSelected: isSelected,
                  fill: fill,
                  fillOpacity: fillOpacity,
                  gradient: gradient,
                  gradientAngle: gradientAngle,
                  blendMode: blendMode,
                  elevated: elevated,
                  onTap: onTap,
                  header: header,
                  bodyContent: { EmptyView() },
                  footerLeading: { EmptyView() },
                  footerActions: { EmptyView() },
                  widget: { EmptyView() })
    }
}

extension CardSurface where BodyContent == EmptyView, Widget == EmptyView {
    init(size: UI.Card.Size,
         isExpanded: Bool = false,
         controlsVisible: Bool = true,
         isSelected: Bool = false,
         fill: Color? = nil,
         fillOpacity: Double = 0.18,
         gradient: Bool = false,
         gradientAngle: Double = 135,
         blendMode: UI.Theme.ColorBlendMode = .softLight,
         elevated: Bool = true,
         onTap: @escaping () -> Void = {},
         @ViewBuilder header: @escaping () -> Header,
         @ViewBuilder footerLeading: @escaping () -> FooterLeading,
         @ViewBuilder footerActions: @escaping () -> FooterActions) {
        self.init(size: size,
                  isExpanded: isExpanded,
                  controlsVisible: controlsVisible,
                  isSelected: isSelected,
                  fill: fill,
                  fillOpacity: fillOpacity,
                  gradient: gradient,
                  gradientAngle: gradientAngle,
                  blendMode: blendMode,
                  elevated: elevated,
                  onTap: onTap,
                  header: header,
                  bodyContent: { EmptyView() },
                  footerLeading: footerLeading,
                  footerActions: footerActions,
                  widget: { EmptyView() })
    }
}

extension CardSurface where Widget == EmptyView {
    init(size: UI.Card.Size,
         isExpanded: Bool = false,
         controlsVisible: Bool = true,
         isSelected: Bool = false,
         fill: Color? = nil,
         fillOpacity: Double = 0.18,
         gradient: Bool = false,
         gradientAngle: Double = 135,
         blendMode: UI.Theme.ColorBlendMode = .softLight,
         elevated: Bool = true,
         onTap: @escaping () -> Void = {},
         @ViewBuilder header: @escaping () -> Header,
         @ViewBuilder bodyContent: @escaping () -> BodyContent,
         @ViewBuilder footerLeading: @escaping () -> FooterLeading,
         @ViewBuilder footerActions: @escaping () -> FooterActions) {
        self.init(size: size,
                  isExpanded: isExpanded,
                  controlsVisible: controlsVisible,
                  isSelected: isSelected,
                  fill: fill,
                  fillOpacity: fillOpacity,
                  gradient: gradient,
                  gradientAngle: gradientAngle,
                  blendMode: blendMode,
                  elevated: elevated,
                  onTap: onTap,
                  header: header,
                  bodyContent: bodyContent,
                  footerLeading: footerLeading,
                  footerActions: footerActions,
                  widget: { EmptyView() })
    }
}

#Preview("Card Surface") {
    VStack(spacing: UI.Tokens.Space.l) {
        CardSurface(size: .small,
                    isSelected: true,
                    fill: .accentColor,
                    fillOpacity: 0.12,
                    gradient: true) {
            CardHeader {
                UI.Card.IconChip(symbol: "shippingbox.fill", tint: .accentColor)
            } content: {
                CardHeaderTextBlock {
                    UI.Card.TitleText(text: "Small card")
                } subtitle: {
                    UI.Card.SubtitleText(text: "Selected")
                }
            } trailing: {
                EmptyView()
            }
        }

        CardSurface(size: .medium,
                    isExpanded: true,
                    controlsVisible: true,
                    fill: .teal,
                    fillOpacity: 0.10) {
            CardHeader {
                UI.Card.IconChip(symbol: "chart.xyaxis.line", tint: .teal)
            } content: {
                CardHeaderTextBlock {
                    UI.Card.TitleText(text: "Expanded surface")
                } subtitle: {
                    UI.Card.SubtitleText(text: "Sticky footer")
                }
            } trailing: {
                EmptyView()
            }
        } bodyContent: {
            UI.Card.InsetSection {
                UI.Chart.Sparkline(samples: [0.2, 0.35, 0.18, 0.6, 0.5])
                    .frame(height: 52)
            }
        } footerLeading: {
            UI.Card.MetricText(text: "62%")
        } footerActions: {
            UI.Card.FooterButton(systemName: "arrow.clockwise", help: "Refresh") {}
        }
    }
    .padding(UI.Tokens.Space.xl)
    .frame(width: 420)
}

#Preview("Card Selection Overlay") {
    VStack(spacing: UI.Tokens.Space.m) {
        Text("Unselected")
            .frame(maxWidth: .infinity)
            .padding(UI.Tokens.Space.l)
            .materialSurface(.regular, cornerRadius: UI.Tokens.Radius.card)
            .designCardSelectionOverlay(when: false)

        Text("Selected")
            .frame(maxWidth: .infinity)
            .padding(UI.Tokens.Space.l)
            .materialSurface(.regular, cornerRadius: UI.Tokens.Radius.card)
            .designCardSelectionOverlay(when: true)
    }
    .padding(UI.Tokens.Space.xl)
    .frame(width: 320)
}

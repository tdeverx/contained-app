import SwiftUI

public enum ResourceCardSize {
    case small, medium, large

    public var showsFooter: Bool { self != .small }
    public var showsWidget: Bool { self == .large }
}

public enum ResourceCardExpandedMetrics {
    public static let maxWidth: CGFloat = 760
}

public struct CardSizePicker: View {
    @Binding var selection: CardDensity

    public init(selection: Binding<CardDensity>) {
        self._selection = selection
    }

    public var body: some View {
        Picker("Card size", selection: $selection) {
            ForEach(CardDensity.allCases) { density in
                Text(density.displayName).tag(density)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 230)
    }
}

public struct ResourceGlassCard<Header: View, BodyContent: View, FooterLeading: View,
                         FooterActions: View, Widget: View>: View {
    var size: ResourceCardSize
    var isExpanded = false
    var cornerRadiusOverride: CGFloat?
    var controlsVisible = true
    var isSelected = false
    /// When set, the selected state reads as a soft `white.opacity` wash (matching a hovered glass
    /// button) instead of the 2.5pt accent stroke — used by the Activity and command-palette rows.
    var usesSelectionFill = false
    var fill: Color?
    var fillOpacity: Double = 0.18
    var gradient: Bool = false
    var gradientAngle: Double = 135
    var blendMode: ColorLayerBlendMode = .softLight
    /// Lift the card with a shadow. Pass `false` for flat tiles inside an already-elevated panel
    /// (e.g. the toolbar Images/Activity morph panels), matching the creation-menu tile style.
    var elevated: Bool = true
    var onTap: () -> Void = {}
    @ViewBuilder var header: () -> Header
    @ViewBuilder var bodyContent: () -> BodyContent
    @ViewBuilder var footerLeading: () -> FooterLeading
    @ViewBuilder var footerActions: () -> FooterActions
    @ViewBuilder var widget: () -> Widget

    @State private var hovering = false
    @Environment(\.cardMaterial) private var cardMaterial

    /// Render the selected state as a soft fill wash instead of the accent stroke.
    public func selectionFill(_ on: Bool = true) -> Self {
        var copy = self
        copy.usesSelectionFill = on
        return copy
    }

    public init(size: ResourceCardSize,
         isExpanded: Bool = false,
         cornerRadiusOverride: CGFloat? = nil,
         controlsVisible: Bool = true,
         isSelected: Bool = false,
         fill: Color? = nil,
         fillOpacity: Double = 0.18,
         gradient: Bool = false,
         gradientAngle: Double = 135,
         blendMode: ColorLayerBlendMode = .softLight,
         elevated: Bool = true,
         onTap: @escaping () -> Void = {},
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
        self.fill = fill
        self.fillOpacity = fillOpacity
        self.gradient = gradient
        self.gradientAngle = gradientAngle
        self.blendMode = blendMode
        self.elevated = elevated
        self.onTap = onTap
        self.header = header
        self.bodyContent = bodyContent
        self.footerLeading = footerLeading
        self.footerActions = footerActions
        self.widget = widget
    }

    public var body: some View {
        surface
            .contentShape(Rectangle())
            .onTapGesture { if !isExpanded { onTap() } }
            .onHover { hovering = $0 }
    }

    private var surface: some View {
        let cornerRadius = cornerRadiusOverride ?? (isExpanded ? Tokens.Radius.sheet : Tokens.Radius.card)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return cardContent
            .frame(maxWidth: isExpanded ? ResourceCardExpandedMetrics.maxWidth : .infinity,
                   alignment: .leading)
            .clipShape(shape)
            .resourceCardMaterial(cardMaterial,
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
                            .fill(AppMaterial.toolbarHoverFill)
                    } else {
                        RoundedRectangle(cornerRadius: Tokens.Radius.inset(from: cornerRadius, by: 1),
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
        if isExpanded {
            VStack(alignment: .leading, spacing: 0) {
                header()
                    .frame(maxWidth: .infinity, alignment: .leading)
                expandedBody()
                if size != .small {
                    footer(showWidget: size.showsWidget, showActions: controlsVisible)
                }
            }
        } else {
            switch size {
            case .small:
                header()
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .medium:
                VStack(alignment: .leading, spacing: 0) {
                    header()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    footer(showWidget: false, showActions: hovering)
                }
            case .large:
                VStack(alignment: .leading, spacing: 0) {
                    header()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    footer(showWidget: true, showActions: hovering)
                }
            }
        }
    }

    private func expandedBody() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            bodyContent()
                .frame(maxWidth: .infinity, alignment: .leading)
            if size == .small {
                footer(showWidget: false, showActions: controlsVisible)
            }
        }
    }

    private func footer(showWidget: Bool, showActions: Bool) -> some View {
        ResourceCardFooter(showWidget: showWidget, actionsVisible: showActions) {
            footerLeading()
        } trailing: {
            footerActions()
        } widget: {
            widget()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)
        }
    }
}

private struct ResourceCardMaterialSurface: ViewModifier {
    var material: WindowMaterial
    var cornerRadius: CGFloat
    var shadow: Bool
    var fill: Color?
    var fillOpacity: Double
    var gradient: Bool
    var gradientAngle: Double
    var blendMode: ColorLayerBlendMode
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
                        VisualEffectBackground(material: material.nsMaterial, blendingMode: .withinWindow)
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
            shape.fill(fillStyle(fill))
                .blendMode(blendMode.blendMode)
                .clipShape(shape)
        }
    }

    private func fillStyle(_ color: Color) -> AnyShapeStyle {
        if gradient {
            let radians = gradientAngle * .pi / 180
            let dx = cos(radians) / 2
            let dy = sin(radians) / 2
            return AnyShapeStyle(LinearGradient(
                colors: [color.opacity(fillOpacity * 1.35), color.opacity(fillOpacity * 0.4)],
                startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
                endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy)))
        }
        return AnyShapeStyle(color.opacity(fillOpacity))
    }

    private var shadowColor: Color { .black.opacity((colorScheme == .dark ? 0.55 : 0.18)) }
    private var shadowRadius: CGFloat { 10 }
    private var shadowY: CGFloat { 4 }
}

private extension View {
    func resourceCardMaterial(_ material: WindowMaterial,
                              cornerRadius: CGFloat,
                              shadow: Bool,
                              fill: Color?,
                              fillOpacity: Double,
                              gradient: Bool,
                              gradientAngle: Double,
                              blendMode: ColorLayerBlendMode) -> some View {
        modifier(ResourceCardMaterialSurface(material: material,
                                             cornerRadius: cornerRadius,
                                             shadow: shadow,
                                             fill: fill,
                                             fillOpacity: fillOpacity,
                                             gradient: gradient,
                                             gradientAngle: gradientAngle,
                                             blendMode: blendMode))
    }
}

public extension ResourceGlassCard where BodyContent == EmptyView, FooterLeading == EmptyView,
                                FooterActions == EmptyView, Widget == EmptyView {
    init(size: ResourceCardSize = .small,
         isSelected: Bool = false,
         fill: Color? = nil,
         fillOpacity: Double = 0.18,
         gradient: Bool = false,
         gradientAngle: Double = 135,
         blendMode: ColorLayerBlendMode = .softLight,
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

public extension ResourceGlassCard where BodyContent == EmptyView, Widget == EmptyView {
    init(size: ResourceCardSize,
         isExpanded: Bool = false,
         controlsVisible: Bool = true,
         isSelected: Bool = false,
         fill: Color? = nil,
         fillOpacity: Double = 0.18,
         gradient: Bool = false,
         gradientAngle: Double = 135,
         blendMode: ColorLayerBlendMode = .softLight,
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

public extension ResourceGlassCard where Widget == EmptyView {
    init(size: ResourceCardSize,
         isExpanded: Bool = false,
         controlsVisible: Bool = true,
         isSelected: Bool = false,
         fill: Color? = nil,
         fillOpacity: Double = 0.18,
         gradient: Bool = false,
         gradientAngle: Double = 135,
         blendMode: ColorLayerBlendMode = .softLight,
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

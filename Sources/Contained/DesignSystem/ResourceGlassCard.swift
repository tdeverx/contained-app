import SwiftUI

enum ResourceCardSize {
    case small, medium, large

    var showsFooter: Bool { self != .small }
    var showsWidget: Bool { self == .large }
}

enum ResourceCardExpandedMetrics {
    static let maxWidth: CGFloat = 760
}

struct CardSizePicker: View {
    @Binding var selection: CardDensity

    var body: some View {
        Picker("Card size", selection: $selection) {
            ForEach(CardDensity.allCases) { density in
                Text(density.displayName).tag(density)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 230)
    }
}

struct ResourceGlassCard<Header: View, BodyContent: View, FooterLeading: View,
                         FooterActions: View, Widget: View>: View {
    var size: ResourceCardSize
    var isExpanded = false
    var controlsVisible = true
    var isSelected = false
    var fill: Color?
    var fillOpacity: Double = 0.18
    var gradient: Bool = false
    var gradientAngle: Double = 135
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

    init(size: ResourceCardSize,
         isExpanded: Bool = false,
         controlsVisible: Bool = true,
         isSelected: Bool = false,
         fill: Color? = nil,
         fillOpacity: Double = 0.18,
         gradient: Bool = false,
         gradientAngle: Double = 135,
         elevated: Bool = true,
         onTap: @escaping () -> Void = {},
         @ViewBuilder header: @escaping () -> Header,
         @ViewBuilder bodyContent: @escaping () -> BodyContent,
         @ViewBuilder footerLeading: @escaping () -> FooterLeading,
         @ViewBuilder footerActions: @escaping () -> FooterActions,
         @ViewBuilder widget: @escaping () -> Widget) {
        self.size = size
        self.isExpanded = isExpanded
        self.controlsVisible = controlsVisible
        self.isSelected = isSelected
        self.fill = fill
        self.fillOpacity = fillOpacity
        self.gradient = gradient
        self.gradientAngle = gradientAngle
        self.elevated = elevated
        self.onTap = onTap
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
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
        return cardContent
            .frame(maxWidth: isExpanded ? ResourceCardExpandedMetrics.maxWidth : .infinity,
                   alignment: .leading)
            .clipShape(shape)
            .glassSurface(.regular, cornerRadius: Tokens.Radius.card,
                          shadow: elevated,
                          fill: fill,
                          fillOpacity: fillOpacity,
                          gradient: gradient,
                          gradientAngle: gradientAngle)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: Tokens.Radius.card)
                        .strokeBorder(Color.accentColor, lineWidth: 2.5)
                        .padding(1)
                }
            }
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

extension ResourceGlassCard where BodyContent == EmptyView, FooterLeading == EmptyView,
                                FooterActions == EmptyView, Widget == EmptyView {
    init(size: ResourceCardSize = .small,
         isSelected: Bool = false,
         fill: Color? = nil,
         fillOpacity: Double = 0.18,
         gradient: Bool = false,
         gradientAngle: Double = 135,
         elevated: Bool = true,
         onTap: @escaping () -> Void = {},
         @ViewBuilder header: @escaping () -> Header) {
        self.init(size: size,
                  isSelected: isSelected,
                  fill: fill,
                  fillOpacity: fillOpacity,
                  gradient: gradient,
                  gradientAngle: gradientAngle,
                  elevated: elevated,
                  onTap: onTap,
                  header: header,
                  bodyContent: { EmptyView() },
                  footerLeading: { EmptyView() },
                  footerActions: { EmptyView() },
                  widget: { EmptyView() })
    }
}

extension ResourceGlassCard where BodyContent == EmptyView, Widget == EmptyView {
    init(size: ResourceCardSize,
         isExpanded: Bool = false,
         controlsVisible: Bool = true,
         isSelected: Bool = false,
         fill: Color? = nil,
         fillOpacity: Double = 0.18,
         gradient: Bool = false,
         gradientAngle: Double = 135,
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
                  elevated: elevated,
                  onTap: onTap,
                  header: header,
                  bodyContent: { EmptyView() },
                  footerLeading: footerLeading,
                  footerActions: footerActions,
                  widget: { EmptyView() })
    }
}

extension ResourceGlassCard where Widget == EmptyView {
    init(size: ResourceCardSize,
         isExpanded: Bool = false,
         controlsVisible: Bool = true,
         isSelected: Bool = false,
         fill: Color? = nil,
         fillOpacity: Double = 0.18,
         gradient: Bool = false,
         gradientAngle: Double = 135,
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
                  elevated: elevated,
                  onTap: onTap,
                  header: header,
                  bodyContent: bodyContent,
                  footerLeading: footerLeading,
                  footerActions: footerActions,
                  widget: { EmptyView() })
    }
}

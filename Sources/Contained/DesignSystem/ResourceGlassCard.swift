import SwiftUI

enum ResourceCardSize {
    case small, medium, large

    var height: CGFloat {
        switch self {
        case .small: return 54
        case .medium: return 78
        case .large: return 176
        }
    }

    var showsFooter: Bool { self != .small }
    var showsWidget: Bool { self == .large }
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
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            header()
            if isExpanded {
                GeometryReader { proxy in
                    expandedBody()
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                        .opacity(clamp((proxy.size.height - 40) / 160))
                }
                if size != .small {
                    footer(showWidget: size.showsWidget, showActions: controlsVisible)
                }
            } else {
                switch size {
                case .small:
                    EmptyView()
                case .medium:
                    footer(showWidget: false, showActions: hovering)
                case .large:
                    Spacer(minLength: 0)
                    footer(showWidget: true, showActions: hovering)
                }
            }
        }
        .padding(Tokens.Space.m)
        .frame(maxWidth: .infinity,
               minHeight: isExpanded ? 0 : size.height,
               maxHeight: isExpanded ? .infinity : size.height,
               alignment: isExpanded ? .bottomLeading : .topLeading)
        .glassSurface(.regular, cornerRadius: Tokens.Radius.card,
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

    private func expandedBody() -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            if size != .large {
                widget()
            }
            bodyContent()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if size == .small {
                footer(showWidget: false, showActions: controlsVisible)
            }
        }
    }

    private func footer(showWidget: Bool, showActions: Bool) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            if showWidget {
                widget()
            }
            HStack(spacing: Tokens.Space.m) {
                footerLeading()
                Spacer(minLength: 0)
                footerActions()
                    .opacity(showActions ? 1 : 0)
                    .allowsHitTesting(showActions)
                    .animation(.easeOut(duration: 0.18), value: showActions)
            }
        }
        .padding(.top, showWidget ? Tokens.Space.s : 0)
    }

    private func clamp(_ value: CGFloat) -> Double {
        Double(max(0, min(1, value)))
    }
}

extension ResourceGlassCard where BodyContent == EmptyView, FooterLeading == EmptyView,
                                FooterActions == EmptyView, Widget == EmptyView {
    init(size: ResourceCardSize = .small,
         fill: Color? = nil,
         fillOpacity: Double = 0.18,
         gradient: Bool = false,
         gradientAngle: Double = 135,
         onTap: @escaping () -> Void = {},
         @ViewBuilder header: @escaping () -> Header) {
        self.init(size: size,
                  fill: fill,
                  fillOpacity: fillOpacity,
                  gradient: gradient,
                  gradientAngle: gradientAngle,
                  onTap: onTap,
                  header: header,
                  bodyContent: { EmptyView() },
                  footerLeading: { EmptyView() },
                  footerActions: { EmptyView() },
                  widget: { EmptyView() })
    }
}

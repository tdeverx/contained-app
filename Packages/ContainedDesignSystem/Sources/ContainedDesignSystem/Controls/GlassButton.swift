import SwiftUI

private struct GlassButtonItemHoverEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

private extension EnvironmentValues {
    var glassButtonItemHoverEnabled: Bool {
        get { self[GlassButtonItemHoverEnabledKey.self] }
        set { self[GlassButtonItemHoverEnabledKey.self] = newValue }
    }
}

private struct OptionalAccessibilityLabel: ViewModifier {
    var label: String

    func body(content: Content) -> some View {
        if label.isEmpty {
            content
        } else {
            content.accessibilityLabel(label)
        }
    }
}

public struct GlassButtonTintStyle: Equatable, Sendable {
    public var enabled = false
    public var tint: DesignTint = .multicolor
    public var opacity = 0.18
    public var gradient = true
    public var gradientAngle = 135.0
    public var blendMode: ColorLayerBlendMode = .softLight

    public init(enabled: Bool = false,
                tint: DesignTint = .multicolor,
                opacity: Double = 0.18,
                gradient: Bool = true,
                gradientAngle: Double = 135.0,
                blendMode: ColorLayerBlendMode = .softLight) {
        self.enabled = enabled
        self.tint = tint
        self.opacity = opacity
        self.gradient = gradient
        self.gradientAngle = gradientAngle
        self.blendMode = blendMode
    }

    public static let disabled = GlassButtonTintStyle()
}

/// A reusable glass button item: an icon or text button with the shared 28pt inner height and 4pt
/// padding. Place it inside `GlassButton` to get the full 36pt glass capsule.
public struct GlassButtonItem<Label: View>: View {
    var role: ButtonRole? = nil
    var tint: Color? = nil
    var help: String = ""
    var isCancel: Bool = false
    var isLabel: Bool = false
    var isIcon = false
    var action: (() -> Void)? = nil
    @ViewBuilder var label: () -> Label

    @State private var hovering = false
    @Environment(\.glassButtonItemHoverEnabled) private var hoverEnabled
    @Environment(\.colorScheme) private var colorScheme

    private var itemForegroundStyle: AnyShapeStyle {
        if role == .destructive { return AnyShapeStyle(Color.red) }
        if let tint { return AnyShapeStyle(tint) }
        return AnyShapeStyle(.primary)
    }

    public init(role: ButtonRole? = nil, tint: Color? = nil, help: String = "",
         isCancel: Bool = false, isLabel: Bool = false, isIcon: Bool = false,
         action: (() -> Void)? = nil, @ViewBuilder label: @escaping () -> Label) {
        self.role = role
        self.tint = tint
        self.help = help
        self.isCancel = isCancel
        self.isLabel = isLabel
        self.isIcon = isIcon
        self.action = action
        self.label = label
    }

    private var content: some View {
        label()
            .font(.body.weight(.medium))
            .foregroundStyle(itemForegroundStyle)
            .padding(DesignTokens.Toolbar.iconInnerPadding)
            .frame(width: isIcon ? DesignTokens.Toolbar.buttonItemHeight : nil,
                   height: DesignTokens.Toolbar.buttonItemHeight)
            .contentShape(Rectangle())
            .background {
                Capsule(style: .continuous)
                    .fill(
                        hoverEnabled && hovering && !isLabel
                            ? DesignMaterial.toolbarInteractiveHoverFill(for: colorScheme)
                            : .clear
                    )
            }
            .onHover { hovering = isLabel ? false : $0 }
            .animation(.easeOut(duration: 0.15), value: hovering)
    }

    public var body: some View {
        Group {
            if let action, !isLabel {
                Button(role: role, action: action) {
                    content
                }
                .buttonStyle(.plain)
                .buttonBorderShape(.capsule)
                .tint(role == .destructive ? .red : tint)
            } else {
                content
            }
        }
        .help(help)
        .modifier(OptionalAccessibilityLabel(label: help))
        .keyboardShortcut(isCancel && action != nil ? .cancelAction : nil)
    }
}

/// Input content that occupies the same 28pt inner lane as `GlassButtonItem`, but leaves hover/pressed
/// treatment to the enclosing `GlassButton` container.
public struct GlassButtonInputItem<Content: View>: View {
    public var spacing = DesignTokens.Toolbar.searchIconGap
    @ViewBuilder var content: () -> Content

    public init(spacing: CGFloat = DesignTokens.Toolbar.searchIconGap,
                @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        HStack(spacing: spacing) { content() }
            .font(.body.weight(.medium))
            .padding(DesignTokens.Toolbar.iconInnerPadding)
            .frame(height: DesignTokens.Toolbar.buttonItemHeight)
            .contentShape(Rectangle())
    }
}

public extension GlassButtonItem where Label == Image {
    init(systemName: String, role: ButtonRole? = nil, tint: Color? = nil, help: String = "",
         isCancel: Bool = false, isLabel: Bool = false, action: (() -> Void)? = nil) {
        self.role = role
        self.tint = tint
        self.help = help
        self.isCancel = isCancel
        self.isLabel = isLabel
        self.isIcon = true
        self.action = action
        self.label = { Image(systemName: systemName) }
    }
}

/// A pill that groups related glass button items under one shared interactive-glass capsule. This
/// is the morph target for compact button groups across the app.
public struct GlassButton<Content: View>: View {
    public var spacing: CGFloat = 0
    public var height: CGFloat = DesignTokens.Toolbar.buttonGroupHeight
    public var minWidth: CGFloat? = nil
    public var singleItem: Bool = false
    /// Set `false` for a static glass container (no hover treatment) — e.g. vanity toolbar chrome.
    public var interactive: Bool = true
    @ViewBuilder var content: () -> Content

    public init(spacing: CGFloat = 0,
                height: CGFloat = DesignTokens.Toolbar.buttonGroupHeight,
                minWidth: CGFloat? = nil,
                singleItem: Bool = false,
                interactive: Bool = true,
                @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.height = height
        self.minWidth = minWidth
        self.singleItem = singleItem
        self.interactive = interactive
        self.content = content
    }

    @State private var hovering = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.buttonTintStyle) private var tintStyle

    public var body: some View {
        let shape = Capsule(style: .continuous)
        HStack(spacing: spacing) { content() }
            .padding(.horizontal, DesignTokens.Toolbar.iconInnerPadding)
            .frame(height: height)
            .frame(minWidth: minWidth)
            .background {
                if singleItem && interactive {
                    Capsule(style: .continuous)
                        .fill(
                            hovering
                                ? DesignMaterial.toolbarInteractiveHoverFill(for: colorScheme)
                                : .clear
                        )
                }
            }
            .environment(\.glassButtonItemHoverEnabled, !singleItem && interactive)
            .onHover { if interactive { hovering = $0 } }
            .background { tintLayer(in: shape) }
            .toolbarControlMaterial(in: shape)
            .animation(.spring(response: 0.18, dampingFraction: 0.82), value: hovering)
    }

    @ViewBuilder
    private func tintLayer(in shape: Capsule) -> some View {
        if tintStyle.enabled {
            shape
                .fill(tintFillStyle(tintStyle.tint.color))
                .blendMode(tintStyle.blendMode.blendMode)
                .clipShape(shape)
        }
    }

    private func tintFillStyle(_ color: Color) -> AnyShapeStyle {
        if tintStyle.gradient {
            let radians = tintStyle.gradientAngle * .pi / 180
            let dx = cos(radians) / 2
            let dy = sin(radians) / 2
            return AnyShapeStyle(LinearGradient(
                colors: [color.opacity(tintStyle.opacity * 1.35), color.opacity(tintStyle.opacity * 0.4)],
                startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
                endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy)))
        }
        return AnyShapeStyle(color.opacity(tintStyle.opacity))
    }
}

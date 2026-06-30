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

/// A reusable glass button item: an icon or text button with the shared 28pt inner height and 4pt
/// padding. Place it inside `GlassButton` to get the full 36pt glass capsule.
struct GlassButtonItem<Label: View>: View {
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

    private var itemForegroundStyle: AnyShapeStyle {
        if role == .destructive { return AnyShapeStyle(Color.red) }
        if let tint { return AnyShapeStyle(tint) }
        return AnyShapeStyle(Color.white)
    }

    init(role: ButtonRole? = nil, tint: Color? = nil, help: String = "",
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
            .padding(Tokens.Toolbar.iconInnerPadding)
            .frame(width: isIcon ? Tokens.Toolbar.buttonItemHeight : nil,
                   height: Tokens.Toolbar.buttonItemHeight)
            .contentShape(Rectangle())
            .background {
                Capsule(style: .continuous)
                    .fill(hoverEnabled && hovering && !isLabel ? AppMaterial.toolbarHoverFill : .clear)
            }
            .onHover { hovering = isLabel ? false : $0 }
            .animation(.easeOut(duration: 0.15), value: hovering)
    }

    var body: some View {
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
        .accessibilityLabel(help.isEmpty ? "Button" : help)
        .keyboardShortcut(isCancel && action != nil ? .cancelAction : nil)
    }
}

/// Input content that occupies the same 28pt inner lane as `GlassButtonItem`, but leaves hover/pressed
/// treatment to the enclosing `GlassButton` container.
struct GlassButtonInputItem<Content: View>: View {
    var spacing = Tokens.Toolbar.searchIconGap
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: spacing) { content() }
            .font(.body.weight(.medium))
            .padding(Tokens.Toolbar.iconInnerPadding)
            .frame(height: Tokens.Toolbar.buttonItemHeight)
            .contentShape(Rectangle())
    }
}

extension GlassButtonItem where Label == Image {
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
struct GlassButton<Content: View>: View {
    var spacing: CGFloat = 0
    var height: CGFloat = Tokens.Toolbar.buttonGroupHeight
    var minWidth: CGFloat? = nil
    var singleItem: Bool = false
    /// Set `false` for a static glass container (no hover treatment) — e.g. vanity toolbar chrome.
    var interactive: Bool = true
    @ViewBuilder var content: () -> Content

    @State private var hovering = false

    var body: some View {
        HStack(spacing: spacing) { content() }
            .padding(.horizontal, Tokens.Toolbar.iconInnerPadding)
            .frame(height: height)
            .frame(minWidth: minWidth)
            .background {
                if singleItem && interactive {
                    Capsule(style: .continuous)
                        .fill(hovering ? AppMaterial.toolbarHoverFill : .clear)
                }
            }
            .environment(\.glassButtonItemHoverEnabled, !singleItem && interactive)
            .onHover { if interactive { hovering = $0 } }
            .animation(.easeOut(duration: 0.15), value: hovering)
            .toolbarControlMaterial(in: Capsule())
    }
}

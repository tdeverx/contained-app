import SwiftUI

/// Semantic action description for package-owned glass action chrome.
public struct DesignAction {
    public var systemName: String
    public var title: String?
    public var help: String
    public var role: ButtonRole?
    public var tint: Color?
    public var isCancel: Bool
    public var isEnabled: Bool
    public var action: () -> Void

    public init(systemName: String,
                title: String? = nil,
                help: String? = nil,
                role: ButtonRole? = nil,
                tint: Color? = nil,
                isCancel: Bool = false,
                isEnabled: Bool = true,
                action: @escaping () -> Void) {
        self.systemName = systemName
        self.title = title
        self.help = help ?? title ?? ""
        self.role = role
        self.tint = tint
        self.isCancel = isCancel
        self.isEnabled = isEnabled
        self.action = action
    }
}

/// Source-of-truth glass action group.
///
/// Feature views provide action descriptions; the design system owns button grouping, sizing,
/// selection tinting, hover treatment, accessibility labels, and cancel/destructive behavior.
public struct DesignActionGroup: View {
    public var actions: [DesignAction]
    public var spacing: CGFloat
    public var height: CGFloat
    public var minWidth: CGFloat?
    public var singleItem: Bool?
    public var interactive: Bool

    public init(_ actions: [DesignAction],
                spacing: CGFloat = 0,
                height: CGFloat = Tokens.Toolbar.buttonGroupHeight,
                minWidth: CGFloat? = nil,
                singleItem: Bool? = nil,
                interactive: Bool = true) {
        self.actions = actions
        self.spacing = spacing
        self.height = height
        self.minWidth = minWidth
        self.singleItem = singleItem
        self.interactive = interactive
    }

    public init(_ action: DesignAction,
                height: CGFloat = Tokens.Toolbar.buttonGroupHeight,
                minWidth: CGFloat? = nil,
                interactive: Bool = true) {
        self.init([action],
                  height: height,
                  minWidth: minWidth,
                  singleItem: true,
                  interactive: interactive)
    }

    public var body: some View {
        GlassButton(spacing: spacing,
                    height: height,
                    minWidth: minWidth,
                    singleItem: singleItem ?? (actions.count == 1),
                    interactive: interactive) {
            DesignActionItems(actions)
        }
    }
}

/// Package-owned glass cluster for mixed content, such as a menu plus action items.
public struct DesignActionCluster<Content: View>: View {
    public var spacing: CGFloat
    public var height: CGFloat
    public var minWidth: CGFloat?
    public var singleItem: Bool?
    public var interactive: Bool
    @ViewBuilder public var content: () -> Content

    public init(spacing: CGFloat = 0,
                height: CGFloat = Tokens.Toolbar.buttonGroupHeight,
                minWidth: CGFloat? = nil,
                singleItem: Bool? = nil,
                interactive: Bool = true,
                @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.height = height
        self.minWidth = minWidth
        self.singleItem = singleItem
        self.interactive = interactive
        self.content = content
    }

    public var body: some View {
        GlassButton(spacing: spacing,
                    height: height,
                    minWidth: minWidth,
                    singleItem: singleItem ?? false,
                    interactive: interactive) {
            content()
        }
    }
}

/// Package-owned input cluster for search fields and compact inline controls.
public struct DesignInputCluster<Content: View>: View {
    @ViewBuilder public var content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        GlassButton(singleItem: true) {
            GlassButtonInputItem {
                content()
            }
        }
    }
}

/// Package-owned action item renderer for mixed groups that also contain menus or status labels.
public struct DesignActionItems: View {
    public var actions: [DesignAction]

    public init(_ actions: [DesignAction]) {
        self.actions = actions
    }

    public var body: some View {
        ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
            GlassButtonItem(role: item.role,
                            tint: item.tint,
                            help: item.help,
                            isCancel: item.isCancel,
                            isIcon: item.title == nil,
                            action: item.action) {
                if let title = item.title {
                    Label(title, systemImage: item.systemName)
                } else {
                    Image(systemName: item.systemName)
                }
            }
            .disabled(!item.isEnabled)
        }
    }
}

/// Semantic label for menus embedded in glass action groups.
public struct DesignMenuActionLabel: View {
    public var systemName: String
    public var help: String
    public var role: ButtonRole?
    public var tint: Color?

    public init(systemName: String,
                help: String,
                role: ButtonRole? = nil,
                tint: Color? = nil) {
        self.systemName = systemName
        self.help = help
        self.role = role
        self.tint = tint
    }

    public var body: some View {
        GlassButtonItem(systemName: systemName,
                        role: role,
                        tint: tint,
                        help: help)
    }
}

/// Package-owned progress capsule for action slots that are temporarily busy.
public struct DesignProgressActionCapsule: View {
    public var controlSize: ControlSize

    public init(controlSize: ControlSize = .small) {
        self.controlSize = controlSize
    }

    public var body: some View {
        GlassButton(singleItem: true) {
            ProgressView()
                .controlSize(controlSize)
                .frame(width: Tokens.Toolbar.buttonItemHeight,
                       height: Tokens.Toolbar.buttonItemHeight)
        }
    }
}

/// Prominence levels for package-owned text action buttons.
public enum DesignTextActionProminence {
    case standard
    case prominent
}

/// Package-owned text action button for command rows and form footers.
public struct DesignTextActionButton: View {
    public var title: String
    public var systemName: String
    public var help: String
    public var role: ButtonRole?
    public var prominence: DesignTextActionProminence
    public var controlSize: ControlSize
    public var isEnabled: Bool
    public var action: () -> Void

    public init(title: String,
                systemName: String,
                help: String? = nil,
                role: ButtonRole? = nil,
                prominence: DesignTextActionProminence = .standard,
                controlSize: ControlSize = .regular,
                isEnabled: Bool = true,
                action: @escaping () -> Void) {
        self.title = title
        self.systemName = systemName
        self.help = help ?? title
        self.role = role
        self.prominence = prominence
        self.controlSize = controlSize
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        switch prominence {
        case .standard:
            Button(role: role, action: action) {
                Label(title, systemImage: systemName)
            }
            .buttonStyle(.glass)
            .controlSize(controlSize)
            .help(help)
            .disabled(!isEnabled)
        case .prominent:
            Button(role: role, action: action) {
                Label(title, systemImage: systemName)
            }
            .buttonStyle(.glassProminent)
            .controlSize(controlSize)
            .help(help)
            .disabled(!isEnabled)
        }
    }
}

/// Package-owned glass toggle used when a binary command belongs in toolbar/panel chrome.
public struct DesignGlassToggle: View {
    @Binding public var isOn: Bool
    public var title: String
    public var systemName: String

    public init(isOn: Binding<Bool>,
                title: String,
                systemName: String) {
        self._isOn = isOn
        self.title = title
        self.systemName = systemName
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: systemName)
        }
        .toggleStyle(.button)
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
    }
}

/// Package-owned floating selection action bar.
public struct DesignSelectionActionBar: View {
    public var count: Int
    public var countLabel: (Int) -> String
    public var actions: [DesignAction]

    public init(count: Int,
                countLabel: @escaping (Int) -> String,
                actions: [DesignAction]) {
        self.count = count
        self.countLabel = countLabel
        self.actions = actions
    }

    public var body: some View {
        HStack(spacing: Tokens.Space.m) {
            Text(countLabel(count))
                .font(.callout.weight(.medium))
            Divider()
                .frame(height: 16)
            ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
                DesignTextActionButton(title: item.title ?? item.help,
                                       systemName: item.systemName,
                                       help: item.help,
                                       role: item.role,
                                       prominence: .standard,
                                       isEnabled: item.isEnabled,
                                       action: item.action)
            }
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.vertical, Tokens.Space.s)
        .glassCapsuleSurface(shadow: false)
    }
}

/// Package-owned transient banner chrome.
public struct DesignStatusBanner: View {
    public var text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.callout.weight(.medium))
            .padding(.horizontal, Tokens.Space.l)
            .padding(.vertical, Tokens.Space.s)
            .glassCapsuleSurface(shadow: false)
    }
}

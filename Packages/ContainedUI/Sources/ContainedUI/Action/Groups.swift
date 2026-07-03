import SwiftUI

/// Source-of-truth glass action group.
///
/// Feature views provide action descriptions; the design system owns button grouping, sizing,
/// selection tinting, hover treatment, accessibility labels, and cancel/destructive behavior.
public extension UI.Action {
struct Group: View {
    public var actions: [UI.Action.Item]
    public var spacing: CGFloat
    public var height: CGFloat
    public var minWidth: CGFloat?
    public var singleItem: Bool?
    public var interactive: Bool

    public init(_ actions: [UI.Action.Item],
                spacing: CGFloat = 0,
                height: CGFloat = UI.Tokens.Toolbar.buttonGroupHeight,
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

    public init(_ action: UI.Action.Item,
                height: CGFloat = UI.Tokens.Toolbar.buttonGroupHeight,
                minWidth: CGFloat? = nil,
                interactive: Bool = true) {
        self.init([action],
                  height: height,
                  minWidth: minWidth,
                  singleItem: true,
                  interactive: interactive)
    }

    public var body: some View {
        MaterialButton(spacing: spacing,
                       height: height,
                       minWidth: minWidth,
                       singleItem: singleItem ?? (actions.count == 1),
                       interactive: interactive) {
            UI.Action.Items(actions)
        }
    }
}

/// Package-owned glass cluster for mixed content, such as a menu plus action items.
struct Cluster<Content: View>: View {
    public var spacing: CGFloat
    public var height: CGFloat
    public var minWidth: CGFloat?
    public var singleItem: Bool?
    public var interactive: Bool
    @ViewBuilder public var content: () -> Content

    public init(spacing: CGFloat = 0,
                height: CGFloat = UI.Tokens.Toolbar.buttonGroupHeight,
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
        MaterialButton(spacing: spacing,
                       height: height,
                       minWidth: minWidth,
                       singleItem: singleItem ?? false,
                       interactive: interactive) {
            content()
        }
    }
}
}

/// Package-owned input cluster for search fields and compact inline controls.
public extension UI.Control {
struct InputCluster<Content: View>: View {
    @ViewBuilder public var content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        MaterialButton(singleItem: true) {
            MaterialButtonInputItem {
                content()
            }
        }
    }
}
}

/// Package-owned action item renderer for mixed groups that also contain menus or status labels.
public extension UI.Action {
struct Items: View {
    public var actions: [UI.Action.Item]

    public init(_ actions: [UI.Action.Item]) {
        self.actions = actions
    }

    public var body: some View {
        ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
            MaterialButtonItem(role: item.role,
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
struct MenuLabel: View {
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
        MaterialButtonItem(systemName: systemName,
                           role: role,
                           tint: tint,
                           help: help)
    }
}
}

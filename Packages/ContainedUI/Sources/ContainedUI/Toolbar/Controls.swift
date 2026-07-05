import SwiftUI

/// UI package controls for the app toolbar band, sized from `UI.Tokens.Toolbar` to macOS 26
/// toolbar proportions. Centralizing them here keeps the toolbar, creation tiles
/// (`OptionTile`), and future band controls visually consistent.

public extension UI.Action {
struct MenuButton<LabelContent: View, MenuContent: View>: View {
    public var material: UI.Theme.WindowMaterial?
    public var tintStyle: UI.Theme.ButtonTintStyle?
    @ViewBuilder public var menuContent: () -> MenuContent
    @ViewBuilder public var labelContent: () -> LabelContent

    public init(material: UI.Theme.WindowMaterial? = nil,
                tintStyle: UI.Theme.ButtonTintStyle? = nil,
                @ViewBuilder menuContent: @escaping () -> MenuContent,
                @ViewBuilder labelContent: @escaping () -> LabelContent) {
        self.material = material
        self.tintStyle = tintStyle
        self.menuContent = menuContent
        self.labelContent = labelContent
    }

    public var body: some View {
        Menu {
            menuContent()
        } label: {
            MaterialButton(singleItem: true,
                           material: material,
                           tintStyle: tintStyle) {
                labelContent()
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: true, vertical: false)
    }
}
}

public extension UI.Toolbar {
struct SearchField<Trailing: View>: View {
    @Binding public var text: String
    public var prompt: String
    public var clearSearchLabel: String
    public var material: UI.Theme.WindowMaterial?
    public var tintStyle: UI.Theme.ButtonTintStyle?
    public var focused: FocusState<Bool>.Binding
    public var onSubmit: () -> Void
    public var onClear: () -> Void
    @ViewBuilder public var trailing: () -> Trailing

    public init(text: Binding<String>,
                prompt: String,
                clearSearchLabel: String,
                material: UI.Theme.WindowMaterial? = nil,
                tintStyle: UI.Theme.ButtonTintStyle? = nil,
                focused: FocusState<Bool>.Binding,
                onSubmit: @escaping () -> Void = {},
                onClear: @escaping () -> Void,
                @ViewBuilder trailing: @escaping () -> Trailing) {
        self._text = text
        self.prompt = prompt
        self.clearSearchLabel = clearSearchLabel
        self.material = material
        self.tintStyle = tintStyle
        self.focused = focused
        self.onSubmit = onSubmit
        self.onClear = onClear
        self.trailing = trailing
    }

    public var body: some View {
        MaterialButton(singleItem: true,
                       material: material,
                       tintStyle: tintStyle) {
            MaterialButtonInputItem {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .foregroundStyle(.secondary)
                TextField(prompt, text: $text)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .fontWeight(.medium)
                    .focused(focused)
                    .onSubmit(onSubmit)
                if !text.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(clearSearchLabel)
                    .accessibilityLabel(clearSearchLabel)
                } else {
                    trailing()
                }
            }
        }
        .toolbarControlContentShape()
        .simultaneousGesture(TapGesture().onEnded { focused.wrappedValue = true })
    }
}

/// Package-owned empty toolbar slot for stable morph origins and vanity chrome.
struct VanitySlot<Content: View>: View {
    public var minWidth: CGFloat
    public var interactive: Bool
    public var material: UI.Theme.WindowMaterial?
    public var tintStyle: UI.Theme.ButtonTintStyle?
    @ViewBuilder public var content: () -> Content

    public init(minWidth: CGFloat = UI.Tokens.Toolbar.trafficLightsWidth,
                interactive: Bool = false,
                material: UI.Theme.WindowMaterial? = nil,
                tintStyle: UI.Theme.ButtonTintStyle? = nil,
                @ViewBuilder content: @escaping () -> Content = { Color.clear }) {
        self.minWidth = minWidth
        self.interactive = interactive
        self.material = material
        self.tintStyle = tintStyle
        self.content = content
    }

    public var body: some View {
        MaterialButton(minWidth: minWidth,
                       singleItem: true,
                       interactive: interactive,
                       material: material,
                       tintStyle: tintStyle) {
            content()
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// Package-owned toolbar button for custom status content.
struct StatusButton<Content: View>: View {
    public var help: String
    public var material: UI.Theme.WindowMaterial?
    public var tintStyle: UI.Theme.ButtonTintStyle?
    public var action: () -> Void
    @ViewBuilder public var content: () -> Content

    public init(help: String,
                material: UI.Theme.WindowMaterial? = nil,
                tintStyle: UI.Theme.ButtonTintStyle? = nil,
                action: @escaping () -> Void,
                @ViewBuilder content: @escaping () -> Content) {
        self.help = help
        self.material = material
        self.tintStyle = tintStyle
        self.action = action
        self.content = content
    }

    public var body: some View {
        MaterialButton(singleItem: true,
                       material: material,
                       tintStyle: tintStyle) {
            MaterialButtonItem(help: help, action: action) {
                content()
            }
        }
    }
}

/// Package-owned glass shell for toolbar clusters that mix action items and status/menu items.
struct ActionCluster<Content: View>: View {
    public var spacing: CGFloat
    public var material: UI.Theme.WindowMaterial?
    public var tintStyle: UI.Theme.ButtonTintStyle?
    @ViewBuilder public var content: () -> Content

    public init(spacing: CGFloat = 0,
                material: UI.Theme.WindowMaterial? = nil,
                tintStyle: UI.Theme.ButtonTintStyle? = nil,
                @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.material = material
        self.tintStyle = tintStyle
        self.content = content
    }

    public var body: some View {
        MaterialButton(spacing: spacing,
                       material: material,
                       tintStyle: tintStyle) {
            content()
        }
    }
}

/// A toolbar-styled menu trigger that uses the shared toolbar icon lane while keeping native menu
/// behavior.
struct MenuButton<Content: View>: View {
    public let systemName: String
    public var help: String
    @ViewBuilder public var content: () -> Content

    public init(systemName: String, help: String = "", @ViewBuilder content: @escaping () -> Content) {
        self.systemName = systemName
        self.help = help
        self.content = content
    }

    public var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: systemName)
                .font(.body.weight(.medium))
                .padding(UI.Tokens.Toolbar.iconInnerPadding)
                .frame(height: UI.Tokens.Toolbar.buttonItemHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Shared two-line toolbar label used by page switchers and filter menus.
/// The second line is always secondary so status/filter copy stays visually subordinate.
struct TitleSubtitle: View {
    public let symbol: String
    public let title: String
    public let subtitle: String
    public var showsChevron: Bool

    public init(symbol: String, title: String, subtitle: String, showsChevron: Bool = true) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self.showsChevron = showsChevron
    }

    public var body: some View {
        HStack(spacing: UI.Tokens.Toolbar.searchIconGap) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: UI.Tokens.Toolbar.buttonItemHeight - UI.Tokens.Toolbar.iconInnerPadding * 2)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .lineLimit(1)
        .padding(.trailing, UI.Tokens.Toolbar.iconInnerPadding * 2)
        .frame(height: UI.Tokens.Toolbar.buttonGroupHeight)
        .contentShape(Rectangle())
    }
}
}

public extension View {
    func subtleTileBackground() -> some View {
        background(.quaternary.opacity(UI.Tokens.InlineControl.subtleTileOpacity),
                   in: RoundedRectangle(cornerRadius: UI.Tokens.Radius.control,
                                        style: .continuous))
    }

    func toolbarControlContentShape() -> some View {
        contentShape(Capsule(style: .continuous))
    }
}

#Preview("Toolbar Controls") {
    ToolbarControlsPreview()
        .padding(UI.Tokens.Space.xl)
        .frame(width: 620)
        .environment(\.buttonMaterial, .glassClear)
}

private struct ToolbarControlsPreview: View {
    @State private var text = "preview"
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: UI.Tokens.Space.m) {
            UI.Toolbar.VanitySlot()
            UI.Toolbar.SearchField(text: $text,
                                   prompt: "Search",
                                   clearSearchLabel: "Clear search",
                                   focused: $searchFocused,
                                   onClear: { text = "" }) {
                Image(systemName: "command")
                    .foregroundStyle(.secondary)
            }
            UI.Toolbar.ActionCluster {
                UI.Toolbar.MenuButton(systemName: "line.3.horizontal.decrease.circle",
                                      help: "Filter") {
                    Button("Running") {}
                    Button("Stopped") {}
                }
                UI.Toolbar.StatusButton(help: "Runtime status", action: {}) {
                    UI.Toolbar.TitleSubtitle(symbol: "shippingbox",
                                             title: "Runtime",
                                             subtitle: "Ready")
                }
            }
            Text("Tile")
                .padding(UI.Tokens.Space.m)
                .subtleTileBackground()
        }
    }
}

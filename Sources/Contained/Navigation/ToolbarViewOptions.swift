import SwiftUI

private struct ToolbarGlassMenuButton<LabelContent: View, MenuContent: View>: View {
    @ViewBuilder var menuContent: () -> MenuContent
    @ViewBuilder var labelContent: () -> LabelContent

    init(@ViewBuilder menuContent: @escaping () -> MenuContent,
         @ViewBuilder labelContent: @escaping () -> LabelContent) {
        self.menuContent = menuContent
        self.labelContent = labelContent
    }

    var body: some View {
        Menu {
            menuContent()
        } label: {
            GlassButton(singleItem: true) {
                labelContent()
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// The page switcher seated in the titlebar. It replaces the old sidebar as the primary way to jump
/// between app pages while using the same toolbar button language as the filter control.
struct ToolbarPageSwitcher: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        ToolbarGlassMenuButton {
            ForEach(AppSectionGroup.allCases) { group in
                Section(group.rawValue) {
                    ForEach(AppSection.allCases.filter { $0.group == group }) { section in
                        Button {
                            ui.navigate(to: section)
                        } label: {
                            Label(section.title, systemImage: section.symbol)
                        }
                    }
                }
            }
        } labelContent: {
            labelContent
        }
    }

    private var labelContent: some View {
        HStack(spacing: Tokens.Toolbar.searchIconGap) {
            Image(systemName: ui.selectedSection.symbol)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: Tokens.Toolbar.buttonItemHeight - Tokens.Toolbar.iconInnerPadding * 2)
            VStack(alignment: .leading, spacing: 0) {
                Text(ui.selectedSection.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(ui.selectedSection.group.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .lineLimit(1)
        .padding(.trailing, Tokens.Toolbar.iconInnerPadding * 2)
        .frame(height: Tokens.Toolbar.buttonGroupHeight)
        .contentShape(Rectangle())
    }
}

/// Containers view options. Shows the current grouping/filter with a down chevron, and opens a menu
/// to change grouping (Network / Volume / Image / Flat), sort order, and the running-only filter.
struct ToolbarViewOptions: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        return ToolbarGlassMenuButton {
            Picker("Group by", selection: $ui.grouping) {
                ForEach(ContainerGrouping.allCases) { grouping in
                    Label(grouping.title, systemImage: grouping.symbol).tag(grouping)
                }
            }
            .pickerStyle(.inline)
            Picker("Sort by", selection: $ui.sort) {
                ForEach(ContainerSort.allCases) { sort in
                    Label(sort.title, systemImage: sort.symbol).tag(sort)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Toggle(isOn: $ui.runningOnly) {
                Label("Running only", systemImage: "play.circle")
            }
        } labelContent: {
            labelContent
        }
    }

    private var labelContent: some View {
        HStack(spacing: Tokens.Toolbar.searchIconGap) {
            Image(systemName: ui.grouping.symbol)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: Tokens.Toolbar.buttonItemHeight - Tokens.Toolbar.iconInnerPadding * 2)
            VStack(alignment: .leading, spacing: 0) {
                Text("Containers")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .lineLimit(1)
        .padding(.trailing, Tokens.Toolbar.iconInnerPadding * 2)
        .frame(height: Tokens.Toolbar.buttonGroupHeight)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts = ["by \(ui.grouping.title)"]
        if ui.runningOnly { parts.append("running") }
        return parts.joined(separator: " · ")
    }
}

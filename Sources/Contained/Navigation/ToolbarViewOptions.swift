import SwiftUI

/// The top-left "view options" control, seated just past the traffic-light cluster. Shows the current
/// Containers view as an icon + title/subtitle with a down chevron, and opens a menu to change the
/// grouping (Network / Volume / Image / Flat), the sort order, and the running-only filter.
struct ToolbarViewOptions: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        return GlassButton(singleItem: true) {
            Menu {
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
            } label: {
                labelContent
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
        }
        .fixedSize(horizontal: true, vertical: false)
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

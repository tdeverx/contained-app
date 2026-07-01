import SwiftUI
import ContainedCore

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

/// Contextual controls for the selected page. This occupies the same bottom-toolbar slot as the
/// Containers filter; pages with no page-specific filtering/actions simply omit the slot.
struct ToolbarPageContextOptions: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui

    var body: some View {
        switch ui.selectedSection {
        case .containers:
            ToolbarViewOptions()
        case .images:
            ToolbarGlassMenuButton {
                Button {
                    ui.dispatch(.loadImage)
                } label: {
                    Label("Load Image Tar", systemImage: "square.and.arrow.down")
                }
                Button {
                    Task { await app.runImageUpdateSweepNow() }
                } label: {
                    Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                Divider()
                Button(role: .destructive) {
                    ui.dispatch(.pruneImages)
                } label: {
                    Label("Prune Images", systemImage: "trash")
                }
            } labelContent: {
                contextLabel(symbol: "square.stack.3d.up",
                             title: "Images",
                             subtitle: imagesSubtitle)
            }
        case .networks:
            ToolbarGlassMenuButton {
                Button {
                    ui.dispatch(.createNetwork)
                } label: {
                    Label("New Network", systemImage: "plus")
                }
                Button {
                    Task { await app.refreshNetworks() }
                } label: {
                    Label("Refresh Networks", systemImage: "arrow.clockwise")
                }
            } labelContent: {
                contextLabel(symbol: "network",
                             title: "Networks",
                             subtitle: "\(app.networks.count) total")
            }
        case .volumes:
            ToolbarGlassMenuButton {
                Button {
                    ui.dispatch(.createVolume)
                } label: {
                    Label("New Volume", systemImage: "plus")
                }
                Button {
                    Task { await app.refreshSystemResources() }
                } label: {
                    Label("Refresh Volumes", systemImage: "arrow.clockwise")
                }
            } labelContent: {
                contextLabel(symbol: "externaldrive",
                             title: "Volumes",
                             subtitle: "\(app.volumes.count) total")
            }
        case .system:
            ToolbarGlassMenuButton {
                Button {
                    app.coordinator.wake()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Button {
                    ui.dispatch(.systemLogs)
                } label: {
                    Label("System Logs", systemImage: "text.alignleft")
                }
            } labelContent: {
                contextLabel(symbol: "gearshape.2",
                             title: "System",
                             subtitle: app.serviceLabel)
            }
        case .activity:
            @Bindable var ui = ui
            ToolbarGlassMenuButton {
                Picker("Filter", selection: $ui.activityFilter) {
                    Label("All events", systemImage: "tray.full").tag(EventKind?.none)
                    Divider()
                    ForEach(EventKind.allCases, id: \.self) { kind in
                        Label(kind.rawValue.capitalized, systemImage: kind.symbol).tag(EventKind?.some(kind))
                    }
                }
                .pickerStyle(.inline)
                Divider()
                Button {
                    app.historyStore.markAllEventsRead()
                } label: {
                    Label("Mark All Read", systemImage: "checkmark.circle")
                }
                Button(role: .destructive) {
                    app.historyStore.clearEvents()
                } label: {
                    Label("Clear Activity", systemImage: "trash")
                }
            } labelContent: {
                contextLabel(symbol: ui.activityFilter == nil ? "bell" : "line.3.horizontal.decrease.circle.fill",
                             title: "Activity",
                             subtitle: ui.activityFilter?.rawValue.capitalized ?? "All events")
            }
        case .registries:
            ToolbarGlassMenuButton {
                Button {
                    ui.dispatch(.registryLogin)
                } label: {
                    Label("Registry Login", systemImage: "person.badge.key")
                }
            } labelContent: {
                contextLabel(symbol: "key",
                             title: "Registries",
                             subtitle: "Credentials")
            }
        case .settings:
            ToolbarGlassMenuButton {
                ForEach(SettingsContent.SettingsPage.allCases) { page in
                    Button {
                        ui.openSettings(to: page)
                    } label: {
                        Label(page.rawValue, systemImage: page.systemImage)
                    }
                }
            } labelContent: {
                contextLabel(symbol: "gearshape",
                             title: "Settings",
                             subtitle: ui.settingsPage?.rawValue ?? "Sections")
            }
        case .templates:
            EmptyView()
        }
    }

    private var imagesSubtitle: String {
        let groups = LocalImageTagGroup.groups(for: app.images)
        let updates = groups.filter { app.imageUpdateStatus(for: $0.primaryReference).state == .updateAvailable }.count
        return "\(groups.count) local · \(updates) update\(updates == 1 ? "" : "s")"
    }

    private func contextLabel(symbol: String, title: String, subtitle: String) -> some View {
        HStack(spacing: Tokens.Toolbar.searchIconGap) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: Tokens.Toolbar.buttonItemHeight - Tokens.Toolbar.iconInnerPadding * 2)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
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
}

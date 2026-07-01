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
                let sections = AppSection.navigableSections(panelNavigationEnabled: ui.panelNavigationEnabled).filter { $0.group == group }
                if !sections.isEmpty {
                    Section(group.rawValue) {
                        ForEach(sections) { section in
                        Button {
                            ui.navigate(to: section)
                        } label: {
                            Label(section.title, systemImage: section.symbol)
                        }
                        }
                    }
                }
            }
        } labelContent: {
            labelContent
        }
        .help("Switch page")
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
        .help("Container filters")
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

/// Contextual controls for the selected page. These act on the current page and never open toolbar
/// morph panels; panel routing belongs to global toolbar buttons and menus.
struct ToolbarPageContextOptions: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui

    var body: some View {
        switch ui.selectedSection {
        case .containers:
            EmptyView()
        case .images:
            GlassButton {
                GlassButtonItem(systemName: "square.and.arrow.down", help: "Load Image Tar") {
                    ui.dispatch(.loadImage)
                }
                GlassButtonItem(systemName: "arrow.triangle.2.circlepath", help: "Check for Updates") {
                    Task { await app.runImageUpdateSweepNow() }
                }
                GlassButtonItem(systemName: "trash", role: .destructive, help: "Prune Images") {
                    ui.dispatch(.pruneImages)
                }
            }
            .help(imagesSubtitle)
        case .networks:
            GlassButton {
                GlassButtonItem(systemName: "plus", help: "New Network") {
                    ui.dispatch(.createNetwork)
                }
                GlassButtonItem(systemName: "arrow.clockwise", help: "Refresh Networks") {
                    Task { await app.refreshNetworks() }
                }
            }
            .help("\(app.networks.count) network\(app.networks.count == 1 ? "" : "s")")
        case .volumes:
            GlassButton {
                GlassButtonItem(systemName: "plus", help: "New Volume") {
                    ui.dispatch(.createVolume)
                }
                GlassButtonItem(systemName: "arrow.clockwise", help: "Refresh Volumes") {
                    Task { await app.refreshSystemResources() }
                }
            }
            .help("\(app.volumes.count) volume\(app.volumes.count == 1 ? "" : "s")")
        case .system:
            HStack(spacing: Tokens.Toolbar.groupSpacing) {
                GlassButton {
                    if app.serviceHealthy {
                        GlassButtonItem(systemName: "stop.fill", role: .destructive, help: "Stop service") {
                            Task { await app.stopService() }
                        }
                    } else {
                        GlassButtonItem(systemName: "play.fill", help: "Start service") {
                            Task { await app.startService() }
                        }
                    }
                    GlassButtonItem(systemName: "arrow.clockwise", help: "Restart service") {
                        Task { await app.restartService() }
                    }
                }
                GlassButton {
                    ForEach(SystemContent.SystemPage.allCases) { page in
                        GlassButtonItem(help: page.rawValue, isIcon: true, action: { ui.systemPage = page }) {
                            Image(systemName: page.systemImage)
                                .foregroundStyle(Color.white)
                                .opacity(ui.systemPage == page ? 1 : 0.62)
                        }
                    }
                    GlassButtonItem(systemName: "text.alignleft", help: "System Logs") {
                        ui.dispatch(.systemLogs)
                    }
                }
            }
        case .activity:
            GlassButton {
                GlassButtonItem(systemName: "checkmark.circle", help: "Mark all read") {
                    app.historyStore.markAllEventsRead()
                }
                GlassButtonItem(systemName: "trash", role: .destructive, help: "Clear activity") {
                    app.historyStore.clearEvents()
                }
            }
        case .registries:
            EmptyView()
        case .settings:
            GlassButton {
                ForEach(SettingsContent.SettingsPage.allCases) { page in
                    GlassButtonItem(help: page.rawValue, isIcon: true, action: {
                        ui.settingsPage = page
                        ui.navigate(to: .settings)
                    }) {
                        Image(systemName: page.systemImage)
                            .foregroundStyle(Color.white)
                    }
                }
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

}

struct ToolbarPageFilterOptions: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        switch ui.selectedSection {
        case .containers:
            ToolbarViewOptions()
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
            } labelContent: {
                activityFilterLabel
            }
            .help(ui.activityFilter == nil ? "Filter Activity" : "Filter: \(ui.activityFilter!.rawValue.capitalized)")
        default:
            EmptyView()
        }
    }

    private var activityFilterLabel: some View {
        HStack(spacing: Tokens.Toolbar.searchIconGap) {
            Image(systemName: ui.activityFilter == nil ? "line.3.horizontal.decrease"
                                                       : "line.3.horizontal.decrease.circle.fill")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: Tokens.Toolbar.buttonItemHeight - Tokens.Toolbar.iconInnerPadding * 2)
            VStack(alignment: .leading, spacing: 0) {
                Text("Activity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(ui.activityFilter?.rawValue.capitalized ?? "All events")
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

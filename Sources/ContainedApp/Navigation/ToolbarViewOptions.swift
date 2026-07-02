import SwiftUI
import ContainedDesignSystem
import SwiftData
import ContainedCore

/// The toolbar page switcher. In the experimental toolbar shell it complements the sidebar, and when
/// the sidebar is hidden it becomes the compact page-jump control.
struct ToolbarPageSwitcher: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Query private var events: [EventRecord]
    @Query private var templates: [Template]

    var body: some View {
        DesignGlassMenuButton {
            ForEach(AppSectionGroup.allCases) { group in
                let sections = AppSection.navigableSections(panelNavigationEnabled: ui.panelNavigationEnabled)
                    .filter { $0.group == group && ($0 != .build || app.settings.imageBuildEnabled) }
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
        ToolbarTitleSubtitleLabel(symbol: ui.selectedSection.symbol,
                                  title: ui.selectedSection.title,
                                  subtitle: pageSubtitle)
    }

    private var pageSubtitle: String {
        switch ui.selectedSection {
        case .containers:
            let total = app.containers.snapshots.count
            let running = app.containers.running.count
            return "\(total) container\(total == 1 ? "" : "s") · \(running) running"
        case .images:
            let groups = app.localImageGroups()
            let updates = groups.filter {
                app.imageUpdateStatus(for: $0.primaryReference).state == .updateAvailable
            }.count
            return "\(groups.count) local · \(updates) update\(updates == 1 ? "" : "s")"
        case .build:
            return "Dockerfile"
        case .volumes:
            return "\(app.volumes.count) volume\(app.volumes.count == 1 ? "" : "s")"
        case .networks:
            return "\(app.networks.count) network\(app.networks.count == 1 ? "" : "s")"
        case .system:
            return app.serviceLabel
        case .templates:
            return "\(templates.count) saved"
        case .activity:
            let unread = events.lazy.filter { !$0.isRead }.count
            let base = "\(events.count) event\(events.count == 1 ? "" : "s")"
            return unread > 0 ? "\(base) · \(unread) unread" : base
        case .settings:
            return "Preferences"
        case .registries:
            return "Credentials"
        }
    }
}

/// Containers view options. Shows the current grouping/filter with a down chevron, and opens a menu
/// to change grouping (Network / Volume / Image / Flat), sort order, and the running-only filter.
struct ToolbarViewOptions: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        return DesignGlassMenuButton {
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
        ToolbarTitleSubtitleLabel(symbol: ui.grouping.symbol,
                                  title: "Containers",
                                  subtitle: subtitle)
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
            DesignActionGroup([
                DesignAction(systemName: "square.and.arrow.down", help: AppText.loadImageTar) {
                    ui.dispatch(.loadImage)
                },
                DesignAction(systemName: "arrow.triangle.2.circlepath", help: AppText.checkForUpdates) {
                    Task { await app.runImageUpdateSweepNow() }
                },
                DesignAction(systemName: "trash", help: AppText.pruneImages, role: .destructive) {
                    ui.dispatch(.pruneImages)
                }
            ])
            .help(imagesSubtitle)
        case .build:
            EmptyView()
        case .networks:
            DesignActionGroup([
                DesignAction(systemName: "plus", help: AppText.newNetwork) {
                    ui.dispatch(.createNetwork)
                },
                DesignAction(systemName: "arrow.clockwise", help: AppText.refreshNetworks) {
                    Task { await app.refreshNetworks() }
                }
            ])
            .help("\(app.networks.count) network\(app.networks.count == 1 ? "" : "s")")
        case .volumes:
            DesignActionGroup([
                DesignAction(systemName: "plus", help: AppText.newVolume) {
                    ui.dispatch(.createVolume)
                },
                DesignAction(systemName: "arrow.clockwise", help: AppText.refreshVolumes) {
                    Task { await app.refreshSystemResources() }
                }
            ])
            .help("\(app.volumes.count) volume\(app.volumes.count == 1 ? "" : "s")")
        case .system:
            HStack(spacing: DesignTokens.Toolbar.groupSpacing) {
                DesignActionGroup(serviceActions)
                DesignActionGroup(systemPageActions + [
                    DesignAction(systemName: "text.alignleft", help: AppText.systemLogs) {
                        ui.dispatch(.systemLogs)
                    }
                ])
            }
        case .activity:
            DesignActionGroup([
                DesignAction(systemName: "checkmark.circle", help: AppText.markAllRead) {
                    app.historyStore.markAllEventsRead()
                },
                DesignAction(systemName: "trash", help: AppText.clearActivity, role: .destructive) {
                    app.historyStore.clearEvents()
                }
            ])
        case .registries:
            EmptyView()
        case .settings:
            DesignActionGroup(SettingsContent.SettingsPage.allCases.map { page in
                DesignAction(systemName: page.systemImage,
                             help: page.rawValue,
                             tint: ui.settingsPage == page ? .accentColor : nil) {
                    ui.settingsPage = page
                    ui.navigate(to: .settings)
                }
            })
        case .templates:
            EmptyView()
        }
    }

    private var serviceActions: [DesignAction] {
        let power = app.serviceHealthy
            ? DesignAction(systemName: "stop.fill", help: AppText.stopService, role: .destructive) {
                Task { await app.stopService() }
            }
            : DesignAction(systemName: "play.fill", help: AppText.startService) {
                Task { await app.startService() }
            }
        return [
            power,
            DesignAction(systemName: "arrow.clockwise", help: AppText.restartService) {
                        Task { await app.restartService() }
            }
        ]
    }

    private var systemPageActions: [DesignAction] {
        SystemContent.SystemPage.allCases.map { page in
            DesignAction(systemName: page.systemImage,
                         help: page.rawValue,
                         tint: ui.systemPage == page ? .accentColor : nil) {
                ui.systemPage = page
            }
        }
    }

    private var imagesSubtitle: String {
        let groups = app.localImageGroups()
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
        case .images:
            ImageViewOptions()
        case .build:
            EmptyView()
        case .templates:
            TemplateViewOptions()
        case .networks:
            NetworkViewOptions()
        case .activity:
            @Bindable var ui = ui
            DesignGlassMenuButton {
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
        ToolbarTitleSubtitleLabel(symbol: ui.activityFilter == nil ? "line.3.horizontal.decrease"
                                                                   : "line.3.horizontal.decrease.circle.fill",
                                  title: "Activity",
                                  subtitle: ui.activityFilter?.rawValue.capitalized ?? "All events")
    }
}

private struct ImageViewOptions: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        return DesignGlassMenuButton {
            Picker("Group by", selection: $ui.imageGrouping) {
                ForEach(ImageGrouping.allCases) { grouping in
                    Label(grouping.title, systemImage: grouping.symbol).tag(grouping)
                }
            }
            .pickerStyle(.inline)
            Picker("Sort by", selection: $ui.imageSort) {
                ForEach(ImageSort.allCases) { sort in
                    Label(sort.title, systemImage: sort.symbol).tag(sort)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Picker("Filter", selection: $ui.imageFilter) {
                ForEach(ImageFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.symbol).tag(filter)
                }
            }
            .pickerStyle(.inline)
        } labelContent: {
            optionLabel(symbol: ui.imageGrouping.symbol,
                        title: "Images",
                        subtitle: imageSubtitle)
        }
        .help("Image filters")
    }

    private var imageSubtitle: String {
        var parts = ["by \(ui.imageGrouping.title)"]
        if ui.imageFilter != .all { parts.append(ui.imageFilter.title) }
        return parts.joined(separator: " · ")
    }
}

private struct TemplateViewOptions: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        return DesignGlassMenuButton {
            Picker("Group by", selection: $ui.templateGrouping) {
                ForEach(TemplateGrouping.allCases) { grouping in
                    Label(grouping.title, systemImage: grouping.symbol).tag(grouping)
                }
            }
            .pickerStyle(.inline)
            Picker("Sort by", selection: $ui.templateSort) {
                ForEach(TemplateSort.allCases) { sort in
                    Label(sort.title, systemImage: sort.symbol).tag(sort)
                }
            }
            .pickerStyle(.inline)
        } labelContent: {
            optionLabel(symbol: ui.templateGrouping.symbol,
                        title: "Templates",
                        subtitle: "by \(ui.templateGrouping.title) · \(ui.templateSort.title)")
        }
        .help("Template grouping")
    }
}

private struct NetworkViewOptions: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        return DesignGlassMenuButton {
            Picker("Group by", selection: $ui.networkGrouping) {
                ForEach(NetworkGrouping.allCases) { grouping in
                    Label(grouping.title, systemImage: grouping.symbol).tag(grouping)
                }
            }
            .pickerStyle(.inline)
            Picker("Sort by", selection: $ui.networkSort) {
                ForEach(NetworkSort.allCases) { sort in
                    Label(sort.title, systemImage: sort.symbol).tag(sort)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Picker("Filter", selection: $ui.networkFilter) {
                ForEach(NetworkFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.symbol).tag(filter)
                }
            }
            .pickerStyle(.inline)
        } labelContent: {
            optionLabel(symbol: ui.networkGrouping.symbol,
                        title: "Networks",
                        subtitle: networkSubtitle)
        }
        .help("Network filters")
    }

    private var networkSubtitle: String {
        var parts = ["by \(ui.networkGrouping.title)"]
        if ui.networkFilter != .all { parts.append(ui.networkFilter.title) }
        return parts.joined(separator: " · ")
    }
}

@MainActor private func optionLabel(symbol: String, title: String, subtitle: String) -> some View {
    ToolbarTitleSubtitleLabel(symbol: symbol, title: title, subtitle: subtitle)
}

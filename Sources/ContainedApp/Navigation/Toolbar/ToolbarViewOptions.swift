import SwiftUI
import ContainedUI
import ContainedCore

/// The toolbar page switcher for primary resource pages.
struct ToolbarPageSwitcher: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui

    var body: some View {
        UI.Action.MenuButton {
            ForEach(AppSectionGroup.allCases) { group in
                let sections = AppSection.allCases.filter { $0.group == group }
                if !sections.isEmpty {
                    Section(group.title) {
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
        UI.Toolbar.TitleSubtitle(symbol: ui.selectedSection.symbol,
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
        case .volumes:
            return "\(app.volumes.count) volume\(app.volumes.count == 1 ? "" : "s")"
        case .networks:
            return "\(app.networks.count) network\(app.networks.count == 1 ? "" : "s")"
        }
    }
}

/// Containers view options. Shows the current grouping/filter with a down chevron, and opens a menu
/// to change grouping (Network / Volume / Image / Flat), sort order, and the running-only filter.
struct ToolbarViewOptions: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        return UI.Action.MenuButton {
            Picker(AppText.string("toolbar.groupBy", defaultValue: "Group by"), selection: $ui.grouping) {
                ForEach(ContainerGrouping.allCases) { grouping in
                    Label(grouping.title, systemImage: grouping.symbol).tag(grouping)
                }
            }
            .pickerStyle(.inline)
            Picker(AppText.string("toolbar.sortBy", defaultValue: "Sort by"), selection: $ui.sort) {
                ForEach(ContainerSort.allCases) { sort in
                    Label(sort.title, systemImage: sort.symbol).tag(sort)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Toggle(isOn: $ui.runningOnly) {
                Label(AppText.string("filter.runningOnly", defaultValue: "Running only"), systemImage: "play.circle")
            }
        } labelContent: {
            labelContent
        }
        .help(AppText.string("toolbar.containerFilters", defaultValue: "Container filters"))
    }

    private var labelContent: some View {
        UI.Toolbar.TitleSubtitle(symbol: ui.grouping.symbol,
                                  title: AppText.sectionContainers,
                                  subtitle: subtitle)
    }

    private var subtitle: String {
        var parts = [AppText.string("toolbar.groupedBy", defaultValue: "by \(ui.grouping.title)")]
        if ui.runningOnly { parts.append(AppText.string("status.running.lowercase", defaultValue: "running")) }
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
            UI.Action.Group([
                UI.Action.Item(systemName: "square.and.arrow.down", help: AppText.loadImageTar) {
                    ui.dispatch(.loadImage)
                },
                UI.Action.Item(systemName: "arrow.triangle.2.circlepath", help: AppText.checkForUpdates) {
                    Task { await app.runImageUpdateSweepNow() }
                },
                UI.Action.Item(systemName: "trash", help: AppText.pruneImages, role: .destructive) {
                    ui.dispatch(.pruneImages)
                }
            ])
            .help(imagesSubtitle)
        case .networks:
            UI.Action.Group([
                UI.Action.Item(systemName: "plus", help: AppText.newNetwork) {
                    ui.dispatch(.createNetwork)
                },
                UI.Action.Item(systemName: "arrow.clockwise", help: AppText.refreshNetworks) {
                    Task { await app.refreshNetworks() }
                }
            ])
            .help("\(app.networks.count) network\(app.networks.count == 1 ? "" : "s")")
        case .volumes:
            UI.Action.Group([
                UI.Action.Item(systemName: "plus", help: AppText.newVolume) {
                    ui.dispatch(.createVolume)
                },
                UI.Action.Item(systemName: "arrow.clockwise", help: AppText.refreshVolumes) {
                    Task { await app.refreshSystemResources() }
                }
            ])
            .help("\(app.volumes.count) volume\(app.volumes.count == 1 ? "" : "s")")
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
        case .networks:
            NetworkViewOptions()
        default:
            EmptyView()
        }
    }
}

private struct ImageViewOptions: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        return UI.Action.MenuButton {
            Picker(AppText.string("toolbar.groupBy", defaultValue: "Group by"), selection: $ui.imageGrouping) {
                ForEach(ImageGrouping.allCases) { grouping in
                    Label(grouping.title, systemImage: grouping.symbol).tag(grouping)
                }
            }
            .pickerStyle(.inline)
            Picker(AppText.string("toolbar.sortBy", defaultValue: "Sort by"), selection: $ui.imageSort) {
                ForEach(ImageSort.allCases) { sort in
                    Label(sort.title, systemImage: sort.symbol).tag(sort)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Picker(AppText.string("activity.filter", defaultValue: "Filter"), selection: $ui.imageFilter) {
                ForEach(ImageFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.symbol).tag(filter)
                }
            }
            .pickerStyle(.inline)
        } labelContent: {
            optionLabel(symbol: ui.imageGrouping.symbol,
                        title: AppText.sectionImages,
                        subtitle: imageSubtitle)
        }
        .help(AppText.string("toolbar.imageFilters", defaultValue: "Image filters"))
    }

    private var imageSubtitle: String {
        var parts = [AppText.string("toolbar.groupedBy", defaultValue: "by \(ui.imageGrouping.title)")]
        if ui.imageFilter != .all { parts.append(ui.imageFilter.title) }
        return parts.joined(separator: " · ")
    }
}

private struct NetworkViewOptions: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        return UI.Action.MenuButton {
            Picker(AppText.string("toolbar.groupBy", defaultValue: "Group by"), selection: $ui.networkGrouping) {
                ForEach(NetworkGrouping.allCases) { grouping in
                    Label(grouping.title, systemImage: grouping.symbol).tag(grouping)
                }
            }
            .pickerStyle(.inline)
            Picker(AppText.string("toolbar.sortBy", defaultValue: "Sort by"), selection: $ui.networkSort) {
                ForEach(NetworkSort.allCases) { sort in
                    Label(sort.title, systemImage: sort.symbol).tag(sort)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Picker(AppText.string("activity.filter", defaultValue: "Filter"), selection: $ui.networkFilter) {
                ForEach(NetworkFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.symbol).tag(filter)
                }
            }
            .pickerStyle(.inline)
        } labelContent: {
            optionLabel(symbol: ui.networkGrouping.symbol,
                        title: AppText.sectionNetworks,
                        subtitle: networkSubtitle)
        }
        .help(AppText.string("toolbar.networkFilters", defaultValue: "Network filters"))
    }

    private var networkSubtitle: String {
        var parts = [AppText.string("toolbar.groupedBy", defaultValue: "by \(ui.networkGrouping.title)")]
        if ui.networkFilter != .all { parts.append(ui.networkFilter.title) }
        return parts.joined(separator: " · ")
    }
}

@MainActor private func optionLabel(symbol: String, title: String, subtitle: String) -> some View {
    UI.Toolbar.TitleSubtitle(symbol: symbol, title: title, subtitle: subtitle)
}

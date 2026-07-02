import SwiftUI
import ContainedDesignSystem
import ContainedCore

/// A palette search scope. Pins a chip to the search field and searches in-place instead of leaving
/// the palette — Docker Hub (live registry search) or the local image store.
enum PaletteScope: Hashable {
    case dockerHub
    case localImages

    var title: String {
        switch self {
        case .dockerHub:   return AppText.paletteDockerHub
        case .localImages: return AppText.paletteLocalImages
        }
    }

    var symbol: String {
        switch self {
        case .dockerHub:   return "globe"
        case .localImages: return "square.stack.3d.up"
        }
    }

    var placeholder: String {
        switch self {
        case .dockerHub:   return AppText.paletteSearchDockerHubPlaceholder
        case .localImages: return AppText.paletteFilterLocalImagesPlaceholder
        }
    }
}

/// One command-palette entry: a titled, icon'd action.
struct PaletteItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    var keywords: [String] = []
    var kind: PaletteItemKind = .action
    var accessory: PaletteItemAccessory = .run
    var visual: PaletteItemVisual = .plain
    /// When true, running the item does not dismiss the palette (used by scope-setting entries that
    /// search in-place).
    var keepsPaletteOpen = false
    let icon: String
    let tint: Color
    let action: () -> Void

    /// Every available command: toolbar-panel navigation, creation, global maintenance, settings,
    /// and resource-specific lifecycle. Add newly exposed app functionality in the section matching
    /// its scope so the command palette remains the human-readable action index.
    @MainActor
    static func all(app: AppModel, ui: UIState) -> [PaletteItem] {
        var items: [PaletteItem] = []
        for section in AppSection.navigableSections(panelNavigationEnabled: ui.panelNavigationEnabled)
            where section != .build || app.settings.imageBuildEnabled {
            items.append(PaletteItem(title: section.title,
                                     subtitle: section.group.title,
                                     kind: .navigation,
                                     icon: section.symbol,
                                     tint: .secondary) {
                ui.navigate(to: section)
            })
        }
        // Add anything, from anywhere. (Pulling an image is covered by the Docker Hub search scope
        // below, so there's no separate "Pull an image" entry.)
        let adds: [(String, String, PendingAction)] = [
            (AppText.paletteRunContainer, "shippingbox", .runContainer),
            (AppText.paletteNewVolume, "externaldrive.badge.plus", .createVolume),
            (AppText.paletteNewNetwork, "network", .createNetwork),
        ]
        for (title, icon, action) in adds {
            items.append(PaletteItem(title: title, subtitle: AppText.paletteCreateSubtitle, kind: .create, icon: icon, tint: .accentColor) {
                ui.dispatch(action)
            })
        }
        if app.settings.composeImportEnabled {
            items.append(PaletteItem(title: AppText.paletteImportCompose,
                                     subtitle: AppText.paletteCreateSubtitle,
                                     kind: .create,
                                     icon: "square.on.square",
                                     tint: .accentColor) {
                ComposeImport.pickAndImport(app: app, ui: ui)
            })
        }
        // Registry credentials live on the Settings → Registries page, not as a standalone app page.
        items.append(PaletteItem(title: AppText.paletteRegistryLogin, subtitle: AppText.paletteCreateSubtitle,
                                 keywords: ["registry", "credentials", "docker login", "sign in"],
                                 kind: .create, icon: "person.badge.key", tint: .accentColor) {
            ui.openSettings(to: .registries)
        })
        // Search scopes: these pin a chip to the search field and search in-place (they keep the
        // palette open) instead of opening another panel.
        if app.settings.hubSearchEnabled {
            items.append(PaletteItem(title: AppText.paletteSearchDockerHub, subtitle: AppText.paletteScopeSubtitle,
                                     keywords: ["registry", "pull", "dockerhub", "image"],
                                     kind: .search, keepsPaletteOpen: true,
                                     icon: "globe", tint: .accentColor) {
                ui.paletteScope = .dockerHub
            })
        }
        items.append(PaletteItem(title: AppText.paletteSearchLocalImages, subtitle: AppText.paletteScopeSubtitle,
                                 keywords: ["image", "tag", "local", "filter"],
                                 kind: .search, keepsPaletteOpen: true,
                                 icon: "square.stack.3d.up", tint: .accentColor) {
            ui.paletteScope = .localImages
        })
        // Page / global actions.
        items.append(PaletteItem(title: AppText.paletteRefresh,
                                 subtitle: AppText.paletteActionSubtitle,
                                 kind: .action,
                                 icon: "arrow.clockwise",
                                 tint: .secondary) {
            app.coordinator.wake()
        })
        items.append(PaletteItem(title: AppText.paletteCheckAppUpdates, subtitle: AppText.paletteUpdatesSubtitle,
                                 keywords: ["sparkle", "software", "release"],
                                 kind: .action,
                                 accessory: app.updater.canCheckForUpdates ? .run : .disabled(AppText.paletteUnavailable),
                                 icon: "arrow.down.app", tint: .blue) {
            if app.updater.canCheckForUpdates {
                app.updater.checkForUpdates()
            } else {
                app.flash(AppText.appUpdateChecksUnavailable)
            }
        })
        items.append(PaletteItem(title: AppText.paletteCheckAllImageUpdates, subtitle: app.imageUpdateIntervalDescription,
                                 keywords: ["updates", "tags", "registry", "all images"],
                                 kind: .image, icon: "arrow.triangle.2.circlepath", tint: .blue) {
            Task { await app.runImageUpdateSweepNow() }
        })
        items.append(PaletteItem(title: AppText.paletteUpdateAllImages, subtitle: AppText.palettePullNewerTagsSubtitle,
                                 keywords: ["pull", "updates", "tags", "all images"],
                                 kind: .image, icon: "arrow.down.circle", tint: .orange) {
            Task { await app.pullAvailableImageUpdates(manual: true) }
        })
        items.append(PaletteItem(title: AppText.paletteCheckAllContainerImages,
                                 subtitle: AppText.paletteContainerCountSubtitle(app.containers.snapshots.count),
                                 keywords: ["container updates", "check all containers", "image updates"],
                                 kind: .container, icon: "shippingbox.and.arrow.backward", tint: .blue) {
            Task { await app.checkContainerImageUpdates() }
        })
        items.append(PaletteItem(title: AppText.palettePullContainerImageUpdates,
                                 subtitle: AppText.paletteDoesNotRecreateContainersSubtitle,
                                 keywords: ["update all containers", "pull container images", "container image updates"],
                                 kind: .container, icon: "arrow.down.circle", tint: .orange) {
            Task { await app.pullAvailableContainerImageUpdates() }
        })
        // Maintenance actions. Load uses a native open panel and Prune a native confirmation.
        let pageActions: [(String, String, PendingAction)] = [
            (AppText.paletteLoadImageTar, "square.and.arrow.down", .loadImage),
            (AppText.palettePruneImages, "trash", .pruneImages),
        ]
        for (title, icon, action) in pageActions {
            items.append(PaletteItem(title: title, subtitle: AppText.paletteActionSubtitle, kind: .action, icon: icon, tint: .secondary) {
                ui.dispatch(action)
            })
        }
        items.append(PaletteItem(title: AppText.paletteSystemLogs, subtitle: AppText.paletteActionSubtitle,
                                 keywords: ["service", "runtime", "diagnostics"],
                                 kind: .action, icon: "text.alignleft", tint: .secondary) {
            ui.dispatch(.systemLogs)
        })
        items.append(contentsOf: settingsItems(app: app, ui: ui))
        items.append(contentsOf: imageItems(app: app, ui: ui))
        items.append(contentsOf: volumeItems(app: app, ui: ui))
        items.append(contentsOf: networkItems(app: app, ui: ui))
        for snapshot in app.containers.snapshots {
            let name = app.containerStyle(for: snapshot)
                .displayName(fallback: snapshot.id)
            items.append(PaletteItem(title: AppText.paletteEditContainer(name),
                                     subtitle: AppText.paletteContainerSubtitle,
                                     keywords: [snapshot.id, snapshot.image],
                                     kind: .container,
                                     visual: .container(snapshot),
                                     icon: "slider.horizontal.3", tint: .secondary) {
                ui.openCreationPanel(editing: snapshot)
            })
            items.append(PaletteItem(title: AppText.paletteUpdateContainerImage(name), subtitle: snapshot.image, keywords: [snapshot.id, snapshot.image],
                                     kind: .container,
                                     visual: .container(snapshot),
                                     icon: "arrow.down.circle", tint: .blue) {
                Task {
                    if await app.pullImageUpdate(snapshot.image) {
                        ui.openCreationPanel(editing: snapshot)
                    }
                }
            })
            if snapshot.state == .running {
                items.append(PaletteItem(title: AppText.paletteStopContainer(name),
                                         subtitle: AppText.paletteContainerSubtitle,
                                         kind: .container, visual: .container(snapshot), icon: "stop.fill", tint: .orange) {
                    Task { await app.containers.stop(snapshot.id) }
                })
                items.append(PaletteItem(title: AppText.paletteRestartContainer(name),
                                         subtitle: AppText.paletteContainerSubtitle,
                                         kind: .container, visual: .container(snapshot), icon: "arrow.clockwise", tint: .blue) {
                    Task { await app.containers.restart(snapshot.id) }
                })
            } else {
                items.append(PaletteItem(title: AppText.paletteStartContainer(name),
                                         subtitle: AppText.paletteContainerSubtitle,
                                         kind: .container, visual: .container(snapshot), icon: "play.fill", tint: .green) {
                    Task { await app.containers.start(snapshot.id) }
                })
            }
        }
        return deduplicated(items)
    }

    static func deduplicated(_ items: [PaletteItem]) -> [PaletteItem] {
        var seen = Set<String>()
        return items.filter { item in
            seen.insert("\(item.kind.rawValue)|\(item.title)|\(item.subtitle ?? "")").inserted
        }
    }

    @MainActor
    private static func settingsItems(app: AppModel, ui: UIState) -> [PaletteItem] {
        let settingsPages: [(SettingsContent.SettingsPage, String)] = [
            (.appearance, "paintpalette"),
            (.general, "gearshape"),
            (.runtime, "cpu"),
            (.registries, "key"),
            (.updates, "arrow.down.app"),
            (.about, "info.circle"),
        ]
        var items = settingsPages.map { page, icon in
            PaletteItem(title: AppText.paletteSettingsTitle(page.rawValue), subtitle: AppText.paletteSettingsSubtitle,
                        keywords: ["preferences", page.rawValue.lowercased()],
                        kind: .settings, icon: icon, tint: .secondary) {
                ui.openSettings(to: page)
            }
        }
        items.append(PaletteItem(title: app.settings.runningOnlyTitle(ui.runningOnly),
                                 subtitle: AppText.paletteToggleSubtitle,
                                 keywords: ["filter", "containers"],
                                 kind: .toggle,
                                 accessory: .toggle(isOn: { ui.runningOnly },
                                                    set: { ui.runningOnly = $0 }),
                                 icon: "play.circle",
                                 tint: .secondary) {
                ui.runningOnly.toggle()
        })
        items.append(PaletteItem(title: app.settings.keepInMenuBar ? AppText.paletteHideMenuBarItem : AppText.paletteShowMenuBarItem,
                                 subtitle: AppText.paletteToggleSubtitle,
                                 keywords: ["setting", "menubar", "menu bar"],
                                 kind: .toggle,
                                 accessory: .toggle(isOn: { app.settings.keepInMenuBar },
                                                    set: { app.settings.keepInMenuBar = $0 }),
                                 icon: "menubar.rectangle",
                                 tint: .secondary) {
            app.settings.keepInMenuBar.toggle()
        })
        items.append(PaletteItem(title: app.settings.revealCLI ? AppText.paletteHideCLIPreviews : AppText.paletteShowCLIPreviews,
                                 subtitle: AppText.paletteToggleSubtitle,
                                 keywords: ["setting", "command", "terminal"],
                                 kind: .toggle,
                                 accessory: .toggle(isOn: { app.settings.revealCLI },
                                                    set: { app.settings.revealCLI = $0 }),
                                 icon: "terminal",
                                 tint: .secondary) {
            app.settings.revealCLI.toggle()
        })
        items.append(PaletteItem(title: app.settings.showInfoTips ? AppText.paletteHideInfoTips : AppText.paletteShowInfoTips,
                                 subtitle: AppText.paletteToggleSubtitle,
                                 keywords: ["setting", "help", "popover"],
                                 kind: .toggle,
                                 accessory: .toggle(isOn: { app.settings.showInfoTips },
                                                    set: { app.settings.showInfoTips = $0 }),
                                 icon: "info.circle",
                                 tint: .secondary) {
            app.settings.showInfoTips.toggle()
        })
        for tint in DesignTint.allCases {
            items.append(PaletteItem(title: AppText.setDesignTintTitle(tint.localizedDisplayName),
                                     subtitle: AppText.paletteAppearanceSubtitle,
                                     keywords: ["accent", "color", "theme", "tint", tint.rawValue] + tint.localizedSearchAliases,
                                     kind: .settings,
                                     visual: .tint(tint),
                                     icon: "paintpalette",
                                     tint: tint.color) {
                app.settings.accentTint = tint
            })
        }
        return items
    }

    @MainActor
    private static func imageItems(app: AppModel, ui: UIState) -> [PaletteItem] {
        var items: [PaletteItem] = []
        let groups = app.localImageGroups()
        for group in groups {
            items.append(PaletteItem(title: AppText.paletteRunImage(Format.shortImage(group.primaryReference)),
                                     subtitle: AppText.paletteLocalImageSubtitle,
                                     keywords: group.references,
                                     kind: .image,
                                     visual: .imageGroup(group),
                                     icon: "play.fill",
                                     tint: .green) {
                ui.runImage(group.primaryReference)
            })
            items.append(PaletteItem(title: AppText.paletteCheckImageUpdate(Format.shortImage(group.primaryReference)),
                                     subtitle: AppText.paletteImageSubtitle,
                                     keywords: group.references,
                                     kind: .image,
                                     visual: .imageGroup(group),
                                     icon: "arrow.triangle.2.circlepath",
                                     tint: .blue) {
                Task { await app.checkImageUpdate(group.primaryReference) }
            })
            if app.imageUpdateStatus(for: group.primaryReference).state == .updateAvailable {
                items.append(PaletteItem(title: AppText.palettePullImageUpdate(Format.shortImage(group.primaryReference)),
                                         subtitle: AppText.paletteImageSubtitle,
                                         keywords: group.references,
                                         kind: .image,
                                         visual: .imageGroup(group),
                                         icon: "arrow.down.circle",
                                         tint: .orange) {
                    Task { await app.pullImageUpdate(group.primaryReference) }
                })
            }
            for reference in group.references where reference != group.primaryReference {
                items.append(PaletteItem(title: AppText.paletteRunImage(Format.shortImage(reference)),
                                         subtitle: AppText.paletteImageTagSubtitle,
                                         keywords: [group.primaryReference, reference],
                                         kind: .image,
                                         visual: .imageTag(reference, groupID: group.id),
                                         icon: "tag",
                                         tint: .green) {
                    ui.runImage(reference)
                })
            }
        }
        return items
    }

    @MainActor
    private static func volumeItems(app: AppModel, ui: UIState) -> [PaletteItem] {
        app.volumes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { volume in
                PaletteItem(title: AppText.paletteUseVolume(volume.name),
                            subtitle: AppText.paletteVolumeSubtitle,
                            keywords: ["storage", volume.name],
                            kind: .resource,
                            visual: .volume(volume),
                            icon: "externaldrive",
                            tint: .secondary) {
                    var spec = RunSpec()
                    spec.volumes = [VolumeMap(source: volume.name, target: "/data")]
                    ui.openCreationPanel(entry: .configure, prefill: spec)
                }
            }
    }

    @MainActor
    private static func networkItems(app: AppModel, ui: UIState) -> [PaletteItem] {
        app.networks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { network in
                PaletteItem(title: AppText.paletteRunOnNetwork(network.name),
                            subtitle: network.isBuiltin ? AppText.paletteBuiltInNetworkSubtitle : AppText.paletteNetworkSubtitle,
                            keywords: ["network", network.name],
                            kind: .resource,
                            visual: .network(network),
                            icon: "network",
                            tint: .secondary) {
                    var spec = RunSpec()
                    spec.network = network.name
                    ui.openCreationPanel(entry: .configure, prefill: spec)
                }
            }
    }

    /// Filter `all(...)` by a query — substring or per-word prefix (predictable for a small set).
    @MainActor
    static func filtered(_ query: String, app: AppModel, ui: UIState) -> [PaletteItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let items = all(app: app, ui: ui)
        guard !q.isEmpty else { return items }
        return items
            .compactMap { item -> (PaletteItem, Int)? in
                PaletteSearch.score(query: q, in: item.searchFields).map { (item, $0) }
            }
            .sorted {
                if $0.1 != $1.1 { return $0.1 > $1.1 }
                return $0.0.title.localizedCaseInsensitiveCompare($1.0.title) == .orderedAscending
            }
            .map(\.0)
    }

    private var searchFields: [String] {
        [title, subtitle ?? ""] + keywords
    }
}

enum PaletteItemKind: String {
    case action = "Action"
    case create = "Create"
    case navigation = "Navigate"
    case settings = "Settings"
    case toggle = "Toggle"
    case image = "Image"
    case container = "Container"
    case resource = "Resource"
    case search = "Search"

    /// The browse-mode section a kind belongs under, with a stable display order. Used to group the
    /// palette into labelled sections when there's no active query.
    var section: (order: Int, title: String) {
        switch self {
        case .navigation:        return (0, AppText.paletteKindNavigate)
        case .create, .search:   return (1, AppText.paletteSectionCreateSearch)
        case .container:         return (2, AppText.paletteSectionContainers)
        case .image:             return (3, AppText.paletteSectionImages)
        case .resource:          return (4, AppText.paletteSectionVolumesNetworks)
        case .settings, .toggle: return (5, AppText.paletteKindSettings)
        case .action:            return (6, AppText.paletteSectionActions)
        }
    }

    var localizedTitle: String {
        switch self {
        case .action: AppText.paletteKindAction
        case .create: AppText.paletteKindCreate
        case .navigation: AppText.paletteKindNavigate
        case .settings: AppText.paletteKindSettings
        case .toggle: AppText.paletteKindToggle
        case .image: AppText.paletteKindImage
        case .container: AppText.paletteKindContainer
        case .resource: AppText.paletteKindResource
        case .search: AppText.paletteKindSearch
        }
    }
}

enum PaletteItemAccessory {
    case run
    case toggle(isOn: () -> Bool, set: (Bool) -> Void)
    case disabled(String)
}

enum PaletteItemVisual {
    case plain
    case container(ContainerSnapshot)
    case imageGroup(LocalImageTagGroup)
    case imageTag(String, groupID: String)
    case volume(VolumeResource)
    case network(NetworkResource)
    case tint(DesignTint)
}

private extension SettingsStore {
    func runningOnlyTitle(_ runningOnly: Bool) -> String {
        runningOnly ? AppText.paletteShowAllContainers : AppText.paletteShowRunningContainersOnly
    }
}

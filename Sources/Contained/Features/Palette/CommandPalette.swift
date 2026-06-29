import SwiftUI
import ContainedCore

/// One command-palette entry: a titled, icon'd action.
struct PaletteItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    var keywords: [String] = []
    var kind: PaletteItemKind = .action
    var accessory: PaletteItemAccessory = .run
    let icon: String
    let tint: Color
    let action: () -> Void

    /// Every available command: toolbar-panel navigation, add actions, global actions, and
    /// per-container lifecycle.
    @MainActor
    static func all(app: AppModel, ui: UIState) -> [PaletteItem] {
        var items: [PaletteItem] = []
        items.append(PaletteItem(title: "Containers", subtitle: "navigate",
                                 kind: .navigation,
                                 icon: "shippingbox", tint: .secondary) { ui.activeMorph = nil })
        // Toolbar panels open the matching morph.
        let panels: [(String, String, UIState.ToolbarMorph)] = [
            ("Images", "shippingbox.fill", .updates),
            ("Templates", "bookmark", .templates),
            ("Activity", "bell", .activity),
            ("System", "gearshape.2", .system),
            ("Settings", "gearshape", .settings),
        ]
        for (title, icon, morph) in panels {
            items.append(PaletteItem(title: title, subtitle: "navigate", kind: .navigation, icon: icon, tint: .secondary) {
                ui.toggleMorph(morph)
            })
        }
        // Add anything, from anywhere.
        let adds: [(String, String, PendingAction)] = [
            ("Run a container", "shippingbox", .runContainer),
            ("Pull an image", "arrow.down.circle", .pullImage),
            ("New volume", "externaldrive.badge.plus", .createVolume),
            ("New network", "network", .createNetwork),
            ("Registry login", "person.badge.key", .registryLogin),
        ]
        for (title, icon, action) in adds {
            items.append(PaletteItem(title: title, subtitle: "create", kind: .create, icon: icon, tint: .accentColor) {
                ui.dispatch(action)
            })
        }
        items.append(PaletteItem(title: "Import compose…", subtitle: "create", kind: .create, icon: "square.on.square", tint: .accentColor) {
            ComposeImport.pickAndImport(app: app, ui: ui)
        })
        items.append(PaletteItem(title: "Search Docker Hub", subtitle: "images", keywords: ["registry", "pull", "dockerhub"],
                                 kind: .search, icon: "magnifyingglass", tint: .accentColor) {
            ui.openCreationPanel(entry: .search)
        })
        // Page / global actions.
        items.append(PaletteItem(title: "Refresh", subtitle: "action", kind: .action, icon: "arrow.clockwise", tint: .secondary) {
            app.coordinator.wake()
        })
        let pageActions: [(String, String, PendingAction)] = [
            ("Load image tar…", "square.and.arrow.down", .loadImage),
            ("Prune images…", "trash", .pruneImages),
            ("Activity history", "bell", .activityHistory),
            ("System logs", "text.alignleft", .systemLogs),
        ]
        for (title, icon, action) in pageActions {
            items.append(PaletteItem(title: title, subtitle: "action", kind: .action, icon: icon, tint: .secondary) {
                ui.dispatch(action)
            })
        }
        items.append(contentsOf: settingsItems(app: app, ui: ui))
        items.append(contentsOf: imageItems(app: app, ui: ui))
        items.append(contentsOf: volumeItems(app: app, ui: ui))
        items.append(contentsOf: networkItems(app: app, ui: ui))
        for snapshot in app.containers.snapshots {
            let name = app.containerStyle(for: snapshot)
                .displayName(fallback: snapshot.id)
            items.append(PaletteItem(title: "Edit \(name)", subtitle: "container", keywords: [snapshot.id, snapshot.image],
                                     kind: .container, icon: "slider.horizontal.3", tint: .secondary) {
                ui.openCreationPanel(editing: snapshot)
            })
            items.append(PaletteItem(title: "Update image for \(name)", subtitle: snapshot.image, keywords: [snapshot.id, snapshot.image],
                                     kind: .container, icon: "arrow.down.circle", tint: .blue) {
                Task { _ = await app.pullImageUpdate(snapshot.image) }
            })
            if snapshot.state == .running {
                items.append(PaletteItem(title: "Stop \(name)", subtitle: "container", kind: .container, icon: "stop.fill", tint: .orange) {
                    Task { await app.containers.stop(snapshot.id) }
                })
                items.append(PaletteItem(title: "Restart \(name)", subtitle: "container", kind: .container, icon: "arrow.clockwise", tint: .blue) {
                    Task { await app.containers.restart(snapshot.id) }
                })
            } else {
                items.append(PaletteItem(title: "Start \(name)", subtitle: "container", kind: .container, icon: "play.fill", tint: .green) {
                    Task { await app.containers.start(snapshot.id) }
                })
            }
        }
        return items
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
            PaletteItem(title: "\(page.rawValue) Settings", subtitle: "settings",
                        keywords: ["preferences", page.rawValue.lowercased()],
                        kind: .settings, icon: icon, tint: .secondary) {
                ui.openSettings(to: page)
            }
        }
        items.append(PaletteItem(title: app.settings.runningOnlyTitle(ui.runningOnly),
                                 subtitle: "toggle",
                                 keywords: ["filter", "containers"],
                                 kind: .toggle,
                                 accessory: .toggle(isOn: { ui.runningOnly },
                                                    set: { ui.runningOnly = $0 }),
                                 icon: "play.circle",
                                 tint: .secondary) {
            ui.runningOnly.toggle()
        })
        items.append(PaletteItem(title: app.settings.keepInMenuBar ? "Hide Menu Bar Item" : "Show Menu Bar Item",
                                 subtitle: "toggle",
                                 keywords: ["setting", "menubar", "menu bar"],
                                 kind: .toggle,
                                 accessory: .toggle(isOn: { app.settings.keepInMenuBar },
                                                    set: { app.settings.keepInMenuBar = $0 }),
                                 icon: "menubar.rectangle",
                                 tint: .secondary) {
            app.settings.keepInMenuBar.toggle()
        })
        items.append(PaletteItem(title: app.settings.revealCLI ? "Hide CLI Previews" : "Show CLI Previews",
                                 subtitle: "toggle",
                                 keywords: ["setting", "command", "terminal"],
                                 kind: .toggle,
                                 accessory: .toggle(isOn: { app.settings.revealCLI },
                                                    set: { app.settings.revealCLI = $0 }),
                                 icon: "terminal",
                                 tint: .secondary) {
            app.settings.revealCLI.toggle()
        })
        items.append(PaletteItem(title: app.settings.showInfoTips ? "Hide Info Tips" : "Show Info Tips",
                                 subtitle: "toggle",
                                 keywords: ["setting", "help", "popover"],
                                 kind: .toggle,
                                 accessory: .toggle(isOn: { app.settings.showInfoTips },
                                                    set: { app.settings.showInfoTips = $0 }),
                                 icon: "info.circle",
                                 tint: .secondary) {
            app.settings.showInfoTips.toggle()
        })
        return items
    }

    @MainActor
    private static func imageItems(app: AppModel, ui: UIState) -> [PaletteItem] {
        var items: [PaletteItem] = []
        let groups = LocalImageTagGroup.groups(for: app.images)
            .sorted { $0.primaryReference.localizedCaseInsensitiveCompare($1.primaryReference) == .orderedAscending }
        for group in groups {
            items.append(PaletteItem(title: "Run \(Format.shortImage(group.primaryReference))",
                                     subtitle: "local image",
                                     keywords: group.references,
                                     kind: .image,
                                     icon: "play.fill",
                                     tint: .green) {
                ui.runImage(group.primaryReference)
            })
            items.append(PaletteItem(title: "Check update for \(Format.shortImage(group.primaryReference))",
                                     subtitle: "image",
                                     keywords: group.references,
                                     kind: .image,
                                     icon: "arrow.triangle.2.circlepath",
                                     tint: .blue) {
                Task { await app.checkImageUpdate(group.primaryReference) }
            })
            for reference in group.references where reference != group.primaryReference {
                items.append(PaletteItem(title: "Run \(Format.shortImage(reference))",
                                         subtitle: "image tag",
                                         keywords: [group.primaryReference, reference],
                                         kind: .image,
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
                PaletteItem(title: "Use volume \(volume.name)",
                            subtitle: "volume",
                            keywords: ["storage", volume.name],
                            kind: .resource,
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
                PaletteItem(title: "Run on network \(network.name)",
                            subtitle: network.isBuiltin ? "built-in network" : "network",
                            keywords: ["network", network.name],
                            kind: .resource,
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
}

enum PaletteItemAccessory {
    case run
    case toggle(isOn: () -> Bool, set: (Bool) -> Void)
}

private extension SettingsStore {
    func runningOnlyTitle(_ runningOnly: Bool) -> String {
        runningOnly ? "Show All Containers" : "Show Running Containers Only"
    }
}

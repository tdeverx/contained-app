import SwiftUI
import ContainedCore

/// One command-palette entry: a titled, icon'd action.
struct PaletteItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    let action: () -> Void

    /// Every available command: navigation, add actions, page/global actions, and per-container
    /// lifecycle. This is the app's single command surface now that the sidebar and toolbar are gone.
    @MainActor
    static func all(app: AppModel, ui: UIState) -> [PaletteItem] {
        var items: [PaletteItem] = []
        items.append(PaletteItem(title: "Containers", subtitle: "navigate",
                                 icon: "shippingbox", tint: .secondary) { ui.activeMorph = nil })
        // Toolbar panels (the former sidebar pages) — open the matching morph.
        let panels: [(String, String, UIState.ToolbarMorph)] = [
            ("Images", "shippingbox.fill", .updates),
            ("Templates", "bookmark", .templates),
            ("Activity", "bell", .activity),
            ("System", "gearshape.2", .system),
        ]
        for (title, icon, morph) in panels {
            items.append(PaletteItem(title: title, subtitle: "navigate", icon: icon, tint: .secondary) {
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
            items.append(PaletteItem(title: title, subtitle: "create", icon: icon, tint: .accentColor) {
                ui.dispatch(action)
            })
        }
        items.append(PaletteItem(title: "Import compose…", subtitle: "create", icon: "square.on.square", tint: .accentColor) {
            ComposeImport.pickAndImport(app: app, ui: ui)
        })
        // Page / global actions.
        items.append(PaletteItem(title: "Refresh", subtitle: "action", icon: "arrow.clockwise", tint: .secondary) {
            app.coordinator.wake()
        })
        let pageActions: [(String, String, PendingAction)] = [
            ("Load image tar…", "square.and.arrow.down", .loadImage),
            ("Prune images…", "trash", .pruneImages),
            ("Activity history", "bell", .activityHistory),
            ("System logs", "text.alignleft", .systemLogs),
        ]
        for (title, icon, action) in pageActions {
            items.append(PaletteItem(title: title, subtitle: "action", icon: icon, tint: .secondary) {
                ui.dispatch(action)
            })
        }
        for snapshot in app.containers.snapshots {
            let name = app.containerStyle(for: snapshot)
                .displayName(fallback: snapshot.id)
            if snapshot.state == .running {
                items.append(PaletteItem(title: "Stop \(name)", subtitle: "container", icon: "stop.fill", tint: .orange) {
                    Task { await app.containers.stop(snapshot.id) }
                })
                items.append(PaletteItem(title: "Restart \(name)", subtitle: "container", icon: "arrow.clockwise", tint: .blue) {
                    Task { await app.containers.restart(snapshot.id) }
                })
            } else {
                items.append(PaletteItem(title: "Start \(name)", subtitle: "container", icon: "play.fill", tint: .green) {
                    Task { await app.containers.start(snapshot.id) }
                })
            }
        }
        return items
    }

    /// Filter `all(...)` by a query — substring or per-word prefix (predictable for a small set).
    @MainActor
    static func filtered(_ query: String, app: AppModel, ui: UIState) -> [PaletteItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let items = all(app: app, ui: ui)
        guard !q.isEmpty else { return items }
        return items.filter { item in
            let t = item.title.lowercased()
            return t.contains(q) || t.split(separator: " ").contains { $0.hasPrefix(q) }
        }
    }
}

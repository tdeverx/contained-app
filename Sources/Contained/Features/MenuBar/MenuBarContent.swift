import SwiftUI
import AppKit
import ContainedCore

/// The menu shown by the menu-bar extra: running containers with quick start/stop, service status
/// and controls, and shortcuts to open the app / run a container. Reads the same stores as the
/// window, so the `RefreshCoordinator` keeps it live.
struct MenuBarContent: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui

    private var store: ContainersStore { app.containers }

    var body: some View {
        // Service status + controls.
        Text(app.serviceHealthy ? "Service running" : "Service \(app.serviceLabel.lowercased())")
        if app.serviceHealthy {
            Button("Stop service") { Task { await app.stopService() } }
        } else {
            Button("Start service") { Task { await app.startService() } }
        }
        Button("Restart service") { Task { await app.restartService() } }

        Divider()

        if store.running.isEmpty {
            Text("No running containers")
        } else {
            ForEach(store.running) { snapshot in
                let name = app.containerStyle(for: snapshot)
                    .displayName(fallback: snapshot.id)
                Button("Stop \(name)") { Task { await store.stop(snapshot.id) } }
            }
        }

        let stopped = store.snapshots.filter { $0.state != .running }
        if !stopped.isEmpty {
            Divider()
            Menu("Start…") {
                ForEach(stopped) { snapshot in
                    let name = app.containerStyle(for: snapshot)
                        .displayName(fallback: snapshot.id)
                    Button(name) { Task { await store.start(snapshot.id) } }
                }
            }
        }

        Divider()

        Button("Run a Container…") { activate(); route(.runContainer) }
        if app.settings.hubSearchEnabled {
            Button("Pull Image…") { activate(); route(.pullImage) }
        }

        Divider()

        Button("Images") { activate(); openSectionOrMorph(.images, morph: .updates) }
        Button("Templates") { activate(); openSectionOrMorph(.templates, morph: .templates) }
        Button("System") { activate(); openSectionOrMorph(.system, morph: .system) }
        Button("Activity") { activate(); openSectionOrMorph(.activity, morph: .activity) }

        Divider()

        Button("Open Contained") { activate() }
        // Deep-link straight to a Settings page via the panel jump system (`openSettings(to:)`).
        Menu("Settings…") {
            ForEach(SettingsContent.SettingsPage.allCases) { page in
                Button(page.rawValue) { activate(); openSettings(to: page) }
            }
        }
        Button("About Contained") { activate(); openSettings(to: .about) }
        Divider()
        Button("Quit Contained") { NSApplication.shared.terminate(nil) }
    }

    /// Bring the main window to the front.
    private func activate() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            break
        }
    }

    private func route(_ action: PendingAction) {
        if app.settings.experimentalToolbarUI {
            ui.dispatch(action)
        } else {
            ui.navigateForClassicFallback(action)
        }
    }

    private func openSectionOrMorph(_ section: AppSection, morph: UIState.ToolbarMorph) {
        if app.settings.experimentalToolbarUI {
            ui.toggleMorph(morph)
        } else {
            ui.navigate(to: section)
        }
    }

    private func openSettings(to page: SettingsContent.SettingsPage) {
        ui.settingsPage = page
        if app.settings.experimentalToolbarUI {
            ui.openSettings(to: page)
        } else {
            ui.navigate(to: page == .registries ? .registries : .settings)
        }
    }
}

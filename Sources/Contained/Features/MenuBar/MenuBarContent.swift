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

        Button("Run a Container…") { activate(); ui.openCreationPanel(entry: .chooser) }
        Button("Pull Image…") { activate(); ui.dispatch(.pullImage) }

        Divider()

        Button("Images") { activate(); ui.toggleMorph(.updates) }
        Button("Templates") { activate(); ui.toggleMorph(.templates) }
        Button("System") { activate(); ui.toggleMorph(.system) }
        Button("Activity") { activate(); ui.dispatch(.activityHistory) }

        Divider()

        Button("Open Contained") { activate() }
        Button("Settings…") { activate(); ui.toggleMorph(.settings) }
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
}

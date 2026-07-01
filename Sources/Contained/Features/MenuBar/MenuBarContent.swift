import SwiftUI
import AppKit
import ContainedCore

/// The menu shown by the menu-bar extra: a compact command surface with service status, running
/// containers, live resource counts, and the same creation / navigation affordances as the app menu.
struct MenuBarContent: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui

    private var store: ContainersStore { app.containers }
    private var stopped: [ContainerSnapshot] { store.snapshots.filter { $0.state != .running } }
    private var unreadActivityCount: Int { app.historyStore.unreadEventCount() }

    private var cliLabel: String {
        switch app.bootstrap {
        case .ready:
            return app.cliVersion.map { "CLI v\($0)" } ?? "CLI ready"
        case .checking:
            return "Checking CLI"
        case .cliMissing:
            return "CLI missing"
        case .unsupported(let version):
            return "CLI v\(version) unsupported"
        case .serviceStopped:
            return "Service stopped"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()

            infoGrid

            Divider()

            actionStrip

            Divider()

            Menu("Service") {
                statusItem
                Divider()
                if app.serviceHealthy {
                    Button("Stop Service") { Task { await app.stopService() } }
                } else {
                    Button("Start Service") { Task { await app.startService() } }
                }
                Button("Restart Service") { Task { await app.restartService() } }
            }

            Menu("Containers") {
                Menu("Running Containers") {
                    if store.running.isEmpty {
                        disabledPlaceholder("No running containers")
                    } else {
                        ForEach(store.running) { snapshot in
                            Button(containerName(for: snapshot)) {
                                Task { await store.stop(snapshot.id) }
                            }
                        }
                    }
                }

                Menu("Stopped Containers") {
                    if stopped.isEmpty {
                        disabledPlaceholder("No stopped containers")
                    } else {
                        ForEach(stopped) { snapshot in
                            Button(containerName(for: snapshot)) {
                                Task { await store.start(snapshot.id) }
                            }
                        }
                    }
                }
            }

            Menu("Create") {
                Button("Run Container…") { activate(); route(.runContainer) }
                Button("Pull Image…") { activate(); route(.pullImage) }
                    .disabled(!app.settings.hubSearchEnabled)
                Button("Build Image…") { activate(); route(.build) }
                    .disabled(!app.settings.imageBuildEnabled)
                Divider()
                Button("New Volume…") { activate(); route(.createVolume) }
                Button("New Network…") { activate(); route(.createNetwork) }
                Button("Import Compose…") { activate(); ComposeImport.pickAndImport(app: app, ui: ui) }
                    .disabled(!app.settings.composeImportEnabled)
            }

            Menu("Navigate") {
                Button("Containers") { activate(); navigate(to: .containers) }
                Button("Images") { activate(); openSectionOrMorph(.images, morph: .updates) }
                Button("Templates") { activate(); openSectionOrMorph(.templates, morph: .templates) }
                Button("System") { activate(); openSectionOrMorph(.system, morph: .system) }
                Button("Activity") { activate(); openSectionOrMorph(.activity, morph: .activity) }
            }

            Menu("Shortcuts") {
                if app.settings.keyboardShortcutsEnabled {
                    Button(ui.sidebarVisible ? "Hide Sidebar" : "Show Sidebar") { activate(); ui.setSidebarVisible(!ui.sidebarVisible) }
                        .keyboardShortcut("s", modifiers: .command)
                        .disabled(!app.settings.sidebarNavigationEnabled)
                    Button("Search This Page") { activate(); ui.focusSearch() }
                        .keyboardShortcut("f", modifiers: .command)
                    Button("Settings") { activate(); openSettings(to: .appearance) }
                        .keyboardShortcut(";", modifiers: .command)
                    Button("Run Container") { activate(); route(.runContainer) }
                        .keyboardShortcut("n", modifiers: .command)
                    Button("Run Image Check") { Task { await app.runImageUpdateSweepNow() } }
                        .keyboardShortcut("u", modifiers: .command)
                    Button("Activity") { activate(); route(.activityHistory) }
                        .keyboardShortcut("i", modifiers: .command)
                } else {
                    disabledPlaceholder("Enable keyboard shortcuts in Settings → Experimental")
                }
            }

            Menu("Settings") {
                Button("Open Contained") { activate() }
                Divider()
                ForEach(SettingsContent.SettingsPage.allCases) { page in
                    Button(page.rawValue) { activate(); openSettings(to: page) }
                }
            }

            Menu("Help") {
                Button("Check for Updates…") {
                    activate()
                    app.updater.checkForUpdates()
                }
                Button("About Contained") { activate(); openSettings(to: .about) }
                Button("Reveal CLI Binary in Finder") { activate(); revealCLIBinary() }
                Divider()
                Button("Release Notes") { activate(); NSWorkspace.shared.open(Links.releasesURL) }
                Button("Troubleshooting") { activate(); NSWorkspace.shared.open(Links.troubleshootingURL) }
                Button("Keyboard Shortcuts") { activate(); NSWorkspace.shared.open(Links.shortcutsURL) }
            }

            Divider()

            footerRow
        }
        .padding(14)
        .frame(width: 340)
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label("Contained", systemImage: app.serviceHealthy ? "shippingbox.fill" : "shippingbox")
                    .font(.headline)
                Spacer(minLength: 0)
                Text("\(store.running.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Label(app.serviceLabel, systemImage: app.serviceHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(app.serviceHealthy ? .green : .secondary)
                Text(app.settings.updateChannel.displayName)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if unreadActivityCount > 0 {
                    Label("\(unreadActivityCount) unread", systemImage: "bell.badge")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private var infoGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            infoRow("Containers", value: "\(store.running.count) running · \(stopped.count) stopped")
            infoRow("Resources", value: "\(app.images.count) images · \(app.volumes.count) volumes · \(app.networks.count) networks")
            infoRow("Bootstrap", value: cliLabel)
            infoRow("Activity", value: unreadActivityCount > 0 ? "\(unreadActivityCount) unread" : "All caught up")
        }
        .font(.caption)
    }

    private var actionStrip: some View {
        HStack(spacing: 8) {
            miniAction("Open", systemImage: "app")
            miniAction("Run", systemImage: "plus") { route(.runContainer) }
            miniAction("Activity", systemImage: unreadActivityCount > 0 ? "bell.badge" : "bell") { route(.activityHistory) }
            miniAction("Updates", systemImage: "arrow.triangle.2.circlepath") { app.updater.checkForUpdates() }
        }
    }

    private var footerRow: some View {
        HStack(spacing: 8) {
            Button("Open Contained") { activate() }
            Spacer(minLength: 0)
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private func miniAction(_ title: String,
                            systemImage: String,
                            action: @escaping () -> Void = {}) -> some View {
        Button(action: {
            activate()
            action()
        }) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private func infoRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)
            Text(value)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func disabledPlaceholder(_ text: String) -> some View {
        Button(text) { }
            .disabled(true)
    }

    @ViewBuilder
    private var statusItem: some View {
        Label(app.serviceLabel,
              systemImage: app.serviceHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(app.serviceHealthy ? .green : .secondary)
    }

    /// Bring the main window to the front.
    private func activate() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            break
        }
    }

    private func containerName(for snapshot: ContainerSnapshot) -> String {
        app.containerStyle(for: snapshot).displayName(fallback: snapshot.id)
    }

    private func navigate(to section: AppSection) {
        ui.navigate(to: section)
    }

    private func route(_ action: PendingAction) {
        ui.dispatch(action)
    }

    private func openSectionOrMorph(_ section: AppSection, morph: UIState.ToolbarMorph) {
        if app.settings.usesPanelNavigation {
            ui.toggleMorph(morph)
        } else {
            ui.navigate(to: section)
        }
    }

    private func openSettings(to page: SettingsContent.SettingsPage) {
        ui.settingsPage = page
        if app.settings.usesPanelNavigation {
            ui.openSettings(to: page)
        } else {
            ui.navigate(to: .settings)
        }
    }

    /// Reveal the resolved `container` binary in Finder (honoring the CLI-path override).
    private func revealCLIBinary() {
        guard let url = CLILocator.locate(override: app.settings.cliPathOverride) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

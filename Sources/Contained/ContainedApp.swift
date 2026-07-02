import SwiftUI
import ContainedDesignSystem
import AppKit
import ContainedCore

@main
struct ContainedApp: App {
    @State private var app = AppModel()
    @State private var ui = UIState()

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(ui)
                .modelContainer(app.historyStore.container)
                .frame(minWidth: 720, minHeight: 480)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Color.clear
                            .frame(width: 0, height: 0)
                            .accessibilityHidden(true)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Contained") {
                    activateMainWindow()
                    openSettings(to: .about)
                }
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { app.updater.checkForUpdates() }
                    .disabled(!app.updater.canCheckForUpdates)
            }
            // Settings now lives in the toolbar morph panel (no separate Settings window), so ⌘,
            // opens that instead of the standard Settings scene.
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { openSettings() }
                    .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                               ",",
                                               modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {
                Menu("Create") {
                    Button("Run Container…") { route(.runContainer) }
                        .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                                   "n",
                                                   modifiers: .command)
                    Button("Pull Image…") { route(.pullImage) }
                        .disabled(!app.settings.hubSearchEnabled)
                    Button("Build Image…") { route(.build) }
                        .disabled(!app.settings.imageBuildEnabled)
                    Divider()
                    Button("New Volume…") { route(.createVolume) }
                    Button("New Network…") { route(.createNetwork) }
                    Button("Import Compose…") { ComposeImport.pickAndImport(app: app, ui: ui) }
                        .disabled(!app.settings.composeImportEnabled)
                }
            }
            CommandGroup(after: .importExport) {
                Menu("Service") {
                    Button(app.serviceLabel) { }
                        .disabled(true)
                    Divider()
                    if app.serviceHealthy {
                        Button("Stop Service") { Task { await app.stopService() } }
                    } else {
                        Button("Start Service") { Task { await app.startService() } }
                    }
                    Button("Restart Service") { Task { await app.restartService() } }
                }
                Divider()
                Button("Open Contained") { activateMainWindow() }
                Button("Check for Updates…") { app.updater.checkForUpdates() }
                    .disabled(!app.updater.canCheckForUpdates)
            }
            CommandGroup(after: .textEditing) {
                Menu("Search") {
                    Button("Search This Page") { ui.focusSearch() }
                        .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                                   "f",
                                                   modifiers: .command)
                    if app.settings.commandPaletteEnabled {
                        Button("Command Palette…") { routePalette() }
                            .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                                       "k",
                                                       modifiers: .command)
                    }
                }
                Menu("Activity") {
                    Button("Run Image Update Check") { Task { await app.runImageUpdateSweepNow() } }
                        .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                                   "u",
                                                   modifiers: .command)
                    Button("Activity") { route(.activityHistory) }
                        .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                                   "i",
                                                   modifiers: .command)
                }
            }
            CommandGroup(replacing: .sidebar) {
                Toggle("Show Sidebar", isOn: sidebarVisibilityBinding)
                    .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                               "s",
                                               modifiers: .command)
                    .disabled(!app.settings.sidebarNavigationEnabled)
            }
            CommandGroup(replacing: .toolbar) {
                Toggle("Show Running Only", isOn: runningOnlyBinding)
                Picker("Card Size", selection: cardSizeBinding) {
                    ForEach(CardDensity.allCases) { Text($0.displayName).tag($0) }
                }
                Divider()
                Button("Reload") { app.coordinator.wake() }
                    .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                               "r",
                                               modifiers: [.command, .shift])
                Menu("Navigate") {
                    Button("Containers") { ui.navigate(to: .containers) }
                        .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                                   "1",
                                                   modifiers: .command)
                    Button("Images") { openSectionOrMorph(.images, morph: .updates) }
                        .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                                   "2",
                                                   modifiers: .command)
                    Button("Templates") { openSectionOrMorph(.templates, morph: .templates) }
                        .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                                   "3",
                                                   modifiers: .command)
                    Button("System") { openSectionOrMorph(.system, morph: .system) }
                        .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                                   "4",
                                                   modifiers: .command)
                    Button("Activity") { openSectionOrMorph(.activity, morph: .activity) }
                        .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                                   "5",
                                                   modifiers: .command)
                    Button("Settings") { openSettings() }
                        .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                                   "6",
                                                   modifiers: .command)
                }
            }
            CommandGroup(replacing: .help) {
                Button("Contained Help") { NSWorkspace.shared.open(Links.helpURL) }
                Button("Features Guide") { NSWorkspace.shared.open(Links.featuresURL) }
                Button("Installation & Updates") { NSWorkspace.shared.open(Links.installURL) }
                Button("Keyboard Shortcuts") { NSWorkspace.shared.open(Links.shortcutsURL) }
                Button("Troubleshooting") { NSWorkspace.shared.open(Links.troubleshootingURL) }
                Divider()
                Button("Release Notes") { showReleaseNotes() }
                Button("Architecture") { NSWorkspace.shared.open(Links.architectureURL) }
                Button("Contributing") { NSWorkspace.shared.open(Links.contributingURL) }
                Divider()
                Button("Report an Issue…") { NSWorkspace.shared.open(Links.issuesURL) }
                Button("View Source on GitHub") { NSWorkspace.shared.open(Links.repoURL) }
                Divider()
                Button("Reveal CLI Binary in Finder") { revealCLIBinary() }
            }
        }

        MenuBarExtra(isInserted: menuBarInserted) {
            MenuBarContent()
                .environment(app)
                .environment(ui)
        } label: {
            Label {
                Text("\(app.containers.running.count)")
            } icon: {
                Image(systemName: app.serviceHealthy ? "shippingbox.fill" : "shippingbox")
            }
        }
        .menuBarExtraStyle(.window)
    }

    /// Binding into the persisted setting so toggling it inserts/removes the menu-bar item live.
    private var menuBarInserted: Binding<Bool> {
        Binding(get: { app.settings.keepInMenuBar }, set: { app.settings.keepInMenuBar = $0 })
    }

    private var cardSizeBinding: Binding<CardDensity> {
        Binding(get: { app.settings.density }, set: { app.settings.density = $0 })
    }

    private var runningOnlyBinding: Binding<Bool> {
        Binding(get: { ui.runningOnly }, set: { ui.runningOnly = $0 })
    }

    private var sidebarVisibilityBinding: Binding<Bool> {
        Binding(get: { app.settings.sidebarNavigationEnabled && ui.sidebarVisible },
                set: { ui.setSidebarVisible($0) })
    }

    private func route(_ action: PendingAction) {
        ui.dispatch(action)
    }

    private func routePalette() {
        if app.settings.usesPanelNavigation {
            ui.toggleMorph(.palette)
        } else {
            ui.navigate(to: .containers)
        }
    }

    private func openSectionOrMorph(_ section: AppSection, morph: UIState.ToolbarMorph) {
        if app.settings.usesPanelNavigation {
            ui.toggleMorph(morph)
        } else {
            ui.navigate(to: section)
        }
    }

    private func openSettings(to page: SettingsContent.SettingsPage = .appearance) {
        ui.settingsPage = page
        if app.settings.usesPanelNavigation {
            ui.openSettings(to: page)
        } else {
            ui.navigate(to: .settings)
        }
    }

    private func showReleaseNotes() {
        activateMainWindow()
        app.updater.presentCurrentReleaseNotes()
    }

    /// Reveal the resolved `container` binary in Finder (honoring the CLI-path override).
    private func revealCLIBinary() {
        guard let url = CLILocator.locate(override: app.settings.cliPathOverride) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Bring the main window to the front so panel morphs open in the right window.
    private func activateMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            break
        }
    }
}

private extension View {
    @ViewBuilder
    func keyboardShortcutIfEnabled(_ enabled: Bool,
                                   _ keyEquivalent: KeyEquivalent,
                                   modifiers: EventModifiers = []) -> some View {
        if enabled {
            keyboardShortcut(keyEquivalent, modifiers: modifiers)
        } else {
            self
        }
    }
}

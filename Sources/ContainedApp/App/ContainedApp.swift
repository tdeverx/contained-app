import SwiftUI
import ContainedUI
import ContainedCore

public struct ContainedApplication: App {
    @Environment(\.openURL) private var openURL
    @State private var app = AppModel()
    @State private var ui = UIState()

    public init() {
        Platform.disableAutomaticWindowTabbing()
    }

    public var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(ui)
                .modelContainer(app.historyStore.container)
                .frame(minWidth: 720, minHeight: 300)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Color.clear
                            .frame(width: 0, height: 0)
                            .accessibilityHidden(true)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)
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
            // Route Settings through the app shell so the keyboard shortcut and toolbar panel
            // open the same surface.
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
                    Button("Import Compose…") { route(.importCompose) }
                        .disabled(!app.settings.composeImportEnabled)
                }
            }
            CommandGroup(after: .importExport) {
                Menu("Service") {
                    Button(app.serviceLabel) { }
                        .disabled(true)
                    Divider()
                    if app.serviceControlRuntimeAvailable {
                        if app.serviceHealthy {
                            Button("Stop Service") { Task { await app.stopService() } }
                        } else {
                            Button("Start Service") { Task { await app.startService() } }
                        }
                        Button("Restart Service") { Task { await app.restartService() } }
                    } else {
                        Button("Retry Runtime Connection") { Task { await app.retryBootstrap() } }
                    }
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
            CommandGroup(replacing: .toolbar) {
                Toggle("Show Running Only", isOn: runningOnlyBinding)
                Picker("Card Size", selection: cardSizeBinding) {
                    ForEach(UI.Card.Density.allCases) { Text($0.localizedDisplayName).tag($0) }
                }
                Divider()
                Button("Reload") { app.coordinator.wake() }
                    .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                               "r",
                                               modifiers: [.command, .shift])
                Menu("Navigate") {
                    Button("Containers") { ui.requestMorphClose() }
                        .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                                   "1",
                                                   modifiers: .command)
                    Button("Images") { ui.toggleMorph(.updates) }
                        .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                                   "2",
                                                   modifiers: .command)
                    Button("Templates") { ui.toggleMorph(.templates) }
                        .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                                   "3",
                                                   modifiers: .command)
                    Button("System") { ui.toggleMorph(.system) }
                        .keyboardShortcutIfEnabled(app.settings.keyboardShortcutsEnabled,
                                                   "4",
                                                   modifiers: .command)
                    Button("Activity") { ui.toggleMorph(.activity) }
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
                Button("Contained Help") { openURL(Links.helpURL) }
                Button("Features Guide") { openURL(Links.featuresURL) }
                Button("Installation & Updates") { openURL(Links.installURL) }
                Button("Keyboard Shortcuts") { openURL(Links.shortcutsURL) }
                Button("Troubleshooting") { openURL(Links.troubleshootingURL) }
                Divider()
                Button("Release Notes") { showReleaseNotes() }
                Button("Architecture") { openURL(Links.architectureURL) }
                Button("Contributing") { openURL(Links.contributingURL) }
                Divider()
                Button("Report an Issue…") { openURL(Links.issuesURL) }
                Button("View Source on GitHub") { openURL(Links.repoURL) }
                Divider()
                Button("Reveal CLI Binary in Finder") { revealCLIBinary() }
            }
        }

        MenuBarExtra(isInserted: menuBarInserted) {
            MenuBarContent()
                .environment(app)
                .environment(ui)
                .tint(app.settings.accentTint.resolvedAppAccentColor)
                .accentColor(app.settings.accentTint.resolvedAppAccentColor)
                .environment(\.designSystemAccentColor, app.settings.accentTint.resolvedAppAccentColor)
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

    private var cardSizeBinding: Binding<UI.Card.Density> {
        Binding(get: { app.settings.density }, set: { app.settings.density = $0 })
    }

    private var runningOnlyBinding: Binding<Bool> {
        Binding(get: { ui.runningOnly }, set: { ui.runningOnly = $0 })
    }

    private func route(_ action: PendingAction) {
        ui.dispatch(action)
    }

    private func routePalette() {
        ui.toggleMorph(.palette)
    }

    private func openSettings(to page: SettingsContent.SettingsPage = .appearance) {
        ui.openSettings(to: page)
    }

    private func showReleaseNotes() {
        activateMainWindow()
        app.updater.presentCurrentReleaseNotes()
    }

    /// Reveal the resolved `container` binary in Finder (honoring the CLI-path override).
    private func revealCLIBinary() {
        guard let url = app.runtimeCLIURL(for: .appleContainer) else { return }
        Platform.revealInFinder(url)
    }

    /// Bring the main window to the front so panel morphs open in the right window.
    private func activateMainWindow() {
        Platform.activateMainWindow()
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

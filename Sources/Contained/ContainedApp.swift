import SwiftUI
import AppKit
import ContainedCore

@main
struct ContainedApp: App {
    @State private var app = AppModel()
    @State private var ui = UIState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(ui)
                .modelContainer(app.historyStore.container)
                .frame(minWidth: 720, minHeight: 480)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Contained") {
                    activateMainWindow()
                    ui.openSettings(to: .about)
                }
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { app.updater.checkForUpdates() }
                    .disabled(!app.updater.canCheckForUpdates)
            }
            // Settings now lives in the toolbar morph panel (no separate Settings window), so ⌘,
            // opens that instead of the standard Settings scene.
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { ui.toggleMorph(.settings) }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                // The toolbar "＋" add-menu — Container / Network / Volume.
                Button("New…") { ui.openCreationPanel() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Run Container…") { ui.openCreationPanel(entry: .chooser) }
                    .keyboardShortcut("r", modifiers: .command)
                Divider()
                if app.settings.hubSearchEnabled {
                    Button("Pull Image…") { ui.dispatch(.pullImage) }
                }
                if app.settings.imageBuildEnabled {
                    Button("Build Image…") { ui.dispatch(.build) }
                }
                Divider()
                Button("New Volume…") { ui.dispatch(.createVolume) }
                Button("New Network…") { ui.dispatch(.createNetwork) }
                if app.settings.composeImportEnabled {
                    Divider()
                    Button("Import Compose…") { ComposeImport.pickAndImport(app: app, ui: ui) }
                }
            }
            // (Find / ⌘F intentionally omitted — in-window search is being reworked and will return
            // with the new search affordance.)
            CommandGroup(after: .sidebar) {
                Divider()
                Button("Reload") { app.coordinator.wake() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Picker("Card Size", selection: cardSizeBinding) {
                    ForEach(CardDensity.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle("Show Running Only", isOn: runningOnlyBinding)
            }
            CommandGroup(after: .toolbar) {
                if app.settings.commandPaletteEnabled {
                    Button("Command Palette…") { ui.toggleMorph(.palette) }
                        .keyboardShortcut("k", modifiers: .command)
                }
                Button("Search This Page") { ui.focusSearch() }
                    .keyboardShortcut("s", modifiers: .command)
                Divider()
                Button("Run Image Update Check") { Task { await app.runImageUpdateSweepNow() } }
                    .keyboardShortcut("u", modifiers: .command)
                Button("Activity") { ui.dispatch(.activityHistory) }
                    .keyboardShortcut("i", modifiers: .command)
            }
            CommandMenu("Go") {
                Button("Containers") { ui.activeMorph = nil }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Images") { ui.toggleMorph(.updates) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Templates") { ui.toggleMorph(.templates) }
                    .keyboardShortcut("3", modifiers: .command)
                Button("System") { ui.toggleMorph(.system) }
                    .keyboardShortcut("4", modifiers: .command)
                Button("Activity") { ui.dispatch(.activityHistory) }
                    .keyboardShortcut("5", modifiers: .command)
            }
            CommandGroup(replacing: .help) {
                Button("Contained Help") { NSWorkspace.shared.open(Links.helpURL) }
                Button("Features Guide") { NSWorkspace.shared.open(Links.featuresURL) }
                Button("Installation & Updates") { NSWorkspace.shared.open(Links.installURL) }
                Button("Keyboard Shortcuts") { NSWorkspace.shared.open(Links.shortcutsURL) }
                Button("Troubleshooting") { NSWorkspace.shared.open(Links.troubleshootingURL) }
                Divider()
                Button("Release Notes") { NSWorkspace.shared.open(Links.releasesURL) }
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
            Label("\(app.containers.running.count)", systemImage: "shippingbox.fill")
        }
        .menuBarExtraStyle(.menu)
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
